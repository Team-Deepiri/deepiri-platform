# Platform decoupling plan

> **Superseding design (Cyrex/LIS out of cloud):**  
> [`CLOUD_HUB_AND_CONTROL_PLANE_REDESIGN.md`](./CLOUD_HUB_AND_CONTROL_PLANE_REDESIGN.md)  
> **Hard rule:** Cyrex and Language Intelligence have **zero** cloud coupling — local control plane only. Cloud = internal hub (auth, org, events, artifacts).

## What the shared cloud + web frontend are *for* (target)

For Deepiri **devs and ecosystem builders**, not end-user AI/doc products.

| Surface | Should be used for |
|---------|-------------------|
| **Web frontend (developer portal)** | Sign in. See what’s available (services, envs, health, ownership). Open docs/links. Trigger **shared** actions (jobs). Account/settings. Hide product lanes that aren’t hosted here. |
| **Auth** | One identity for humans and service clients across Deepiri tools. |
| **API gateway** | Single public HTTPS entry + JWT. Route to control-plane services. Soft-fail when a product plane is offline. |
| **Jobs (+ Truss if needed)** | Shared async work: QA/match/check/deploy helpers that shouldn’t only live on one laptop. |
| **Registry (when ready)** | Catalog of platform services, URLs, health, metadata — discovery for builders. |
| **Realtime / messaging (optional)** | Live portal updates and notifications — only if the portal UX needs them. |

**Not this plane’s job:** Cyrex inference, Ollama, training, Milvus, LIS document pipelines, Kafka toys, GPU work.

**Contract:** local or product-box workloads call **gateway + auth (+ jobs)** when they need shared identity or shared actions. They do not require the full monorepo compose to be up in the cloud.

---

## Target topology

```
deepiri-control-plane/          ← thin always-on cloud (this plan’s “platform”)
  frontend (portal)
  api-gateway
  auth-service
  jobs
  [truss, registry, telemetry, messaging, realtime — opt-in]
  postgres, redis, nginx
  compose: docker-compose.yml (control-plane profile only)

deepiri-cyrex/ (or diri-cyrex)  ← own compose; optional call into control plane
deepiri-language-intelligence/  ← own compose + object storage
deepiri-* (zepgpu, elkedel, …) ← own compose per product/tool
```

Cloud VPS runs **only** `deepiri-control-plane`. Everything else is local, GPU box, or a later second machine.

---

## Principles

1. **Planes, not one mega-compose.** Control plane ≠ AI plane ≠ doc plane.
2. **Compose coupling is packaging, not truth.** `depends_on` and hard `${ENV:?}` must not force product services into cloud.
3. **Gateway soft-deps.** Missing backends → 503/feature-flag, not boot failure.
4. **Portal shows only what’s deployed.** No LI/AI nav when those planes aren’t up.
5. **One identity, many products.** Auth (+ JWT) is the shared seam; products keep their own DBs/storage.
6. **No big-bang rewrite.** Strangle the monorepo; extract when a plane has a clear owner and compose.

---

## Option A — New control-plane repo (recommended direction)

**Repo:** `deepiri-control-plane` (or rename path under platform later).

**Contains:**
- Portal frontend (or submodule)
- `api-gateway`, `auth-service`, `jobs` (+ optional registry/truss/telemetry/messaging/realtime)
- Shared utils only as needed
- One `docker-compose.yml` + `.env.example` with **no** Cyrex/LIS/MinIO/Kafka
- Deploy docs for cheap one-box VPS

**Does not contain:** Cyrex, Helox, Ollama, LIS, prismpipe, milvus, kafka, mlflow.

**Monorepo (`deepiri-platform`):** becomes the **integration / full-local** workspace: submodules + `docker-compose.dev.yml` that can still wire everything for contributors who want the zoo. Prod cloud does **not** use that file.

---

## Option B — Stay in monorepo, split by compose profiles (faster, less clean)

Keep `deepiri-platform`, add:

```bash
docker compose --profile control-plane up   # cloud
docker compose --profile ai up              # local Cyrex/Ollama/…
docker compose --profile lis up             # LIS + MinIO/S3
```

Profiles must not hard-require cross-profile env (LIS `STORAGE_*` only under `lis`).

Gateway: optional upstreams. Frontend: build-time or runtime feature flags per profile.

Use this as **Phase 0–1**; graduate to Option A when ownership is clear.

---

## Option C — Split every platform microservice to its own repo (not first)

Only after Option A is stable. High ops cost (CI, versioning, shared-utils). Prefer **one control-plane repo** over N nano-repos until teams need independent release cadence.

---

## Product / AI planes — individual composes

| Plane | Lives where | Own compose includes | Talks to control plane via |
|-------|-------------|----------------------|----------------------------|
| Cyrex / AGI | `diri-cyrex` (+ Helox as needed) | cyrex, its Postgres, redis/vector as required | Gateway JWT; optional jobs hooks |
| Language Intelligence | LIS repo/service tree | LIS + object storage (MinIO local / S3 cloud) | Gateway JWT |
| Training / GPU | training-orchestrator / zepgpu / etc. | GPU stack | Jobs or direct API with credentials |
| Speech / other tools | their repos | their compose | Gateway when shared identity needed |

Rule: **each product compose must `up` without the monorepo root compose.** Optional `.env` lines: `DEEPIRI_GATEWAY_URL`, `DEEPIRI_AUTH_…`.

---

## Platform services — what stays vs moves

| Service | Control plane? | Notes |
|---------|----------------|-------|
| api-gateway | **Yes** | Soft-fail upstreams |
| auth-service | **Yes** | |
| jobs | **Yes** | |
| truss | Optional | Keep if jobs alone aren’t enough for workflows |
| registry | Optional month 2+ | Discovery for portal; don’t block launch |
| telemetry | Optional | |
| messaging + realtime + synapse/sugar-glider | Optional | Only if portal needs live UX |
| language-intelligence | **No** | Own plane + storage |
| external-bridge | **No** | Kafka-heavy; product/integration plane |
| Cyrex / Ollama / MLflow / Milvus / MinIO / Kafka | **No** | AI/data plane |

---

## Phased execution

### Phase 0 — Scope cloud (this week)

- Document: cloud = control plane only (this file + `CHEAP_ONE_BOX_VPS.md`).
- Buy hourly VPS + domain.
- Deploy: frontend, nginx, auth, gateway, jobs, postgres, redis.
- Do **not** deploy LIS/AI; remove hard `STORAGE_*` gate from control-plane compose.
- Portal: hide LI/AI routes.

### Phase 1 — Soft decoupling in monorepo

- Compose profiles: `control-plane` | `lis` | `ai`.
- Gateway: optional service URLs; health degraded not fatal.
- Frontend feature flags: `VITE_ENABLE_LIS`, `VITE_ENABLE_AI`, default false in cloud env.
- CI: control-plane compose config + boot smoke without LIS/AI.

### Phase 2 — Product composes stand alone

- Cyrex: documented `docker compose` in its tree; no root compose required.
- LIS: same + MinIO/S3 local defaults.
- Each ships a short “how to point at control plane” note.

### Phase 3 — Extract `deepiri-control-plane` repo

- Move control-plane services + portal + compose.
- Monorepo keeps submodules / full-dev compose for integration.
- Cloud deploy tracks control-plane repo only.
- Version shared-utils via package/tag, not “must clone whole platform.”

### Phase 4 — Only if needed

- Split hot services to own repos for release cadence.
- Second VPS / GPU box for AI plane; still auth via control plane.

---

## Success criteria

- Dev can run **only** control plane and do: login → portal → call gateway → enqueue a job.
- Dev can run **Cyrex (or LIS) alone** locally without bringing up the monorepo zoo.
- Cloud VPS boots with **no** object-storage credentials and **no** GPU.
- Portal never advertises services that aren’t deployed.
- “Shared backend” means **identity + entry + shared jobs (+ discovery later)** — not “all Deepiri products.”

---

## Explicit non-goals (near term)

- Rewriting all services into one language/framework.
- Micro-repos for every Node service before control plane is extracted.
- Hosting Cyrex/LIS on the cheap one-box VPS.
- Perfect purity of shared-utils; good enough boundaries first.
