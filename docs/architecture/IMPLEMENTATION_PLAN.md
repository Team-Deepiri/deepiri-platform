# Cloud vs control plane — implementation plan

PR [#304](https://github.com/Team-Deepiri/deepiri-platform/pull/304). Session log: `SESSION_DESIGN_LOG_2026-08-26.md`.

**Hard rule:** Cyrex and LIS never run on the cloud VPS.

---

## Repo strategy (updated 2026-08-26)

| Repo | Role |
|------|------|
| **`deepiri-control-plane`** (new) | Current monorepo full stack — Cyrex, LIS, Kafka, dev compose |
| **`deepiri-platform`** (slimmed) | Cloud portal on VPS — `docker-compose.yml` only |

See `REPO_SPLIT.md`.

---

## Phase 0 — Done / in PR #304

- [x] Slim `docker-compose.yml` — cloud portal only
- [x] `docker-compose.control-plane.yml` — copy of full dev stack
- [x] `platform.pg_backup` in jobs
- [x] `postgres-init-platform.sql` + init script
- [x] Architecture docs + service lists
- [x] CI validates cloud `docker-compose.yml` (no LIS/Cyrex)
- [ ] Create `Team-Deepiri/deepiri-control-plane` repo and push
- [ ] Gateway code: soft-fail optional upstreams (follow-up PR in api-gateway submodule)
- [ ] Frontend cloud build flags wired in FE repo
- [ ] External-bridge Plaky poll without Kafka (follow-up in bridge submodule)

---

## Phase 1 — Portal wiring

- Auth/registry/jobs/bridge → `postgres-platform` / `platform` DB
- Gateway slim routes + `/api/plaky/*` proxy
- FE portal nav (events, people, tools, Plaky)
- `vizult.scan`, `integrations.plaky_sync` job types

---

## Phase 2 — CI split

| Repo | CI gate |
|------|---------|
| `deepiri-platform` | `docker compose -f docker-compose.yml config` + cloud service builds |
| `deepiri-control-plane` | `docker-compose.control-plane.yml` + full stack smoke |

---

## Cloud service list

```
postgres-platform, redis
nginx, certbot
auth-service, api-gateway, jobs, registry, platform-frontend, external-bridge-service
pg-backup-offsite (optional)
```

## Control plane service list

```
postgres-cp-db, postgres-cyrex-db
redis, minio, etcd, milvus, influxdb, kafka
auth-service, api-gateway (full)
truss, telemetry, messaging-service, realtime-gateway
synapse, sugar-glider
language-intelligence-service, mlflow
external-bridge-service
cyrex, cyrex-interface, ollama
jobs, registry, platform-frontend (optional)
```
