# Databases + compose split (renamed)

Naming locked:

| Plane | Postgres container name | What it is |
|-------|-------------------------|------------|
| **Cloud** | `postgres-platform` | The hub DB (internal portal / shared org backend) |
| **Control plane** | `postgres-cp-db` | All non-Cyrex local/platform DBs |
| **Control plane** | `postgres-cyrex-db` | Cyrex only |

**Do not** call anything `lis_db` / `postgres-lis`. Language-intelligence uses a logical DB **inside** `postgres-cp-db` (see below).

Full inventory from today’s `docker-compose.dev.yml` → cloud vs control-plane.

---

## 1. How many databases (control plane)?

**Two Postgres containers:**

1. `postgres-cp-db`
2. `postgres-cyrex-db`

Inside `postgres-cp-db`, keep **three logical databases** (same jobs as today’s auth/core/intelligence, renamed):

| Logical DB name | Old name | Used by |
|-----------------|----------|---------|
| `cp_auth` | `auth_db` / `platform_auth` | local `auth-service` |
| `cp_core` | `deepiri` / `platform_core` | truss, registry, telemetry, jobs, messaging, external-bridge, local gateway |
| `cp_intel` | `intelligence_db` / `platform_intelligence` | `language-intelligence-service`, `mlflow` |

So: **2 Postgres containers**, **3 logical DBs on cp-db + 1 on cyrex** = **4 Postgres databases** on the control-plane side total.

| # | Container | Logical DB | Plane |
|---|-----------|------------|-------|
| 1 | `postgres-platform` | `platform` (or `deepiri_platform`) | **Cloud only** |
| 2 | `postgres-cp-db` | `cp_auth` | Control plane |
| 3 | `postgres-cp-db` | `cp_core` | Control plane |
| 4 | `postgres-cp-db` | `cp_intel` | Control plane |
| 5 | `postgres-cyrex-db` | `cyrex_db` | Control plane / Cyrex stack |

Cloud = **1** Postgres container / **1** app DB.  
Control plane = **2** containers / **4** logical DBs.

---

## 2. What both planes need

| Need | Cloud (`postgres-platform`) | Control plane |
|------|----------------------------|---------------|
| **Auth** | Yes — `auth-service` → `postgres-platform` | Yes — local `auth-service` → `cp_auth` (offline / lab). May also accept **cloud JWT** later |
| **Redis** | Yes — `redis` (sessions/cache) | Yes — `redis` (Cyrex, gateway, jobs, realtime, LIS, etc.) |
| **API entry** | Yes — slim `hub-api` or stripped gateway (**no** Cyrex/LIS routes) | Yes — full `api-gateway` (LIS, Cyrex, jobs, …) |
| **Frontend** | Yes — portal (hub-focused build) | Optional `frontend-dev` against local stack |
| **Postgres backups** | Yes — hub only | Optional for cp/cyrex |
| **Object / vector / GPU stores** | **No** | Yes — minio, milvus, etcd, ollama, etc. as needed |
| **Cyrex DB** | **No** | Yes — `postgres-cyrex-db` |

**Auth is not one shared Postgres across planes.**  
Two auth *services* (or one local + cloud tokens). Same *product idea* (login), different data stores. Cloud users ≠ forcing Cyrex lab DB onto the VPS.

---

## 3. Cloud vs control-plane — every `docker-compose.dev.yml` service

### CLOUD (platform / hub compose)

| Service | Role on cloud |
|---------|----------------|
| `postgres-platform` | **New name** for hub Postgres (replaces using auth+core+intel on VPS) |
| `redis` | Hub cache/sessions |
| `auth-service` | Hub login / invites / API keys → `postgres-platform` |
| `hub-api` *(new; or gutted `api-gateway`)* | Org, events, announcements, artifacts, run catalog — **no** Cyrex/LIS upstreams |
| `frontend` / `frontend-dev` (prod build) | Internal portal |
| `nginx` + `certbot` | Edge (prod compose; not always in dev.yml) |
| `pg-backup` (+ offsite optional) | Backup `postgres-platform` only |

**Cloud logical DB content (`postgres-platform`):**  
identity, teams/projects, announcements, events, artifacts, run_records — **not** cp_intel schemas, **not** cyrex.

---

### CONTROL PLANE (local compose — includes Cyrex stack)

#### Data stores

| Service | Notes |
|---------|--------|
| `postgres-cp-db` | Hosts `cp_auth`, `cp_core`, `cp_intel` |
| `postgres-cyrex-db` | Was `postgres-cyrex` — rename only |
| `redis` | Shared local redis |
| `minio` | LIS + Cyrex object bits as configured |
| `etcd` | Milvus dependency |
| `milvus` | Vectors (Cyrex / AI) |
| `influxdb` | Metrics (Cyrex/telemetry style) |
| `kafka` | Only if `external-bridge-service` stays |

#### App services → which DB

| Service | Goes to | Database |
|---------|---------|----------|
| `auth-service` | Control plane | `cp_auth` on `postgres-cp-db` |
| `api-gateway` | Control plane | `cp_core` (if it still has direct DB) + routes to others |
| `truss` | Control plane | `cp_core` |
| `registry` | Control plane | `cp_core` |
| `telemetry` | Control plane | `cp_core` |
| `jobs` | Control plane | `cp_core` |
| `messaging-service` | Control plane | `cp_core` |
| `external-bridge-service` | Control plane | `cp_core` (+ kafka) |
| `language-intelligence-service` | Control plane | `cp_intel` + minio/`STORAGE_*` |
| `mlflow` | Control plane | `cp_intel` |
| `realtime-gateway` | Control plane | redis (no own PG) |
| `synapse` | Control plane | (as today) |
| `sugar-glider` | Control plane | (as today) |
| `cyrex` | Control plane | `postgres-cyrex-db` / `cyrex_db` |
| `cyrex-interface` | Control plane | talks to cyrex |
| `ollama` | Control plane | local models |
| `frontend-dev` | Control plane (optional) | against local gateway |

#### Dev-only admin (control plane)

| Service | Notes |
|---------|--------|
| `pgadmin` | Point at `postgres-cp-db` / `postgres-cyrex-db` |
| `adminer` | Same |

---

## 4. Split checklist (copy/paste)

### → Cloud compose only
- [ ] `postgres-platform`
- [ ] `redis` (hub)
- [ ] `auth-service` (hub)
- [ ] `hub-api` (or stripped gateway)
- [ ] `frontend` (portal)
- [ ] `nginx`, `certbot`, `pg-backup` (prod)

### → Control-plane compose
- [ ] `postgres-cp-db` (`cp_auth`, `cp_core`, `cp_intel`)
- [ ] `postgres-cyrex-db` (`cyrex_db`)
- [ ] `redis`
- [ ] `minio`, `etcd`, `milvus`, `influxdb`
- [ ] `kafka` (if bridge stays)
- [ ] `auth-service` (local)
- [ ] `api-gateway`
- [ ] `truss`, `registry`, `telemetry`, `jobs`
- [ ] `messaging-service`, `realtime-gateway`
- [ ] `synapse`, `sugar-glider`
- [ ] `language-intelligence-service`
- [ ] `mlflow`
- [ ] `external-bridge-service`
- [ ] `cyrex`, `cyrex-interface`
- [ ] `ollama`
- [ ] `frontend-dev` (optional)
- [ ] `pgadmin`, `adminer`

### → Neither as “shared cloud DB”
- Cyrex tables never in `postgres-platform`
- `cp_intel` / language-intelligence never in `postgres-platform`

---

## 5. Both have auth — what else is duplicated vs shared idea

| Capability | Cloud | Control plane | Shared how? |
|------------|-------|---------------|-------------|
| Auth | Hub users | Lab users / service accounts | Optional: CP trusts hub JWT; still has local auth for offline |
| Redis | Hub | Lab | **Separate** instances |
| Gateway/API | Hub API only | Full gateway | Different binaries/config |
| Frontend | Portal | Dev UI | Same repo, different env flags |
| Events/people/artifacts | **Cloud source of truth** | Read via hub API | Not copied into `cp_core` as SoT |
| Jobs/truss/registry/LIS/Cyrex | No | Yes | Local only |
| Postgres | `postgres-platform` | `postgres-cp-db` + `postgres-cyrex-db` | **Never one container for both planes** |

---

## 6. Picture

```
CLOUD
  postgres-platform     ← 1 container, hub DB
  redis
  auth-service
  hub-api
  frontend
  nginx / certbot / backup

CONTROL PLANE
  postgres-cp-db        ← cp_auth | cp_core | cp_intel
  postgres-cyrex-db     ← cyrex_db
  redis, minio, etcd, milvus, influxdb, [kafka]
  auth-service (local)
  api-gateway
  truss, registry, telemetry, jobs, messaging
  realtime-gateway, synapse, sugar-glider
  language-intelligence-service, mlflow
  external-bridge-service
  cyrex, cyrex-interface, ollama
  [frontend-dev, pgadmin, adminer]
```

---

## 7. Rename map (old → new)

| Old compose service / DB | New |
|--------------------------|-----|
| cloud single postgres / `platform_*` trio on VPS | `postgres-platform` |
| `postgres-auth` + `auth_db` (local) | logical `cp_auth` on `postgres-cp-db` |
| `postgres-core` + `deepiri` | logical `cp_core` on `postgres-cp-db` |
| `postgres-intelligence` + `intelligence_db` | logical `cp_intel` on `postgres-cp-db` (**not** “lis_db”) |
| `postgres-cyrex` + `cyrex_db` | `postgres-cyrex-db` + `cyrex_db` |
