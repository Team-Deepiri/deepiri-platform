# Repo split: deepiri-platform vs deepiri-control-plane

**Decision (2026-08-26):** the **full monorepo body** lives in **deepiri-control-plane**; **deepiri-platform** is the slim cloud VPS portal.

| Repo | What it is | Compose file |
|------|------------|--------------|
| **`deepiri-control-plane`** | Full local/lab stack (Cyrex, LIS, Kafka, Milvus, speech engine) | **`docker-compose.dev.yml`** (main dev compose) |
| **`deepiri-platform`** | Cloud VPS internal portal only | `docker-compose.yml` |

## GitHub layout

1. **`Team-Deepiri/deepiri-control-plane`** — `docker-compose.dev.yml`, `setup-deepiri-dev.sh`, `teams/*.yml`
2. **`Team-Deepiri/deepiri-platform`** — PR #304 cloud-only `docker-compose.yml`

## Cloud services (`docker-compose.yml`)

- `postgres-platform`, `redis`
- `nginx`, `certbot`
- `auth-service`, `api-gateway`, `jobs`, `registry`, `platform-frontend`, `external-bridge-service`
- `pg-backup-offsite` (optional)

## Control plane (`docker-compose.dev.yml`)

See `docs/architecture/DATABASES_AND_COMPOSE_BY_PLANE.md` in **deepiri-control-plane**.

Includes **speech engine** (`livekit` + `speech` in compose and `teams/ai-team.yml`).

## Local dev

```bash
# Cloud portal (VPS-shaped) — deepiri-platform
docker compose -f docker-compose.yml up -d

# Full builder stack — deepiri-control-plane
git clone git@github.com:Team-Deepiri/deepiri-control-plane.git
cd deepiri-control-plane
bash setup-deepiri-dev.sh
```

Control plane may set `DEEPIRI_PLATFORM_URL` to call cloud auth when online.
