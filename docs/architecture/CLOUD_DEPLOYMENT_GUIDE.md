# Deepiri Cloud Portal — Deployment Guide (cheap one-box VPS)

> Deployed against **Netcup VPS 1000 G12** (Magdeburg MNZ, 4 vCPU / 8 GiB / ~251 GB)
> serving the decoupled **cloud portal** stack from `deepiri-platform` PR #304.
> This guide is written so it can be followed end-to-end **without ever exposing a secret**.

**What lives on this box (11 services):** `postgres-platform`, `redis`, `auth-service`,
`registry`, `jobs`, `external-bridge-service`, `api-gateway`, `platform-frontend`,
`nginx`, `certbot`, `pg-backup-offsite`.

**What does NOT live here:** Cyrex, language-intelligence (LIS), speech, Kafka,
messaging, realtime-gateway, MinIO, MLflow, Milvus, etcd — those stay on the
local `deepiri-control-plane` stack. See `REPO_SPLIT.md`.

---

## 0. Architecture / traffic flow

```
Browser
   │  https://platform.deepiri.com
   ▼
Cloudflare  (proxy — orange cloud; TLS terminates on edge, universal SSL cert)
   │  forwards :443 to origin (Full strict → origin cert must be valid)
   ▼
VPS 159.195.234.19  :80 / :443
   │  nginx (cloud-prod.conf)
   ├── /            → platform-frontend (nginx container → static build)
   ├── /api/*       → api-gateway (5000) → auth / registry / jobs / external-bridge
   └── /.well-known → certbot webroot (HTTP-01 ACME challenge)
```

`/health` is served plain over HTTP (no redirect) so load balancers / health checks work.

---

## 1. Order the box & point DNS

1. Order the VPS → wait for root credentials.
2. Note the public **IPv4** from the SCP control panel.
3. In **Cloudflare → deepiri.com → DNS → Add record**:

   | Field | Value |
   |-------|-------|
   | Type | `A` |
   | Name | `platform` |
   | IPv4 address | `<VPS_IPV4>` |
   | Proxy status | **Proxied** (orange cloud) |
   | TTL | Auto |

   Result: `platform.deepiri.com → <VPS_IPV4>`.

4. In **Cloudflare → SSL/TLS → Overview**, set mode to **Full (strict)**.
   (Origin must present a valid cert for the domain — we issue one via Let's Encrypt below.)

---

## 2. First login & host prep

```bash
ssh root@<VPS_IPV4>
```

```bash
apt update && apt upgrade -y
apt install -y ca-certificates curl git ufw fail2ban rsync

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
```

Verify: `docker compose version`, `free -h` (~8 GiB), `nproc` (4).

---

## 3. Get the code + secrets onto the box (no secrets via git)

### Option A — rsync from a trusted machine (used here)

Rsync only the **source** tree (`.git` and `node_modules` excluded — the compose build
reinstalls deps). Secrets are transferred **out-of-band** (below), never through git.

```bash
mkdir -p /opt/deepiri
rsync -a --delete -e ssh \
  --exclude '.git/' --exclude 'node_modules/' \
  <local-vm>/deepiri-platform/  root@<VPS_IPV4>:/opt/deepiri/deepiri-platform/
```

### Secrets (out-of-band — never committed anywhere)

The production secrets live in a **sealed, gitignored** file:
`/opt/deepiri/deepiri-platform/ops/k8s/secrets/.env`
(`ops/k8s/secrets/` is in `.gitignore`; the template is `ops/k8s/secrets-templates/cloud-portal/dot.env.example`).

The encrypted archive (`.7z`, password protected) is distributed on Discord
(`cloud-portal-secrets.7z`). Extract it **on the VPS** (or locally, then scp the
resulting `.env` directly — still never via git):

```bash
mkdir -p ops/k8s/secrets
scp <local>/cloud-portal-staging/.env root@<VPS_IPV4>:/opt/deepiri/deepiri-platform/ops/k8s/secrets/.env
chmod 600 ops/k8s/secrets/.env
```

**Required keys** (see `.env.example`): `POSTGRES_PASSWORD`, `PLATFORM_DB_PASSWORD`,
`REDIS_PASSWORD`, `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `CORS_ORIGINS`, `VITE_API_URL`.

> **Password hygiene**: DB/Redis/JWT secrets are generated as **hex** (URL-safe by
> construction) — never use base64, because `/+ =` break `postgresql://` / `redis://` URLs.
> Example: `openssl rand -hex 32`.

**Public URL keys** — set these to the real domain:

```bash
CORS_ORIGINS=https://platform.deepiri.com
VITE_API_URL=https://platform.deepiri.com/api
CLIENT_URL=https://platform.deepiri.com
```

Validate interpolation (must exit 0):

```bash
set -a && source ops/k8s/secrets/.env && set +a
docker compose -f docker-compose.yml config --quiet
```

---

## 4. Build & start the stack

```bash
cd /opt/deepiri/deepiri-platform
set -a && source ops/k8s/secrets/.env && set +a

docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml up -d
```

To show compose status you must re-export the env (interpolation):

```bash
set -a && source ops/k8s/secrets/.env && set +a
docker compose -f docker-compose.yml ps
```

Quick bring-up check (self-signed cert expected at this stage):

```bash
curl -sk http://127.0.0.1/health           # 200
curl -sk https://127.0.0.1/api/health      # healthy JSON
docker stats --no-stream
```

Target idle: **well under 1 GiB RAM**, CPU near 0.

---

## 5. Real TLS (Let's Encrypt) — after DNS points here

nginx loads its cert from `/etc/letsencrypt/live/current` (a symlink into the
`certbot_conf` docker volume). `ensure-dummy-cert.sh` first writes a throwaway
self-signed cert so nginx can bind :443 at all.

> **Cloudflare proxy note:** HTTP-01 works through the orange cloud because Cloudflare
> forwards `/.well-known/acme-challenge/*` to origin :80. Verified that `probe.txt`
> behind the challenge path returned 200 through the proxy before issuing.

```bash
cd /opt/deepiri/deepiri-platform
set -a && source ops/k8s/secrets/.env && set +a

# 1. Dummy cert so nginx can bind :443
./ops/nginx/ensure-dummy-cert.sh platform.deepiri.com -- -f docker-compose.yml

# 2. Issue the real cert (HTTP-01 via the running nginx webroot)
docker compose -f docker-compose.yml run --rm --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  --email ops@deepiri.com -d platform.deepiri.com \
  --rsa-key-size 2048 --agree-tos --no-eff-email

# 3. Point live/current at the real cert and reload nginx
docker compose -f docker-compose.yml run --rm --entrypoint sh certbot -c \
  "ln -sfn platform.deepiri.com /etc/letsencrypt/live/current"
docker compose -f docker-compose.yml exec nginx nginx -s reload
```

Then rebuild the frontend with the **domain** API URL baked in and bounce nginx:

```bash
docker compose -f docker-compose.yml up -d --build platform-frontend nginx
```

Verification:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://platform.deepiri.com/        # 200
curl -sS https://platform.deepiri.com/api/health                                # healthy JSON
# Confirm origin serves the REAL Let's Encrypt cert, not the dummy:
echo | openssl s_client -connect <VPS_IPV4>:443 -servername platform.deepiri.com 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

The `certbot` service auto-renews. Add a host cron to reload nginx after renewal:

```
0 3 * * 0 cd /opt/deepiri/deepiri-platform && docker compose exec nginx nginx -s reload
```

---

## 6. Smoke test (go / no-go)

| Check | Pass criteria |
|-------|---------------|
| `docker compose ps` | All critical services `healthy` / `running` |
| `https://platform.deepiri.com` | Portal loads (HTTP 200) |
| `https://platform.deepiri.com/api/health` | `"healthy"`, redis + database connected |
| CORS preflight `OPTIONS /api` with `Origin: https://platform.deepiri.com` | `204` |
| `docker stats` | Memory ≪ 8 GiB, CPU low at idle |
| Postgres backup job | `jobs` scheduler enabled; `postgres_backups` volume writable |
| No Cyrex / LIS / livekit containers | `docker ps` shows none of them |

---

## 7. Ops hygiene

```bash
# Update code (rsync new source, or git pull if you deployed with git)
rsync ... root@<VPS_IPV4>:/opt/deepiri/deepiri-platform/

# Rebuild + restart
cd /opt/deepiri/deepiri-platform
set -a && source ops/k8s/secrets/.env && set +a
docker compose -f docker-compose.yml up -d --build

# Logs
docker compose -f docker-compose.yml logs -f api-gateway auth-service nginx

# Stop (keep volumes)
docker compose -f docker-compose.yml down
```

---

## 8. Rollback / abort

1. `docker compose -f docker-compose.yml down` (add `-v` only if wiping the DB is OK).
2. Terminate the Netcup hourly contract in SCP.
3. Local control-plane stack on `deepiri-control-plane` stays unaffected.

---

## Secrets checklist (what must NEVER appear in git)

- `ops/k8s/secrets/` — gitignored; contains the real `.env`.
- `cloud-portal-secrets.7z` / `control-plane-secrets.7z` — sealed archives, shared on
  Discord only, never in the repo.
- `*secret.yaml` under `ops/k8s/secrets-templates/` — these are **templates** with
  `REPLACE_ME` / `example` values; fill real values out-of-band.
- Passwords are **hex**-encoded random values (`openssl rand -hex N`), URL-safe.

Before opening any PR touching infra, run:

```bash
git diff --check origin/dev...HEAD
git status -s | grep -v '^ M .*submodule' || true   # confirm no secrets staged
```

---

## Related docs

- [`NETCUP_VPS_1000_G12_DEPLOYMENT_PLAN.md`](NETCUP_VPS_1000_G12_DEPLOYMENT_PLAN.md) — ordered-box runbook
- [`CHEAP_ONE_BOX_VPS.md`](CHEAP_ONE_BOX_VPS.md) — sizing + pricing
- [`REPO_SPLIT.md`](REPO_SPLIT.md) — cloud vs control-plane split
- [`PLATFORM_DECOUPLING_PLAN.md`](PLATFORM_DECOUPLING_PLAN.md) — why Cyrex/LIS stay local
- [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)
- Control plane repo: `https://github.com/Team-Deepiri/deepiri-control-plane`
