# Cyrex / Helox vs deepiri-platform decoupling

Last updated: 2026-08-24  
Owner: Platform + Cyrex/Helox leads  
Status: **Proposed** (decision pending)

## Question

`deepiri-platform` is getting heavy: many submodules, one mega `docker-compose.yml`,
slow clones, noisy submodule drift, and PRs that mix AI-runtime changes with gateway /
frontend / shared-utils churn. Should **`diri-cyrex` and `diri-helox` be decoupled**
from the platform mega-repo for day-to-day develop / compose / release?

Related precedent: [SUGAR_GLIDER_SYNAPSE_REPO_DECISION.md](./SUGAR_GLIDER_SYNAPSE_REPO_DECISION.md)
(extract shared runtimes, keep contract ownership clear).

## Current state

| Piece | Where it lives | How platform uses it |
|-------|----------------|----------------------|
| Cyrex | submodule `diri-cyrex` | compose service `cyrex` + `cyrex-interface` |
| Helox | submodule `diri-helox` | training / learning path; Synapse publisher |
| Modelkit / Ollama utils / logger / suite | more submodules | Cyrex/Helox + CI |
| Backend gateway, auth, LIS, frontend | more submodules | product shell |
| Shared: Synapse, Sugar Glider, Prismpipe | more submodules | event bus between AI + product |

Pain today:

- **Clone / CI weight** — recursive submodule update is large and flaky.
- **Compose coupling** — bringing up Cyrex pulls Redis/Milvus/Postgres/MinIO/Ollama
  whether you care about the web product or not.
- **Branch entropy** — platform branch status is often a sea of dirty submodule pointers
  unrelated to the change you want to ship.
- **Release coupling** — bumping Cyrex for an AGI experiment forces a platform PR even
  when the product shell did not change.
- **Cognitive load** — AGI tracks (pipeline, MCP, artifacts) and product tracks (auth,
  gateway, LIS) share one "platform" mental model.

## Options

### A — Keep as-is (monorepo-of-submodules)

Cyrex/Helox stay first-class platform submodules; one compose file to rule them all.

- **Pros:** single `docker compose up` story; one place for env secrets; existing onboarding.
- **Cons:** heaviness stays; every AI PR still touches platform gitlinks.

### B — Soft decouple (recommended near-term)

Keep git submodules **and** gitlinks, but split **compose + DX**:

1. **`docker-compose.cyrex.yml`** (or `compose/cyrex-stack.yml`) — Cyrex + Helox +
   their deps (postgres-cyrex, redis, milvus/minio/etcd, ollama, elkedel, optional
   sugar-glider). Product shell not required.
2. **`docker-compose.yml`** — product shell (gateway, auth, frontend, LIS) with
   optional `profiles: [agi]` to attach Cyrex/Helox.
3. **Contract package** — published env + health URLs (`CYREX_BASE_URL`,
   `ELKEDEL_BASE_URL`, Synapse topics) so product and AGI stacks talk without
   sharing a repo checkout.
4. **Release**: Cyrex/Helox tag independently; platform pins submodule SHAs when the
   product shell needs a bump (same as today, but fewer forced bumps).

- **Pros:** unblocks Elkedel/Cyrex iteration without dragging the whole platform;
  reversible; matches how Sugar Glider already grew a local compose overlay.
- **Cons:** two compose files to document; env parity must be tested.

### C — Hard decouple (separate meta-repo)

Move Cyrex+Helox(+modelkit+elkedel) into something like `deepiri-agi` /
`deepiri-cyrex-stack` with its own compose, CI, and release train. Platform becomes
product-only and consumes Cyrex as a **remote service** (image + URL), not a submodule.

- **Pros:** cleanest ownership; lightest platform; AGI team ships on its own cadence.
- **Cons:** highest migration cost; duplicate secrets/CI; need a real service contract
  and versioning story; breaks "one clone for everything" onboarding.

## Recommendation

**Do B now. Revisit C after Elkedel is wired and Cyrex MCP host exists.**

Reasons:

1. The immediate pain is **compose + PR blast radius**, not the existence of gitlinks.
2. Elkedel (and future sensory services) fit the AGI stack, not the product shell —
   soft decouple gives them a home without a repo migration.
3. Hard extract (C) before MCP + artifact contracts stabilize will create two half-broken
   stacks. Soft decouple buys the learning.
4. Precedent: Sugar Glider/Synapse already use overlay compose + explicit contracts.

## Decision rubric

| Criterion | Weight | A | B | C |
|-----------|--------|---|---|---|
| Ship Elkedel↔Cyrex this month | high | ok | **best** | slow |
| Reduce platform PR noise | high | poor | **good** | best |
| Onboarding simplicity | med | best | good | poor |
| Independent AGI release | med | poor | good | **best** |
| Migration risk | high | none | low | high |

## Migration sketch (if B accepted)

1. Extract Cyrex-relevant services from `docker-compose.yml` into
   `docker-compose.cyrex.yml` (include `elkedel`, `elkedel-mcp`).
2. Add compose profile `agi` on the main file that `include`s the Cyrex stack.
3. Document: "product only" vs "AGI only" vs "full" bring-up in
   `docs/getting-started`.
4. Keep submodule pins; stop requiring platform PRs for Cyrex-only experiments
   (developers work in `diri-cyrex` / `deepiri-elkedel` remotes directly).
5. After 2–3 release cycles, re-score hard extract (C).

## What this is *not*

- Not deleting Cyrex/Helox from `.gitmodules` tomorrow.
- Not making Helox mandatory for Elkedel (Elkedel → Cyrex first; Helox later for
  learning from visual corrections).
- Not splitting Synapse/Sugar Glider again — reuse the existing contract decision.

## Ask for leadership

Approve **Option B (soft decouple)** as the working direction so Elkedel platform
wire-up lands in a Cyrex-local compose overlay without waiting on a mega-repo extract.
