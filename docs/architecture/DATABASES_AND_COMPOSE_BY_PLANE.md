# Databases + compose split (cloud vs control plane)

Naming locked:

| Plane | Postgres container | What |
|-------|-------------------|------|
| **Cloud** | `postgres-platform` | Portal / org / auth / jobs / registry data |
| **Control plane** | `postgres-cp-db` | Local non-Cyrex DBs |
| **Control plane** | `postgres-cyrex-db` | Cyrex only |

No `lis_db`. No `hub-api` — cloud uses **`api-gateway`** (same service; Cyrex/LIS routes off or 503).

---

## 1. Postgres counts

### Cloud
- **1 container:** `postgres-platform`
- Logical DBs / schemas on it (v1):
  - auth (users, sessions, keys, invites)
  - platform core slice used by **gateway, jobs, registry** + portal org/events/artifacts tables  
  - **Not** intelligence / Cyrex

### Control plane
- **2 containers:** `postgres-cp-db`, `postgres-cyrex-db`
- On `postgres-cp-db` (3 logical DBs):
  - `cp_auth` — local auth when developing offline
  - `cp_core` — truss, telemetry, messaging, external-bridge, local gateway extras
  - `cp_intel` — language-intelligence-service, mlflow (old intelligence_db)
- On `postgres-cyrex-db`:
  - `cyrex_db`

**Control plane total:** 2 Postgres containers, 4 logical databases.

---

## 2. What both planes need

| Need | Cloud | Control plane |
|------|-------|---------------|
| **Auth** | `auth-service` → `postgres-platform` | Local `auth-service` → `cp_auth` (lab/offline); can also trust cloud JWT later |
| **Redis** | Yes | Yes (separate instance) |
| **API entry** | **`api-gateway`** | **`api-gateway`** (full upstreams: LIS, Cyrex, …) |
| **Frontend** | **`platform-frontend`** (was `frontend` / `frontend-dev`) | Optional local copy only for offline UI work |
| **Jobs** | **Yes — on cloud** | Optional duplicate only if you need local-only workers |
| **Registry** | **Yes — on cloud** | Optional local if developing registry in isolation |

**Not on cloud:** Cyrex, language-intelligence, mlflow, milvus/minio/etcd for AI, ollama, kafka/bridge unless you explicitly add them later.

---

## 3. `api-gateway` (not “hub-api”)

`api-gateway` stays the single HTTP front door.

| Plane | Gateway behavior |
|-------|------------------|
| **Cloud** | Routes to `auth-service`, `jobs`, `registry`, and portal/BFF-style routes that hit `postgres-platform`. **No** required upstream to Cyrex or language-intelligence (omit or soft-fail). |
| **Control plane** | Full wiring: auth, jobs, registry, truss, telemetry, messaging, realtime, LIS, Cyrex, etc. |

There is **no** separate `hub-api` service. Kill that name.

---

## 4. Cloud compose — services

| Service | DB / store |
|---------|------------|
| `postgres-platform` | platform auth + core (incl. jobs/registry tables) |
| `redis` | sessions/cache |
| `auth-service` | `postgres-platform` |
| **`api-gateway`** | talks to auth/jobs/registry; not Cyrex/LIS |
| **`jobs`** | `postgres-platform` |
| **`registry`** | `postgres-platform` |
| **`platform-frontend`** | Portal UI (rename of `frontend` / `frontend-dev`) |
| `nginx` + `certbot` | prod edge |
| `pg-backup` (+ optional offsite) | `postgres-platform` only |

---

## 5. Control-plane compose — services

### Data
| Service | Notes |
|---------|--------|
| `postgres-cp-db` | `cp_auth`, `cp_core`, `cp_intel` |
| `postgres-cyrex-db` | `cyrex_db` |
| `redis` | |
| `minio`, `etcd`, `milvus`, `influxdb` | AI / LIS / Cyrex deps |
| `kafka` | if external-bridge stays |

### Apps
| Service | DB |
|---------|-----|
| `auth-service` | `cp_auth` |
| `api-gateway` | full local graph |
| `truss` | `cp_core` |
| `telemetry` | `cp_core` |
| `messaging-service` | `cp_core` |
| `external-bridge-service` | `cp_core` (+ kafka) |
| `language-intelligence-service` | `cp_intel` + minio/`STORAGE_*` |
| `mlflow` | `cp_intel` |
| `realtime-gateway` | redis |
| `synapse`, `sugar-glider` | as today |
| `cyrex`, `cyrex-interface` | `postgres-cyrex-db` |
| `ollama` | — |
| `jobs`, `registry` | **optional local** only for offline/dev; **cloud is source for shared org** |
| `platform-frontend` | optional local only |
| `pgadmin`, `adminer` | optional |

---

## 6. Full split from today’s `docker-compose.dev.yml`

### → CLOUD
- `postgres-platform` *(replaces putting auth/core/intel on the VPS)*
- `redis`
- `auth-service`
- `api-gateway` *(cloud config — no Cyrex/LIS hard deps)*
- **`jobs`**
- **`registry`**
- **`platform-frontend`** (was `frontend` / `frontend-dev`)
- prod: `nginx`, `certbot`, `pg-backup`

### → CONTROL PLANE
- `postgres-cp-db` *(was postgres-auth + postgres-core + postgres-intelligence, one container)*
- `postgres-cyrex-db` *(was postgres-cyrex)*
- `redis`
- `minio`, `etcd`, `milvus`, `influxdb`
- `kafka` (with bridge)
- `auth-service` (local)
- `api-gateway` (full)
- `truss`
- `telemetry`
- `messaging-service`
- `realtime-gateway`
- `synapse`, `sugar-glider`
- `language-intelligence-service`
- `mlflow`
- `external-bridge-service`
- `cyrex`, `cyrex-interface`
- `ollama`
- optional: local `platform-frontend` (dev only), `pgadmin`, `adminer`
- optional local copies: `jobs`, `registry` (dev only)

### → NOT on cloud
- Cyrex + `postgres-cyrex-db`
- language-intelligence + `cp_intel` + LIS object storage
- mlflow, ollama, milvus, etcd, minio (AI), kafka/bridge
- truss, telemetry, messaging, realtime, synapse, sugar-glider *(unless you later promote one)*

---

## 7. Picture

```
CLOUD
  postgres-platform
  redis
  auth-service
  api-gateway          ← not hub-api
  jobs                 ← on cloud
  registry             ← on cloud
  platform-frontend    ← on cloud (was frontend / frontend-dev)
  nginx / certbot / pg-backup

CONTROL PLANE
  postgres-cp-db       ← cp_auth | cp_core | cp_intel
  postgres-cyrex-db
  redis, minio, etcd, milvus, influxdb, [kafka]
  auth-service, api-gateway
  truss, telemetry, messaging, realtime-gateway
  synapse, sugar-glider
  language-intelligence-service, mlflow
  external-bridge-service
  cyrex, cyrex-interface, ollama
  [optional local jobs/registry/platform-frontend for offline]
```

---

## 8. Rename map

| Old | New |
|-----|-----|
| “hub-api” | **deleted — use `api-gateway`** |
| cloud hub postgres / deepiri_hub naming | **`postgres-platform`** |
| `frontend` / `frontend-dev` (cloud) | **`platform-frontend`** |
| postgres-auth / core / intelligence (local) | logical DBs on **`postgres-cp-db`** |
| postgres-cyrex | **`postgres-cyrex-db`** |
| lis_db | **never — use `cp_intel`** |
