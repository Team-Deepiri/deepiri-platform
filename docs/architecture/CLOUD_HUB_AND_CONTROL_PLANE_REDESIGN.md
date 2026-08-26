# Cloud hub vs local control plane — redesign

**Hard rule:** Cyrex and Language Intelligence (LIS) have **zero** coupling in the cloud. They exist only on the **local control plane**. The cloud stack is the Deepiri **internal hub** (portal + org memory + identity), not an AI/doc-intel runtime.

Related: `PLATFORM_DECOUPLING_PLAN.md`, `CHEAP_ONE_BOX_VPS.md`, PR #304.

---

## 1. Two products, two repos (target)

| | **Cloud hub** | **Local control plane** |
|--|---------------|-------------------------|
| **Repo (target)** | `deepiri-platform` (or rename `deepiri-hub`) | `deepiri-control-plane` (new) |
| **Where it runs** | Cheap VPS, always on | Dev laptop / lab box, on demand |
| **Audience** | Deepiri people + invited guests | Builders integrating Cyrex / Helox / LIS / GPU tools |
| **Contains** | Portal FE, auth, hub API, org Postgres | Platform-style services that talk to Cyrex/Helox/LIS, local composes |
| **Must not contain** | Cyrex, LIS, Ollama, Milvus, MinIO-for-LIS, Helox runtime, GPU | — |
| **May call** | Nothing in Cyrex/LIS | Cloud hub auth/API for identity + catalog publish |

```
                    ┌─────────────────────────────┐
   Humans / portal  │  CLOUD HUB (VPS)            │
   Project CLIs ───▶│  auth · hub-api · portal    │
                    │  postgres_hub · redis        │
                    │  NO cyrex · NO lis           │
                    └──────────────▲──────────────┘
                                   │ HTTPS + JWT (optional)
                    ┌──────────────┴──────────────┐
   Local tools ───▶ │  CONTROL PLANE (local)      │
                    │  gateway glue · jobs/truss   │
                    │  LIS · (links to) Cyrex      │
                    │  Helox as library in-process │
                    │  cyrex has its OWN database  │
                    └─────────────────────────────┘
```

---

## 2. What the cloud hub *is* for

Internal Deepiri site + shared org backend:

- Login / invites / API keys  
- Announcements, events, people, teams, project ownership  
- Artifact + test-run **catalog** (metadata + external URLs; not LIS document pipeline)  
- Optional later: ZepGPU room broker (HTTP to ZepGPU, not Cyrex)  
- Soft-fail or hide: old ops/AI/LIS UI routes  

**Not for:** inference, lease/doc intelligence, training, vector DBs.

### What projects “tap the cloud server” for

| Capability | API idea | Not |
|------------|----------|-----|
| Identity | JWT / API key | Cyrex sessions |
| Directory | projects, members, owners | Service mesh for AI |
| Publish / discover | `artifacts`, `run_records` | Storing model weights in hub Postgres |
| Calendar | events, announcements | Discord replacement chat |
| Later rooms | proxy to ZepGPU | Spawning Cyrex |

---

## 3. Cloud hub — allowed services

**In cloud compose (target):**

| Service | Role |
|---------|------|
| `frontend` (portal) | Internal site |
| `nginx` + `certbot` | Edge / TLS |
| `auth-service` | Identity (hub users) |
| `hub-api` *(new or slimmed gateway)* | CRUD for org entities; **no** upstreams to Cyrex/LIS |
| `postgres` | **One** hub database (new schema — see §5) |
| `redis` | Sessions / cache as needed |
| `jobs` | Hub DB backup via `platform.pg_backup`; vizult + sync triggers |

**Explicitly removed from cloud compose / env:**

- `language-intelligence-service` and all `STORAGE_*` hard requirements  
- `CYREX_URL` / `CYREX_BASE_URL` / `CYREX_API_KEY` (delete, don’t stub `disabled-cyrex`)  
- Gateway `depends_on: language-intelligence-service`  
- `platform_intelligence` DB / tenant used for LIS  
- MinIO, Milvus, Ollama, MLflow, Kafka, Cyrex containers  

**Frontend (cloud build):**

- Feature flags default **off**: `VITE_ENABLE_LIS=false`, `VITE_ENABLE_CYREX=false`, `VITE_ENABLE_AI_WORKSPACE=false`  
- Nav centers: Dashboard, Events, People/Team, Announcements, Artifacts, Projects  
- LIS/Cyrex/AI routes: omit from cloud build or show “runs on local control plane only”

---

## 4. Local control plane — what moves here

New repo (or monorepo slice) `deepiri-control-plane`:

| Piece | Notes |
|-------|--------|
| Optional local gateway / BFF | May call **cloud hub** for auth; routes to local Cyrex/LIS |
| LIS + `STORAGE_*` / MinIO | Document/lease plane — local or dedicated box only |
| Cyrex client wiring | Cyrex **keeps its own DB**; control plane does not own it |
| Helox | Library — no DB; used by Cyrex/local processes |
| jobs / truss / telemetry / registry / messaging / realtime / synapse / sugar-glider | Keep here if they exist to drive local AI/tool workflows; **not** required on cloud hub |
| Old `platform_core` / `platform_intelligence` service assumptions | Evolve or retire; do not drag into hub schema |

**Compose:** `docker compose` in control-plane repo must `up` **without** the cloud hub. Optional `.env`: `DEEPIRI_HUB_URL`, `DEEPIRI_HUB_TOKEN`.

---

## 5. Postgres redesign (hub)

**Stop using** `platform_auth` / `platform_core` / `platform_intelligence` as the cloud model. Those names encode the old product split (including intelligence/LIS).

### New cloud database: `deepiri_hub` (single DB, one container)

| Schema / area | Tables (v1) | Purpose |
|---------------|-------------|---------|
| `identity` | `users`, `sessions`, `api_keys`, `invites` | Login, tokens |
| `org` | `teams`, `memberships`, `projects`, `project_members` | Ownership |
| `comms` | `announcements`, `events`, `event_rsvps` | Off-Discord durable posts |
| `catalog` | `artifacts`, `run_records` | Shared links + test-run metadata |

**`artifacts`:** `id`, `project_id`, `type` (`dataset|doc|recording|other`), `title`, `uri` (Drive/S3/HF/Git), `owner_user_id`, `created_at`, `meta jsonb`  

**`run_records`:** `id`, `project_id`, `git_sha`, `status`, `summary jsonb`, `artifact_uris text[]`, `created_by`, `created_at`  

**No tables for:** LIS documents, Cyrex graphs, embeddings, lease pipelines.

### Migration stance

1. **Greenfield hub migrations** in cloud repo (Prisma/Flyway — pick one).  
2. Do **not** migrate `platform_intelligence` into hub.  
3. Old auth users: optional one-time export → `identity.users` if needed; else fresh invites.  
4. Old core/intelligence containers: move with control-plane or delete from cloud compose.

### Local control plane DBs

- Cyrex: **unchanged**, owns its DB.  
- LIS: own DB + object storage as today.  
- Optional local Postgres for leftover platform microservices — **not** the hub schema.

---

## 6. API / gateway redesign (cloud)

Replace “gateway that fans out to every platform microservice” with a **hub API**:

| Route prefix | Owner | Upstream |
|--------------|-------|----------|
| `/api/auth/*` | auth-service | Hub Postgres |
| `/api/hub/*` or REST resources | hub-api | Hub Postgres |
| `/api/lis/*`, `/api/cyrex/*` | **Absent in cloud** | — |

Local control plane may expose those prefixes locally only.

Auth tokens from the hub **may** be accepted by control-plane services later (trust hub issuer). Reverse is not required for v1.

---

## 7. Frontend redesign (cloud)

| Keep / center | Drop or control-plane-only |
|---------------|----------------------------|
| Login, register, profile | Lease upload / LIS document UIs |
| Events, create event | Cyrex / AI workspace as live backends |
| People, friends, team, onboarding | Immersive hub that assumes full AI topology |
| New: Announcements, Artifacts, Projects | Hard dependency on ops/LIS health to boot |
| Dashboard (hub-oriented) | |
| Ops pages | Soft-fail banner: “not on cloud hub” |

---

## 8. Phased execution

### Phase A — Cloud compose quarantine (immediate)

- Remove `language-intelligence-service` from cloud/prod compose.  
- Remove gateway `depends_on` + `LANGUAGE_INTELLIGENCE_*` + all `CYREX_*` from cloud env.  
- Remove `STORAGE_*` required vars from cloud `.env.example`.  
- FE cloud env: LIS/Cyrex flags false; hide nav entries.  
- Confirm `docker compose up` with **no** object storage and **no** Cyrex.

### Phase B — Hub schema + API

- Add `deepiri_hub` migrations (§5).  
- Implement hub-api (or strip gateway to hub-only routes).  
- Wire portal pages to hub APIs (events/people already partially there — retarget).  
- Artifacts + announcements + run_records + projects.

### Phase C — Extract `deepiri-control-plane`

- Move LIS, Cyrex wiring, Helox consumers, optional jobs/truss/realtime/synapse stack.  
- Own compose; document `DEEPIRI_HUB_URL`.  
- Monorepo `deepiri-platform` cloud path no longer submodules LIS/Cyrex for deploy.

### Phase D — ZepGPU rooms (optional)

- Hub button → ZepGPU rooms API (Team-Deepiri). Still **no** Cyrex/LIS.

---

## 9. Success criteria

- [ ] Cloud VPS boots with zero Cyrex and zero LIS containers/env.  
- [ ] No `STORAGE_*` required to start cloud stack.  
- [ ] Hub Postgres has no intelligence/LIS schemas.  
- [ ] Portal usable for auth + events + people + artifacts without local control plane.  
- [ ] Local control plane runs Cyrex/LIS without deploying the cloud compose.  
- [ ] Helox remains a library dependency of local/AI code — never a cloud service.

---

## 10. Non-goals

- Hosting Cyrex or LIS “temporarily” on the VPS.  
- Shared Postgres between hub and Cyrex.  
- Rebuilding Discord.  
- Full RBAC in week one (team admin + invites enough).  
- Moving ZepGPU into the platform monorepo.

---

## Decision summary

| Question | Decision |
|----------|----------|
| Cyrex in cloud? | **No** — local control plane / Cyrex’s own stack only |
| LIS in cloud? | **No** — local control plane only |
| Cloud Postgres? | **New `deepiri_hub` schema** — not auth/core/intelligence as today |
| Shared “something” for projects? | Identity + org directory + artifact/run catalog (+ later ZepGPU rooms) |
| Old platform microservices? | Control plane if AI/tool glue; not required on hub |
