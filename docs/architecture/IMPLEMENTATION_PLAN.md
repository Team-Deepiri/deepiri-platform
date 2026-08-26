# Cloud vs control plane — implementation plan

PR [#304](https://github.com/Team-Deepiri/deepiri-platform/pull/304). Session log: `SESSION_DESIGN_LOG_2026-08-26.md`.

**Hard rule:** Cyrex and LIS never run on the cloud VPS. Cloud = internal portal. Local lab = control plane.

---

## Repo strategy (do not rename platform → control-plane)

| Repo | Role |
|------|------|
| **`deepiri-platform`** (keep name) | Cloud portal on VPS — slim compose, `postgres-platform` |
| **`deepiri-control-plane`** (new, Phase 3) | Local full stack — Cyrex, LIS, Kafka, Milvus, full gateway |
| **`diri-cyrex`**, **`diri-helox`**, service submodules | Stay in own repos; CP references them |

`deepiri-platform` gets **carved down** for cloud. Heavy stack **extracts** to `deepiri-control-plane`.

---

## Phase 0 — Compose quarantine (this PR)

### `deepiri-platform` — files

| File | Change |
|------|--------|
| `docker-compose.yml` | Cloud prod only; remove `pg-backup` container |
| `docker-compose.yml` | `jobs` gets `PG_BACKUP_*` env + `postgres_backups` volume |
| `docker-compose.yml` | `pg-backup-offsite` reads same volume at `/backups/postgres` |
| `platform-services/backend/deepiri-jobs/` | **`platform.pg_backup`** job type + cron scheduler |
| `scripts/database/postgres-init-platform.sql` | Cloud DB schemas |
| `.env.example` | No required `STORAGE_*` / `CYREX_*` for cloud |
| `docs/architecture/*.md` | Service lists, no `pg-backup` service |

### `deepiri-jobs` — done in this PR

| File | Change |
|------|--------|
| `src/platformPgBackup.ts` | `pg_dump`, gzip, retention, job logs |
| `src/backupScheduler.ts` | Cron → enqueue daily with idempotency key |
| `src/jobsService.ts` | Dispatch `platform.pg_backup` |
| `src/server.ts` | Start scheduler; health lists capability |
| `Dockerfile` | `postgresql16-client`, `/backups/postgres` |
| `package.json` | `node-cron` |
| `README.md` | Env vars + manual trigger |

Manual backup: `POST /api/jobs` with `{"type":"platform.pg_backup"}`.

---

## Phase 1 — Portal schema + slim gateway (2–3 weeks)

| Repo / area | Work |
|-------------|------|
| `scripts/database/postgres-init-platform.sql` | Full DDL: identity, org, portal, catalog, onboarding, vizult, integrations |
| `deepiri-auth-service` | Prisma → `identity` + `org` on `postgres-platform` |
| `deepiri-api-gateway` | Slim routes; optional Cyrex/LIS upstreams (503 if unset); `/api/plaky/*` → bridge |
| `deepiri-web-frontend` | Cloud build: LIS/Cyrex off; portal nav |
| `deepiri-external-bridge-service` | Plaky poll/webhook → `integrations.*`; no Kafka on cloud |
| `deepiri-jobs` | `vizult.scan`, `integrations.plaky_sync` job types |
| `deepiri-registry` | `catalog.tools` seed |

Add `docker-compose.cloud.yml` and `docker-compose.control-plane.yml` in monorepo before CP extraction.

---

## Phase 2 — CI (`deepiri-platform`)

Update `.github/workflows/platform-build-and-test.yml`:

- Validate **cloud `docker-compose.yml` only** — boots without LIS/Cyrex/`STORAGE_*`
- Shrink build matrix to cloud services: auth, gateway, jobs, registry, external-bridge, frontend
- Smoke: `jobs` `/health` includes `platform.pg_backup`
- Do **not** gate cloud deploy on full `docker-compose.dev.yml` zoo

---

## Phase 3 — Extract `deepiri-control-plane` (new repo)

Create `Team-Deepiri/deepiri-control-plane`:

```
deepiri-control-plane/
├── docker-compose.yml
├── docker-compose.dev.yml
├── .env.example
├── .gitmodules
├── scripts/database/   # cp_auth, cp_core, cp_intel, cyrex_db init
└── .github/workflows/  # full stack compose smoke
```

**Moves to CP:** LIS, Cyrex, synapse, kafka, minio, milvus, full gateway, truss, telemetry, messaging, realtime, ollama, mlflow.

**Stays in platform:** cloud compose, portal FE, slim gateway, auth, jobs, registry, bridge (Plaky), nginx, certbot.

Optional env on CP: `DEEPIRI_PLATFORM_URL` for cloud JWT when online.

---

## Phase 4 — David Li sizing (post-decoupling)

Re-run local prod on **4c / 8GB** against **redesigned cloud compose** (~11 services):

1. At rest — RSS / % RAM
2. Under load — portal traffic; CPU is watch item

Pre-decoupling ~478 MiB idle is **not** valid for the slim cloud profile.

---

## Cloud service list (target)

```
postgres-platform, redis
nginx, certbot
auth-service, api-gateway (slim)
jobs (+ platform.pg_backup)
registry, platform-frontend
external-bridge-service (Plaky)
pg-backup-offsite (optional)
```

## Control plane service list (target)

```
postgres-cp-db, postgres-cyrex-db
redis, minio, etcd, milvus, influxdb, kafka
auth-service, api-gateway (full)
truss, telemetry, messaging, realtime-gateway
synapse, sugar-glider
language-intelligence-service, mlflow
external-bridge-service
cyrex, cyrex-interface, ollama
```

---

## Success criteria

- [ ] Cloud VPS boots with zero Cyrex/LIS/`STORAGE_*` required
- [ ] `platform.pg_backup` runs on schedule via `jobs`
- [ ] Portal usable without local control plane
- [ ] CP runs full stack without cloud compose
- [ ] CI split: platform = cloud; control-plane = local zoo
