# GitHub Actions secrets for `deepiri-platform` CI (cloud portal)

Repository: **Team-Deepiri/deepiri-platform** → Settings → Secrets and variables → Actions.

## Required for CI (submodule + Docker builds)

| Secret | Purpose | How to obtain |
|--------|---------|---------------|
| `PLATFORM_ACCESS_TOKEN` | Clone private Team-Deepiri submodules over HTTPS in CI | Fine-grained PAT with **read** on cloud-portal submodule repos, or from **`cloud-portal-secrets.7z`** (Discord — @daev1005) |

`GITHUB_TOKEN` is automatic (used for `ghcr.io` / `deepiri-suite` base images).

## Not required for CI (workflow placeholders)

Cloud `docker-compose.yml` vars are set in `.github/workflows/platform-build-and-test.yml` for `docker compose config` / builds:

`POSTGRES_PASSWORD`, `PLATFORM_DB_PASSWORD`, `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `REDIS_PASSWORD`, `CORS_ORIGINS`, `VITE_API_URL`, OAuth dummies, etc.

## Local / VPS secrets (not GitHub)

| Plane | Discord archive | Local path |
|-------|-----------------|------------|
| **Cloud portal** | **`cloud-portal-secrets.7z`** (new — @daev1005) | `ops/k8s/secrets/.env` + `*-secret.yaml` |
| **Control plane** | **`secrets.7z`** (existing — edit for control-plane) | **deepiri-control-plane** repo only |

See [`ops/k8s/secrets-templates/SECRETS_SPLIT.md`](../k8s/secrets-templates/SECRETS_SPLIT.md).

## Required for CD (cloud portal → VPS)

CD workflow: **`.github/workflows/cd-cloud-portal.yml`** — deploys `dev` pushes to `platform.deepiri.com`.

| Secret | Purpose | Example |
|--------|---------|---------|
| `VPS_HOST` | VPS IPv4 | `159.195.234.19` |
| `VPS_USER` | SSH user | `root` |
| `VPS_SSH_KEY` | Private key (`cat ~/.ssh/id_ed25519`) paired with `~/.ssh/authorized_keys` on VPS | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `VPS_PORT` | *(optional)* SSH port | `22` |
| `VPS_DEPLOY_PATH` | *(optional)* Remote path | `/opt/deepiri/deepiri-platform` |
| `VPS_ENV_FILE` | *(optional)* Full `ops/k8s/secrets/.env` content — if set, CD overwrites the remote `.env` before build | paste from `cloud-portal-secrets.7z` |

**Setup steps (one-time):**
1. On your machine: `ssh-keygen -t ed25519 -f ~/.ssh/deepiri-cd -C "deepiri-cd"` (no passphrase).
2. On VPS: `mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys` then paste `~/.ssh/deepiri-cd.pub`.
3. In GitHub repo Settings → Secrets → Actions: add `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY` (cat `~/.ssh/deepiri-cd`), and optionally `VPS_ENV_FILE` (`cat ops/k8s/secrets/.env`).
4. Test manually: Actions → **CD — Cloud Portal Deploy** → Run workflow.

See [`docs/architecture/CLOUD_DEPLOYMENT_GUIDE.md`](../../docs/architecture/CLOUD_DEPLOYMENT_GUIDE.md) for the full VPS setup (Docker, ufw, Let’s Encrypt, Cloudflare).

## Manual CI full build

Actions → **Platform Build and Test** → **Run workflow** → **full_build** builds all cloud portal services.
