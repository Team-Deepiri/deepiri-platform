# postgres-platform init (cloud portal DB)

## What this is

Single cloud database for the **new platform direction**:

- identity / org (“My Deepiri”)
- portal (announcements, events)
- catalog (installable tools, artifacts, runs)
- registry (cloud service discovery rows)
- onboarding tracks
- vizult graph snapshots
- Plaky integrations (`external-bridge-service`)
- jobs_meta

**Not here:** Cyrex, language-intelligence, milvus, etc. Those stay on control plane (`postgres-cp-db` / `postgres-cyrex-db`).

## Files

| File | Role |
|------|------|
| `postgres-init-platform.sql` | Full DDL + seeds |
| `postgres-init-platform.sh` | Creates role `deepiri_platform`, DB `platform`, applies SQL |
| `postgres-init-auth.sql` | **Legacy / control-plane** — do not use for cloud portal SoT |
| `postgres-init-core.sql` | **Legacy / control-plane** |
| `postgres-init-intelligence.sql` | **Control plane `cp_intel` only** |
| `postgres-init-multi-db.sh` | **Legacy** auth+core+intelligence trio — replace with platform init on cloud |

## Apply (fresh volume)

```bash
export PLATFORM_DB_PASSWORD='…'
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD='…'
# inside container or with psql reachable:
./scripts/database/postgres-init-platform.sh
```

Compose sketch:

```yaml
postgres-platform:
  image: postgres:16-alpine
  environment:
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: postgres
    PLATFORM_DB_USER: deepiri_platform
    PLATFORM_DB_PASSWORD: ${PLATFORM_DB_PASSWORD}
    PLATFORM_DB_NAME: platform
    PLATFORM_SCHEMA_FILE: /docker-entrypoint-initdb.d/schemas/platform.sql
  volumes:
    - ./scripts/database/postgres-init-platform.sh:/docker-entrypoint-initdb.d/00-init-platform.sh:ro
    - ./scripts/database/postgres-init-platform.sql:/docker-entrypoint-initdb.d/schemas/platform.sql:ro
    - postgres_platform_data:/var/lib/postgresql/data
```

## Service → schema map (cloud)

| Service | Reads/writes |
|---------|----------------|
| `auth-service` | `identity.*`, `org.*` (membership) |
| `api-gateway` | none (proxy) |
| `jobs` | `jobs_meta.*`, ingest `vizult.*` |
| `registry` | `registry.*`, optionally `catalog.tools` |
| `external-bridge-service` | `integrations.*` (Plaky) |
| `platform-frontend` | via APIs only |
