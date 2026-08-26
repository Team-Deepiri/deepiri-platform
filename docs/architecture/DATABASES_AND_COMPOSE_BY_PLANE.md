# Database + Compose inventory (redesign)

**Rule:** Cyrex + LIS never run in cloud. Cloud = hub. Control plane + Cyrex stack = local/lab.

Companion: `CLOUD_HUB_AND_CONTROL_PLANE_REDESIGN.md`

---

## 0. Today (what you have now) — snapshot

### Cloud / cheap one-box (`docker-compose.yml` on PR #304)

**One Postgres container** with **3 logical DBs**:

| Logical DB (today) | Role | Used by (today) |
|--------------------|------|-----------------|
| `platform_auth` | Auth | `auth-service` |
| `platform_core` | “Platform” product data | `api-gateway`, `truss`, `registry`, `telemetry`, `jobs`, `messaging-service` |
| `platform_intelligence` | LIS / intel | `language-intelligence-service` |

**Also:** `redis` (shared).

**Services in that compose today:**  
`postgres`, `redis`, `api-gateway`, `frontend`, `nginx`, `certbot`, `pg-backup`, `pg-backup-offsite`, `auth-service`, `truss`, `registry`, `telemetry`, `jobs`, `language-intelligence-service`, `messaging-service`, `realtime-gateway`, `synapse`, `sugar-glider`  
(Cyrex commented out; still has `CYREX_*` env stubs + LIS `STORAGE_*` hard req.)

### Dev compose (`docker-compose.dev.yml`) — historically

| Container | DB name | Port (host) |
|-----------|---------|-------------|
| `postgres-auth` | `auth_db` | 5432 |
| `postgres-core` | `deepiri` / core | 5433 |
| `postgres-cyrex` | `cyrex_db` | 5434 |
| `postgres-intelligence` | `intelligence_db` | 5435 |

### Cyrex stack (owns its own world)

| Store | Purpose |
|-------|---------|
| `postgres-cyrex` / `cyrex_db` | Cyrex AGI / runtime tables (`cyrex.*`) |
| Redis (Cyrex) | Cache / queues as Cyrex defines |
| InfluxDB (optional) | Time-series |
| etcd + MinIO + Milvus | Vector / object for Cyrex RAG plane |
| Helox | **No DB** — library |

---

## 1. Target — specific databases by plane

### A. Cloud hub (`deepiri-platform` / hub compose)

**One Postgres container:** `postgres-hub`  
**One database:** `deepiri_hub`  
**(Optional later: split schemas only — not separate containers unless scale demands.)**

| Schema (inside `deepiri_hub`) | Tables (v1) | Replaces |
|------------------------------|-------------|----------|
| `identity` | `users`, `sessions`, `api_keys`, `invites` | old `platform_auth` / `auth_db` **for hub login only** |
| `org` | `teams`, `memberships`, `projects`, `project_members` | subset of old core “org” ideas |
| `comms` | `announcements`, `events`, `event_rsvps` | events that belong on the internal site |
| `catalog` | `artifacts`, `run_records` | **new** — not LIS docs, not Cyrex artifacts |

**Also on cloud:**

| Store | Name | Purpose |
|-------|------|---------|
| Redis | `redis-hub` | Hub sessions / rate limits / light cache |

**Explicitly NOT on cloud:**

| Store | Why |
|-------|-----|
| `platform_intelligence` / `intelligence_db` | LIS only → control plane |
| `cyrex_db` / `postgres-cyrex` | Cyrex only → Cyrex stack |
| Milvus, MinIO (LIS/Cyrex), etcd, Influx for AI | AI/doc plane |
| Object storage for leases | LIS `STORAGE_*` → control plane |

---

### B. Local control plane (`deepiri-control-plane` compose)

These are **local/lab** databases + services that glue tools — **no Cyrex containers required inside control-plane if Cyrex is a sibling compose**, but LIS + leftover platform microservices live here.

| Container / DB | Database name | Owner service(s) |
|----------------|---------------|------------------|
| `postgres-lis` | `lis_db` (rename from `platform_intelligence` / `intelligence_db`) | `language-intelligence-service` |
| Object store | MinIO bucket **or** external S3 | LIS documents (`STORAGE_*`) |
| `redis-cp` (optional) | — | LIS / local gateway / jobs if needed |
| *(optional)* `postgres-cp-core` | `cp_core` | Only if you still run truss/jobs/registry **locally** for Cyrex workflows — **not** the cloud hub DB |

**Do not** put hub `deepiri_hub` data here as source of truth. Control plane may **read** hub via HTTPS + JWT.

---

### C. Cyrex stack (Cyrex’s own compose / diri-cyrex)

Unchanged ownership — **never** merged into hub Postgres.

| Container | Database / store | Purpose |
|-----------|------------------|---------|
| `postgres-cyrex` | `cyrex_db` | All Cyrex AGI / agent / pipeline tables |
| `redis` (cyrex) | — | Cyrex cache/queues |
| `influxdb` (if used) | — | Metrics |
| `etcd` + `minio` + `milvus` | — | Vector / object for Cyrex |
| Helox | — | **No database** |

---

## 2. Target — docker compose service lists

### Compose 1: Cloud hub  
**File:** `deepiri-platform/docker-compose.yml` (or `docker-compose.hub.yml`)

| Service | In cloud? | Notes |
|---------|-----------|--------|
| `postgres-hub` | **Yes** | DB `deepiri_hub` only |
| `redis-hub` | **Yes** | |
| `auth-service` | **Yes** | Talks only to `deepiri_hub.identity` |
| `hub-api` | **Yes** | New/slim API for org/comms/catalog (replaces fat gateway fan-out) |
| `frontend` | **Yes** | Portal; LIS/Cyrex routes off or hidden |
| `nginx` | **Yes** | |
| `certbot` | **Yes** | |
| `pg-backup` (+ optional offsite) | **Yes** | Hub DB only |
| ~~`api-gateway`~~ as today | Replace or strip | No LIS/Cyrex upstreams |
| ~~`language-intelligence-service`~~ | **No** | |
| ~~`truss` `registry` `telemetry` `jobs`~~ | **No** on cloud v1* | Move to control plane if still needed for AI workflows |
| ~~`messaging-service` `realtime-gateway` `synapse` `sugar-glider`~~ | **No** on cloud v1* | Optional later if portal needs live chat; not required for hub MVP |
| ~~`cyrex` / `cyrex-interface`~~ | **No** | |
| ~~MinIO / Milvus / Ollama / MLflow / Kafka~~ | **No** | |

\*If you want jobs/registry on cloud later for **non-AI** org automation, that’s a product call — default redesign keeps cloud thin (hub only).

**Cloud service count (MVP):** ~8 containers  
`postgres-hub`, `redis-hub`, `auth-service`, `hub-api`, `frontend`, `nginx`, `certbot`, `pg-backup`

---

### Compose 2: Local control plane  
**File:** `deepiri-control-plane/docker-compose.yml`

| Service | In control plane? | DB / store |
|---------|-------------------|------------|
| `postgres-lis` | **Yes** | `lis_db` |
| `minio` (or external S3) | **Yes** (local) | LIS blobs |
| `redis-cp` | **Yes** if needed | |
| `language-intelligence-service` | **Yes** | → `lis_db` + MinIO/S3 |
| `api-gateway` (local BFF) | Optional | Routes to LIS; optional `DEEPIRI_HUB_URL` |
| `jobs` / `truss` / `registry` / `telemetry` | Optional | Only if local AI workflows need them → `cp_core` if you keep a local core DB |
| `messaging` / `realtime` / `synapse` / `sugar-glider` | Optional | Local realtime for tools |
| `frontend` | Optional | Dev against local + hub flags |
| Cyrex containers | **No** (sibling stack) | See Compose 3 |
| Hub postgres | **No** | Call cloud hub over network |

---

### Compose 3: Cyrex stack  
**File:** Cyrex / diri-cyrex compose (existing)

| Service | In Cyrex stack? | Store |
|---------|-----------------|-------|
| `cyrex` (+ interface) | **Yes** | |
| `postgres-cyrex` | **Yes** | `cyrex_db` |
| `redis` | **Yes** | |
| `milvus` / `etcd` / `minio` | As Cyrex requires | |
| `influxdb` / `ollama` / `mlflow` | As Cyrex requires | |
| Helox | Library in Cyrex process | **No DB** |
| LIS | **No** | Control plane |
| Hub | **No** | HTTPS client only if needed |

---

## 3. One-page matrix

### Databases

| Database | Plane | Container | Used by |
|----------|-------|-----------|---------|
| `deepiri_hub` | **Cloud** | `postgres-hub` | auth-service, hub-api |
| `lis_db` | **Control plane** | `postgres-lis` | language-intelligence-service |
| `cp_core` (optional) | **Control plane** | `postgres-cp-core` | local jobs/truss/registry/telemetry only |
| `cyrex_db` | **Cyrex stack** | `postgres-cyrex` | cyrex |
| Redis hub | **Cloud** | `redis-hub` | hub |
| Redis CP | **Control plane** | `redis-cp` | LIS / local services |
| Redis Cyrex | **Cyrex stack** | cyrex redis | cyrex |
| MinIO/S3 LIS | **Control plane** | minio or external | LIS |
| Milvus/MinIO/etcd Cyrex | **Cyrex stack** | cyrex compose | cyrex |

### What happens to today’s 3 logical DBs

| Today | Tomorrow |
|-------|----------|
| `platform_auth` | → evolves into `deepiri_hub.identity` (cloud) |
| `platform_core` | → **split**: hub org/events/catalog pieces → `deepiri_hub`; leftover microservice tables → optional `cp_core` on control plane **or deleted** if unused |
| `platform_intelligence` | → `lis_db` on control plane only |

---

## 4. Service → database map (target)

### Cloud

| Service | Database |
|---------|----------|
| `auth-service` | `deepiri_hub` (identity) |
| `hub-api` | `deepiri_hub` (org, comms, catalog) |
| `frontend` | none (calls APIs) |
| `nginx` / `certbot` / `pg-backup` | n/a / hub dumps |

### Control plane

| Service | Database / store |
|---------|------------------|
| `language-intelligence-service` | `lis_db` + MinIO/S3 |
| optional local `jobs`/`truss`/`registry`/`telemetry`/`messaging`/… | `cp_core` and/or `redis-cp` |
| local gateway | no DB |

### Cyrex stack

| Service | Database / store |
|---------|------------------|
| `cyrex` | `cyrex_db` (+ milvus/minio/redis as designed) |
| Helox | none |

---

## 5. Compose diagrams (target)

```
CLOUD HUB COMPOSE
├── postgres-hub          (deepiri_hub)
├── redis-hub
├── auth-service
├── hub-api
├── frontend
├── nginx
├── certbot
└── pg-backup

CONTROL PLANE COMPOSE
├── postgres-lis          (lis_db)
├── minio                 (or STORAGE_* → external)
├── redis-cp
├── language-intelligence-service
├── [optional] gateway, jobs, truss, registry, telemetry, messaging, realtime, synapse, sugar-glider
└── [optional] postgres-cp-core (cp_core)

CYREX COMPOSE (unchanged ownership)
├── postgres-cyrex        (cyrex_db)
├── redis
├── cyrex (+ interface)
├── milvus / etcd / minio / …
└── (Helox = library, not a container DB)
```

---

## 6. Decisions locked

1. **Cloud has exactly one app DB:** `deepiri_hub` — no intelligence, no cyrex.  
2. **LIS has its own DB on control plane:** `lis_db` — never on VPS hub.  
3. **Cyrex keeps `cyrex_db` in Cyrex stack** — never shared with hub or LIS.  
4. **Helox: no database.**  
5. **Cloud compose MVP services:** hub postgres/redis, auth, hub-api, frontend, nginx, certbot, backup — **not** LIS, **not** Cyrex, **not** AI datastores.  
6. **Old `platform_core` microservice farm** defaults to control plane (optional) or delete from cloud — not required for internal hub.

---

## 7. Implementation order

1. Quarantine cloud compose: drop LIS + STORAGE + CYREX env; stop creating `platform_intelligence` on hub postgres.  
2. Introduce `deepiri_hub` migrations; point auth + hub-api at it.  
3. Stand up control-plane compose with `postgres-lis` + LIS + MinIO.  
4. Leave Cyrex compose as the third stack; document “three composes, three data planes.”
