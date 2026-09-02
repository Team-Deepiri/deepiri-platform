# Secrets split — cloud portal vs control plane

**Owner action:** @daev1005 (David Li) — update Discord archives and local `ops/k8s/secrets/` trees.

## Two archives (Discord)

| Archive | Repo | Who creates |
|---------|------|-------------|
| **`secrets.7z`** (existing) | **deepiri-control-plane** | David — **edit** current bundle: rename DB vars to match `docker-compose.dev.yml` (auth/core/intel/cyrex Postgres), keep Cyrex/ML/OAuth keys that belong on lab stack |
| **`cloud-portal-secrets.7z`** (new) | **deepiri-platform** | David — **new** 7z for VPS deploy only |

Do **not** mix cloud VPS secrets into the control-plane bundle or vice versa.

## Cloud portal (`cloud-portal-secrets.7z` → `deepiri-platform`)

Extract into `ops/k8s/secrets/` (gitignored):

| File | Required keys |
|------|----------------|
| `.env` | `POSTGRES_PASSWORD`, `PLATFORM_DB_PASSWORD`, `PLATFORM_DB_NAME`, `PLATFORM_DB_USER`, `REDIS_PASSWORD`, `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `CORS_ORIGINS`, `VITE_API_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `PLAKY_API_TOKEN` (optional), `BACKUP_OFFSITE_*` (optional) |
| `api-gateway-secret.yaml` | `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `REDIS_PASSWORD`, `DB_PASSWORD` (= `PLATFORM_DB_PASSWORD`) |
| `auth-service-secret.yaml` | `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `REDIS_PASSWORD`, `GOOGLE_CLIENT_SECRET` |
| `registry-secret.yaml` | `REDIS_PASSWORD`, `GITHUB_TOKEN` (optional) |
| `jobs-secret.yaml` | `PG_BACKUP_PASSWORD` (= `PLATFORM_DB_PASSWORD`) |
| `external-bridge-service-secret.yaml` | `REDIS_PASSWORD`, `GOOGLE_CLIENT_SECRET`, `PLAKY_API_TOKEN` |

Templates (no real values): [`cloud-portal/`](cloud-portal/)

## Control plane (`secrets.7z` → `deepiri-control-plane`)

Keep / migrate existing Discord bundle here. Edit for multi-DB dev compose:

- `POSTGRES_AUTH_PASSWORD`, `POSTGRES_CORE_PASSWORD`, `POSTGRES_INTELLIGENCE_PASSWORD`, `POSTGRES_CYREX_PASSWORD`
- `INTERNAL_SERVICE_SECRET`, `JWT_SECRET`, `REDIS_PASSWORD`, `INFLUXDB_TOKEN`
- `CYREX_API_KEY`, `OPENAI_API_KEY`, `WANDB_API_KEY`, etc.
- Per-service `ops/k8s/secrets/<service>-secret.yaml` for full stack (see control-plane `secrets-templates/control-plane/`)

## Bootstrap locally

```bash
# Cloud VPS
cp ops/k8s/secrets-templates/cloud-portal/dot.env.example ops/k8s/secrets/.env
# fill from cloud-portal-secrets.7z

# Control plane
cp ops/k8s/secrets-templates/control-plane/dot.env.example ops/k8s/secrets/.env
# fill from secrets.7z (edited)
```

Never paste secret values into GitHub issues, PR comments, or chat.
