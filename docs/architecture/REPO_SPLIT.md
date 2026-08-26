# Repo split: deepiri-platform vs deepiri-control-plane

**Decision (2026-08-26):** invert the earlier doc default — the **current monorepo body** is the control plane; the **cloud portal** is the slim fork.

| Repo | What it is | Compose file |
|------|------------|--------------|
| **`deepiri-control-plane`** | Full local/lab stack (Cyrex, LIS, Kafka, Milvus, full gateway) | `docker-compose.control-plane.yml` (same as `docker-compose.dev.yml`) |
| **`deepiri-platform`** | Cloud VPS internal portal only | `docker-compose.yml` |

## Target GitHub layout

1. **`Team-Deepiri/deepiri-control-plane`** (new) — push from `dev` + `docker-compose.control-plane.yml`
2. **`Team-Deepiri/deepiri-platform`** — PR #304 branch becomes cloud-only; org may later rename old default branch history or keep both repos side-by-side

Optional org admin step (not required day one):

- Rename archive of full monorepo → `deepiri-control-plane`
- Reset `deepiri-platform` default branch to cloud-only `main`

## Cloud services (`docker-compose.yml`)

- `postgres-platform`, `redis`
- `nginx`, `certbot`
- `auth-service`, `api-gateway`, `jobs`, `registry`, `platform-frontend`, `external-bridge-service`
- `pg-backup-offsite` (optional)

## Control plane services (`docker-compose.control-plane.yml`)

See `docs/architecture/DATABASES_AND_COMPOSE_BY_PLANE.md`.

## Local dev

```bash
# Cloud portal (VPS-shaped)
docker compose -f docker-compose.yml up -d

# Full builder stack
docker compose -f docker-compose.control-plane.yml up -d
```

Control plane may set `DEEPIRI_PLATFORM_URL` to call cloud auth when online.
