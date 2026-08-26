# Cloud vs control plane — full service lists + Plaky

## Plaky realtime / sync — where it lives

**Owner: `external-bridge-service` (cloud).**  
**Not** a new microservice. **Not** business logic inside `api-gateway`.

| Piece | Responsibility |
|-------|----------------|
| **`external-bridge-service`** | Plaky API poll + optional webhooks; upsert `integrations.plaky_*` in `postgres-platform`; map assignees → users; expose internal HTTP for “list/get issues” |
| **`api-gateway`** | AuthZ + route `/api/plaky/*` → bridge only (proxy). No Plaky tokens in gateway env if avoidable |
| **`platform-frontend`** | Renders issues; can poll gateway every N seconds or use SSE/WS **from gateway** that just streams bridge responses |
| **`jobs`** | Optional scheduled “full sync” job that hits bridge `/internal/plaky/sync` |

**Realtime enough for portal:** bridge polls Plaky on an interval (e.g. 30–60s) and/or accepts Plaky webhooks → DB. Frontend polls `/api/plaky/issues` or gateway SSE that reads bridge. True sub-second Plaky push is optional later.

**Cloud bridge config:** prefer **HTTP + Postgres**, no Kafka required on the VPS. Kafka stays control-plane if the bridge still uses it locally.

```
Plaky API / webhooks
        │
external-bridge-service  ──writes──▶  postgres-platform.integrations
        ▲
api-gateway  (/api/plaky/* proxy + JWT)
        ▲
platform-frontend
```

---

## Databases (reminder)

| Plane | Postgres |
|-------|----------|
| Cloud | **`postgres-platform`** (schemas: identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta) |
| Control plane | **`postgres-cp-db`** (`cp_auth`, `cp_core`, `cp_intel`) + **`postgres-cyrex-db`** (`cyrex_db`) |

DDL: `scripts/database/postgres-init-platform.sql`

---

## CLOUD platform — full service list

Everything that runs on the VPS for the internal portal.

### Data / edge
| Service | Notes |
|---------|--------|
| `postgres-platform` | Sole cloud app DB |
| `redis` | Sessions / cache / rate limits |
| `nginx` | TLS termination / reverse proxy |
| `certbot` | Certificates |
| `pg-backup` | Nightly dumps of `postgres-platform` |
| `pg-backup-offsite` | Optional; only if `BACKUP_OFFSITE_ENABLED=true` |

### App
| Service | Notes |
|---------|--------|
| `auth-service` | Login, invites, sessions, API keys → `identity` (+ org membership APIs) |
| **`api-gateway`** | Public API door; **no Cyrex/LIS hard deps**; proxies Plaky to bridge |
| **`jobs`** | Shared jobs; vizult scan ingest; optional Plaky full-sync trigger |
| **`registry`** | Tools catalog / service registry for portal |
| **`platform-frontend`** | Portal UI (was frontend / frontend-dev) |
| **`external-bridge-service`** | **Plaky sync + read API** (and later GitHub if needed) |

### On-box tools (not long-running product services)
| Piece | Notes |
|-------|--------|
| `deepiri-vizult` CLI | Installed on VM or job image; run by `jobs` → write `vizult.*` |

### Explicitly NOT on cloud
Cyrex, cyrex-interface, language-intelligence, mlflow, ollama, milvus, etcd, minio (AI), kafka, synapse, sugar-glider, realtime-gateway, messaging-service, truss, telemetry, external-bridge’s Kafka dependency (if any — strip for cloud), adminer/pgadmin (optional ops only).

---

## CONTROL PLANE — full service list

Local / lab compose (includes Cyrex stack). Talks to cloud optionally via JWT + `DEEPIRI_PLATFORM_URL`.

### Data stores
| Service | Notes |
|---------|--------|
| `postgres-cp-db` | Logical DBs: `cp_auth`, `cp_core`, `cp_intel` |
| `postgres-cyrex-db` | `cyrex_db` |
| `redis` | Local |
| `minio` | LIS / Cyrex object (as configured) |
| `etcd` | Milvus dep |
| `milvus` | Vectors |
| `influxdb` | Metrics |
| `kafka` | external-bridge / streaming if used locally |

### App services
| Service | DB / store |
|---------|------------|
| `auth-service` | `cp_auth` (offline lab auth) |
| `api-gateway` | Full upstreams (LIS, Cyrex, truss, …) |
| `truss` | `cp_core` |
| `telemetry` | `cp_core` |
| `messaging-service` | `cp_core` |
| `realtime-gateway` | redis / synapse path |
| `synapse` | local event bus |
| `sugar-glider` | with synapse |
| `language-intelligence-service` | `cp_intel` + minio/`STORAGE_*` |
| `mlflow` | `cp_intel` |
| `external-bridge-service` | local integrations; may use kafka |
| `cyrex` | `postgres-cyrex-db` |
| `cyrex-interface` | UI for Cyrex |
| `ollama` | local models |
| `jobs` | **optional local** (cloud jobs is SoT for org) |
| `registry` | **optional local** |
| `platform-frontend` | **optional** local UI against CP gateway |

### Dev-only
| Service | Notes |
|---------|--------|
| `pgadmin` | |
| `adminer` | |

### Libraries (not compose DB services)
| Piece | Notes |
|-------|--------|
| Helox | Library used by Cyrex / training — **no DB container** |

---

## Side-by-side (from today’s `docker-compose.dev.yml`)

| Service (today) | Cloud | Control plane |
|-----------------|:----:|:-------------:|
| postgres-auth / core / intelligence | → **`postgres-platform`** schemas | → **`postgres-cp-db`** (`cp_auth`/`cp_core`/`cp_intel`) |
| postgres-cyrex | — | **`postgres-cyrex-db`** |
| redis | ✓ | ✓ |
| kafka | — | ✓ |
| influxdb | — | ✓ |
| etcd | — | ✓ |
| minio | — | ✓ |
| milvus | — | ✓ |
| api-gateway | ✓ (slim) | ✓ (full) |
| auth-service | ✓ | ✓ |
| jobs | ✓ | optional |
| registry | ✓ | optional |
| truss | — | ✓ |
| telemetry | — | ✓ |
| messaging-service | — | ✓ |
| realtime-gateway | — | ✓ |
| synapse | — | ✓ |
| sugar-glider | — | ✓ |
| language-intelligence-service | — | ✓ |
| mlflow | — | ✓ |
| external-bridge-service | ✓ (**Plaky**, no Kafka) | ✓ (full) |
| cyrex | — | ✓ |
| cyrex-interface | — | ✓ |
| ollama | — | ✓ |
| frontend / frontend-dev | → **`platform-frontend`** ✓ | optional |
| nginx / certbot / pg-backup | ✓ | — |
| pgadmin / adminer | optional | optional |
| deepiri-vizult | CLI via jobs ✓ | CLI local ✓ |

---

## Cloud compose picture

```
CLOUD VPS
  postgres-platform
  redis
  nginx / certbot / pg-backup
  auth-service
  api-gateway          ← proxies /api/plaky/* 
  jobs                 ← vizult ingest, sync triggers
  registry
  platform-frontend
  external-bridge-service   ← Plaky poll/webhooks + DB upsert
  [vizult CLI on host/job image]
```

## Control plane picture

```
CONTROL PLANE
  postgres-cp-db | postgres-cyrex-db
  redis, minio, etcd, milvus, influxdb, kafka
  auth-service, api-gateway (full)
  truss, telemetry, messaging, realtime-gateway
  synapse, sugar-glider
  language-intelligence-service, mlflow
  external-bridge-service
  cyrex, cyrex-interface, ollama
  [optional jobs/registry/platform-frontend]
```
