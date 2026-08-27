# Netcup VPS 1000 G12 — cloud portal deployment plan (PR #304)

**Box ordered (2026-08-27):** `VPS 1000 G12 iv MNZ hourly-based`  
**Location:** Magdeburg (MNZ) · **Billing:** hourly / min 0 months · **Setup:** €4.20 · **VPS:** €11.06/mo + IPv4 €0.50/mo  

**Stack:** `deepiri-platform` `docker-compose.yml` only (11 services).  
**Not on this box:** Cyrex, LIS, speech, Kafka, messaging — those stay on **deepiri-control-plane**.

**Sizing:** David Li decoupled bench — idle ~316 MiB; gateway-routed load ~1.66 core-eq. Fits 4c/8GB. See [`CHEAP_ONE_BOX_VPS.md`](CHEAP_ONE_BOX_VPS.md).

---

## Phase 0 — Before SSH (checklist)

| # | Task | Owner | Done? |
|---|------|-------|-------|
| 0.1 | Pay Netcup invoice in SCP; wait for “activated” / root credentials email | Joe | ☐ |
| 0.2 | Note **IPv4** from SCP (and IPv6 if used) | Joe | ☐ |
| 0.3 | Domain DNS: `A` record → VPS IPv4 (and `AAAA` if using IPv6) — needed for Let’s Encrypt | Joe | ☐ |
| 0.4 | Merge [external-bridge #84](https://github.com/Team-Deepiri/deepiri-external-bridge-service/pull/84) (**merged**) and bump submodule pointer on this PR if not already | David / infra | ☐ |
| 0.5 | Publish **`cloud-portal-secrets.7z`** on Discord; fill `ops/k8s/secrets/.env` from templates | David | ☐ |
| 0.6 | Real object storage (`STORAGE_*` if compose still requires) + Google OAuth if login-via-Google is in launch scope | David / Josep | ☐ |
| 0.7 | Merge PR #304 into `dev` (or deploy from this branch with explicit checkout) | leads | ☐ |

Do **not** paste secret values into this PR.

---

## Phase 1 — First login & host prep

```bash
# From laptop — replace with SCP-provided IP / user
ssh root@YOUR_VPS_IPV4
```

```bash
# On the VPS
apt update && apt upgrade -y
apt install -y ca-certificates curl git ufw fail2ban

# Docker Engine + Compose plugin (official)
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Firewall: SSH + HTTP/HTTPS only
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Optional: create a non-root deploy user and disable password SSH later
```

Confirm: `docker compose version` and `free -h` (~8 GB).

---

## Phase 2 — Clone cloud portal repo

```bash
# Prefer deploy key or fine-grained PAT with read on Team-Deepiri/deepiri-platform
# and private submodules used by cloud compose builds
mkdir -p /opt/deepiri && cd /opt/deepiri
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform

# Until merged: deploy from PR branch
git fetch origin infra/cheap-one-box-compose-dev
git checkout infra/cheap-one-box-compose-dev

# Init ONLY cloud-needed submodules (matches CI in platform-build-and-test.yml)
git submodule sync \
  platform-services/backend/deepiri-api-gateway \
  platform-services/backend/deepiri-auth-service \
  platform-services/backend/deepiri-external-bridge-service \
  platform-services/shared/deepiri-shared-utils
git submodule update --init --depth 1 \
  platform-services/backend/deepiri-api-gateway \
  platform-services/backend/deepiri-auth-service \
  platform-services/backend/deepiri-external-bridge-service \
  platform-services/shared/deepiri-shared-utils
# Also init any other build-context paths in docker-compose.yml (registry, jobs, frontend) if they are submodules
```

Verify compose is the **cloud** file:

```bash
grep -q postgres-platform docker-compose.yml && echo "cloud portal OK"
```

---

## Phase 3 — Secrets on the box

```bash
mkdir -p ops/k8s/secrets
# Copy from cloud-portal-secrets.7z (SCP/rsync — never commit)
# Or: cp ops/k8s/secrets-templates/cloud-portal/dot.env.example ops/k8s/secrets/.env
nano ops/k8s/secrets/.env   # fill required keys
chmod 600 ops/k8s/secrets/.env
```

**Minimum env for `docker compose config` to succeed** (see `SECRETS_SPLIT.md` + `.env.example`):

- `POSTGRES_PASSWORD`, `PLATFORM_DB_PASSWORD`, `PLATFORM_DB_USER`, `PLATFORM_DB_NAME`
- `REDIS_PASSWORD`, `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`
- `CORS_ORIGINS` — e.g. `https://your.domain`
- `VITE_API_URL` — e.g. `https://your.domain` (build-time for frontend)
- Google OAuth pair if auth requires them at boot
- Keep `BACKUP_OFFSITE_ENABLED=false` for first boot unless offsite keys are ready

```bash
# Dry-run interpolation (must exit 0)
set -a && source ops/k8s/secrets/.env && set +a
docker compose -f docker-compose.yml config --quiet
```

---

## Phase 4 — Build & start stack

```bash
cd /opt/deepiri/deepiri-platform
set -a && source ops/k8s/secrets/.env && set +a

docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml up -d

docker compose -f docker-compose.yml ps
docker compose -f docker-compose.yml logs -f --tail=100
```

**Expected services (11):**  
`postgres-platform`, `redis`, `auth-service`, `registry`, `jobs`, `external-bridge-service`, `api-gateway`, `platform-frontend`, `nginx`, `certbot`, `pg-backup-offsite` (may be idle if offsite disabled).

```bash
# Quick health (via nginx once up — HTTP may redirect)
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1/api/health || true
docker stats --no-stream
```

Target idle: **well under 1 GB RAM**, CPU low (David: ~300 MiB class).

---

## Phase 5 — TLS (after DNS points here)

```bash
export DOMAIN_NAME=your.domain.example
export CERTBOT_EMAIL=ops@your-org.example   # LE notices only
./ops/nginx/init-letsencrypt.sh
```

Then set in `.env` and rebuild frontend if needed:

- `CORS_ORIGINS=https://$DOMAIN_NAME`
- `VITE_API_URL=https://$DOMAIN_NAME`
- `CLIENT_URL` / related auth redirect URLs if present

```bash
docker compose -f docker-compose.yml up -d --build platform-frontend nginx
```

---

## Phase 6 — Smoke test (Saturday go/no-go)

| Check | Pass criteria |
|-------|----------------|
| `docker compose ps` | All critical services healthy / running |
| `https://$DOMAIN_NAME` | Portal loads |
| Login (local and/or Google) | Auth works |
| API via gateway | `/api/health` or app call succeeds |
| `docker stats` | Memory ≪ 8 GB; CPU not pegged at idle |
| Postgres backup job | `jobs` scheduler enabled; backup dir writable |
| No Cyrex/LIS containers | `docker ps` does not show cyrex / language-intelligence / livekit |

---

## Phase 7 — Ops hygiene

```bash
# Updates
cd /opt/deepiri/deepiri-platform
git pull
git submodule update --init --recursive   # cloud paths only
docker compose -f docker-compose.yml up -d --build

# Logs
docker compose -f docker-compose.yml logs -f api-gateway auth-service nginx

# Stop (keep volumes)
docker compose -f docker-compose.yml down

# Cancel Netcup (trial end)
# SCP → contracts → terminate VPS 1000 G12 hourly (no 12M lock-in)
```

Watch **CPU** under real concurrent use more than RAM. Upgrade path: Netcup VPS 2000 G12 if needed — non-blocking resize discussion later.

---

## Rollback / abort

1. `docker compose -f docker-compose.yml down` (add `-v` only if wiping DB is OK)
2. Terminate Netcup hourly contract in SCP
3. Keep control-plane local stack on **deepiri-control-plane** unchanged

---

## Related docs

- [`CHEAP_ONE_BOX_VPS.md`](CHEAP_ONE_BOX_VPS.md) — sizing + pricing
- [`REPO_SPLIT.md`](REPO_SPLIT.md) — cloud vs control-plane
- [`../ops/k8s/secrets-templates/SECRETS_SPLIT.md`](../../ops/k8s/secrets-templates/SECRETS_SPLIT.md) — Discord archives
- [`../ops/nginx/init-letsencrypt.sh`](../../ops/nginx/init-letsencrypt.sh) — TLS bootstrap
- Control plane: https://github.com/Team-Deepiri/deepiri-control-plane
