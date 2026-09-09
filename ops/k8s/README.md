# Kubernetes manifests — repo split

| Repo | Compose | K8s scope |
|------|---------|-----------|
| **deepiri-platform** (cloud VPS) | `docker-compose.yml` | Cloud portal services only |
| **deepiri-control-plane** | `docker-compose.dev.yml` | Full dev/lab stack |

## Cloud portal (`deepiri-platform`)

**Services:** `postgres-platform`, `redis`, `nginx`, `certbot`, `auth-service`, `api-gateway`, `jobs`, `registry`, `platform-frontend`, `external-bridge-service`, optional `pg-backup-offsite`

**ConfigMaps (committed):** see [`configmaps/README.md`](configmaps/README.md)

**Secrets (local only, never commit):**
- Root env file: `ops/k8s/secrets/.env` — used by `docker-compose.yml`
- Per-service: `ops/k8s/secrets/<service>-secret.yaml`
- Templates: [`secrets-templates/cloud-portal/`](secrets-templates/cloud-portal/)

**Generate compose env from k8s:**
```bash
./ops/k8s/generate-env-files.sh   # cloud services only on this repo
```

## Control plane (`deepiri-control-plane`)

Full stack configmaps (Cyrex, LIS, speech, Kafka, etc.) live in the **control-plane repo** under the same paths. The copies still present here under `configmaps/` are **legacy references** during the split — do not use them for cloud deploy.

## Secrets archives (Discord)

| Archive | Owner | Contents |
|---------|-------|----------|
| `secrets.7z` (existing) | → **control-plane** | Auth/core/intel/cyrex DB passwords, Cyrex keys, ML keys — **edit for control-plane compose** |
| `cloud-portal-secrets.7z` (new) | **@daev1005** | `POSTGRES_PASSWORD`, `PLATFORM_DB_*`, `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `REDIS_PASSWORD`, OAuth, Plaky, backup offsite |

See [`secrets-templates/SECRETS_SPLIT.md`](secrets-templates/SECRETS_SPLIT.md).
