# Session design log — Cloud platform vs control plane (2026-08-26)

Everything decided / debated this session for Deepiri cloud presence, VPS, portal product, databases, and service split. Companion PR: [#304](https://github.com/Team-Deepiri/deepiri-platform/pull/304).

---

## 0. Starting question

Joe: look at the platform cloud/prod Docker PR; what does David Li want minimum; is Netcup VPS 1000 G12 (~€104/12 mo) enough; don’t pay for a box that can’t run the stack.

---

## 1. David Li — minimum cloud services (from Discord + PR #304)

**Early:** API Gateway + Jobs first (over registry-as-dashboard).

**Cloud control plane (shared):** frontend, auth, gateway, jobs.  
**Local:** heavy / experimental / AI; call cloud gateway with credentials.

**Expanded PR #304 one-box (non-AI):**  
frontend, nginx, api-gateway, auth-service, realtime-gateway, messaging-service, synapse + sugar-glider, jobs, truss, registry, telemetry, language-intelligence (later contested), external-bridge, Postgres, Redis.  
**Off:** Cyrex, Ollama, MLflow, Milvus, etcd, MinIO, Kafka, Influx, admin UIs, prismpipe.

**Postgres:** consolidate 3 containers → one with logical DBs (later renamed for portal).

**David later:** Gateway + Jobs priority; Registry only if compute allows; cloud = frontend/auth/gateway/jobs; local = heavy services.

---

## 2. Cost / VPS sizing

- Platform-only (no AI) lean MVP estimates discussed; one-box ~$20 class.
- Austin: Contabo false economy for prod; Netcup 1000 G12 strong 8GB pick; 2000 for 16GB.
- Joe: try 8GB then 16GB; Netcup 1000 linked by David.
- Checkout: **12M prepaid** €8.70/mo (€104.40 year) vs **hourly NUE** €4.20 setup + €11.56/mo (~€15.76 first charge). **Don’t buy both.**
- Recommendation for trial: **hourly NUE only**.

**Local-prod measurement (idle):** ~477.8 MiB / ~8.64% CPU / 17 containers — huge headroom on 8GB.

**David stress check (2026-08-26):** at rest &lt;~7% RAM; under load memory fine; **CPU** can tighten on 4 cores under concurrent multi-service hit; launch OK; **gap:** document upload not stress-tested.

**Secrets (David):** generated Postgres passwords + INTERNAL_SERVICE_SECRET + CYREX_API_KEY (not in chat); safe defaults filled; DNS URLs localhost; **hard block:** `STORAGE_*`; Google OAuth needed for product login; `BACKUP_OFFSITE_*` moot while disabled.

---

## 3. Month-to-month VPS links (no 12-month lock-in)

- OVHcloud VPS-2: https://www.ovhcloud.com/en/vps/ — US order https://us.ovhcloud.com/vps/configurator/ — 8GB https://www.ovhcloud.com/en/vps/vps-8gb/
- Hetzner: https://www.hetzner.com/cloud/ — CX33 https://www.hetzner.com/cloud/cost-optimized/ — CPX32 https://www.hetzner.com/cloud/regular-performance/ — console https://console.hetzner.com/
- Netcup catalog: https://www.netcup.com/en/server/vps — avoid 12M https://www.netcup.com/en/server/vps/vps-1000-g12-iv-12m — hourly https://www.netcup.com/de/server/vps/vps-1000-g12-stundenbasiert
- Contabo staging only: https://contabo.com/en-us/vps/
- 16GB Netcup: https://www.netcup.com/en/server/vps/vps-2000-g12-iv-12m

Docs: `CHEAP_ONE_BOX_VPS.md` + PR comments.

**Buy for month 1 (practical):** Netcup hourly 1000 G12 **or** OVH VPS-2 + domain + object storage **only if LIS stays**; later decided LIS off cloud → no STORAGE required for hub.

---

## 4. Product pivot — what is cloud *for*?

Rejected vague “shared jobs / see what’s up / GitHub clone.”

**Real job:** invite-only **Deepiri internal portal** for builders:

- Auth / invites  
- Announcements + events (off Discord for durable info)  
- People / teams / **project assignment** (“My Deepiri”)  
- Tools install catalog (deepiri.com tools list)  
- Artifacts / run records as **links + metadata** (not a data lake)  
- Onboarding checklist  
- Vizult dependency graphs  
- Plaky issues mirrored in portal  

**Not cloud:** Cyrex, LIS, Ollama, training, vector DBs.  
**“Tap our server for something”** = identity + org directory + catalog + calendar + later ZepGPU room broker — **not** run models on the $10 VPS.

---

## 5. Hard split — cloud platform vs local control plane

| | **Cloud (`deepiri-platform` on VPS)** | **Control plane (`deepiri-control-plane`, local)** |
|--|--------------------------------------|-----------------------------------------------------|
| Job | Internal portal + org API | Cyrex / Helox / LIS / GPU tool glue |
| Cyrex / LIS | **Never** | Yes |
| Helox | — | Library, no DB |

Docs: `CLOUD_HUB_AND_CONTROL_PLANE_REDESIGN.md`, `PLATFORM_DECOUPLING_PLAN.md`, `DATABASES_AND_COMPOSE_BY_PLANE.md`.

### Naming locked

| Name | Meaning |
|------|---------|
| `postgres-platform` | Cloud portal DB (not “hub”, not lis_db) |
| `postgres-cp-db` | Control plane non-Cyrex (`cp_auth`, `cp_core`, `cp_intel`) |
| `postgres-cyrex-db` | Cyrex only |
| `api-gateway` | Cloud + CP entry — **no `hub-api`** |
| `platform-frontend` | Cloud UI (was frontend / frontend-dev) |

### Cloud services (final list this session)

- `postgres-platform`, `redis`
- `nginx`, `certbot`, `pg-backup` (+ optional offsite)
- `auth-service`
- **`api-gateway`** (slim: no Cyrex/LIS hard deps; proxies Plaky)
- **`jobs`**, **`registry`**
- **`platform-frontend`**
- **`external-bridge-service`** (Plaky sync; cloud without Kafka)
- vizult CLI via jobs (clone on VM)

### Control plane services (final list)

- `postgres-cp-db`, `postgres-cyrex-db`
- `redis`, `minio`, `etcd`, `milvus`, `influxdb`, `kafka`
- `auth-service`, `api-gateway` (full)
- `truss`, `telemetry`, `messaging-service`, `realtime-gateway`
- `synapse`, `sugar-glider` (**not** cloud v1)
- `language-intelligence-service`, `mlflow`
- `external-bridge-service`
- `cyrex`, `cyrex-interface`, `ollama`
- optional local jobs/registry/platform-frontend, pgadmin/adminer

**Synapse on cloud?** No for v1.

---

## 6. `postgres-platform` schema (portal-fit)

Schemas: `identity`, `org`, `portal`, `catalog`, `registry`, `onboarding`, `vizult`, `integrations`, `jobs_meta`.

DDL + seeds: `scripts/database/postgres-init-platform.sql`  
Bootstrap: `scripts/database/postgres-init-platform.sh`  
Guide: `scripts/database/PLATFORM_DB.md`

Legacy auth/core/intelligence multi-db init = **not** cloud SoT (control plane / legacy).

Seeds include roles, flagship projects, 25+ tools, AI-engineer onboarding steps, registry service rows.

---

## 7. Vizult

- Local-first CLI (`deepiri-vizult`); **run on VM via jobs**, ingest `graph.json` → `vizult.*`.
- Not a permanent microservice with its own DB.
- Portal renders dependency graph for onboarding / architecture.

---

## 8. Plaky

- **Owner: `external-bridge-service`** — poll + webhooks → `integrations.plaky_*`.
- **`api-gateway` only proxies** `/api/plaky/*` + JWT.
- Frontend polls (or SSE via gateway→bridge).
- Cloud bridge: HTTP + Postgres, **no Kafka** on cheap VPS.
- Map Plaky assignees → `identity.users` via `integrations.identity_maps`.

---

## 9. STORAGE / LIS

- `STORAGE_*` only required because **language-intelligence** was in compose.
- Cloud direction: **LIS off cloud** → no object-storage hard gate for portal boot.
- LIS + MinIO/S3 stay control plane (`cp_intel`).

---

## 10. Docs on this PR (design trail)

| Doc | Topic |
|-----|--------|
| `docs/architecture/CHEAP_ONE_BOX_VPS.md` | VPS sizing, pricing, exact links, David quotes |
| `docs/architecture/PLATFORM_DECOUPLING_PLAN.md` | Planes / extract control plane |
| `docs/architecture/CLOUD_HUB_AND_CONTROL_PLANE_REDESIGN.md` | Zero Cyrex/LIS on cloud |
| `docs/architecture/DATABASES_AND_COMPOSE_BY_PLANE.md` | DBs + full service lists + Plaky ownership |
| `docs/architecture/PLATFORM_SCHEMA_REDESIGN.md` | Schema goals / API owners |
| `docs/architecture/SESSION_DESIGN_LOG_2026-08-26.md` | **This file** |
| `scripts/database/postgres-init-platform.sql` | Full portal DDL |
| `scripts/database/postgres-init-platform.sh` | Bootstrap |
| `scripts/database/PLATFORM_DB.md` | How to apply |

---

## 11. Open / next (not done in session)

- [ ] Wire cloud `docker-compose.yml` to `postgres-platform` init (drop LIS/`STORAGE_*`/Cyrex env)
- [ ] Slim cloud api-gateway upstreams
- [ ] Rename frontend service → `platform-frontend` in compose
- [ ] Add cloud `external-bridge` without Kafka for Plaky
- [ ] Create `deepiri-control-plane` repo / compose extract
- [ ] Domain + DNS + real secrets for deploy
- [ ] Order VPS (hourly Netcup or OVH)
- [ ] Implement Plaky poller in external-bridge
- [ ] Jobs path for vizult scan → ingest

---

## 12. One-sentence north star

**Cloud = Deepiri’s always-on internal portal (people, projects, tools, events, onboarding, vizult graphs, Plaky) on `postgres-platform` + slim compose; control plane = local Cyrex/LIS/AI stack that may call cloud auth/API — never the other way around for AI data.**
