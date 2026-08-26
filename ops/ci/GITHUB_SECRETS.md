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

## Manual CI full build

Actions → **Platform Build and Test** → **Run workflow** → **full_build** builds all cloud portal services.
