# PrismPipe / Bedd — change inventory, PR plan, improvements

Updated 2026-07-27 after service-impact integration + full gates.

## Honest value to auth / other services

| Claim | Reality |
|-------|---------|
| Helps real `/api/auth` login/register/JWT traffic | **No** — gateway still proxies `/api/auth` → auth-service directly |
| Helps auth under repeated *identical health pipelines* | **Yes** — ComputationGraph dedup avoids re-hitting auth+LIS |
| Makes auth itself faster | **No** |
| Without sharing, PrismPipe load on auth/LIS | **Worse** — every cold/noshare call probes auth+LIS (+ optional cyrex) |
| Non-interference under warm prism load | **Proven** — auth p95 stays healthy |

**Bottom line:** PrismPipe is a useful multi-service *façade + dedup cache* for composite probes today — not a sidecar that accelerates auth business APIs. Real product value lands when capability nodes wrap real auth/LIS/Cyrex *operations*, not only `/health`.

## Latest gates

| Gate | Verdict | Notes |
|------|---------|-------|
| Unit / bench | PASS (prior) | |
| System (`REQUIRE_USEFUL=1 REQUIRE_GATEWAY=1`) | USEFUL | |
| Latency A/B | PASS | warm ~2ms vs direct ~1.5ms |
| Throughput | PASS | ~1540 RPS warm |
| **Service impact integration** (new) | **GO** | cold ~12ms (cyrex skipped), warm ~1.2ms, auth under load OK |
| Gateway `/api/users/health` → auth | 200 | real auth path unchanged |

Cold path fix: empty `CYREX_URL` skips cyrex hop (was ~10s DNS when cyrex down).

## Repos / PRs

### PR-1 — `deepiri-prismpipe`
- **Branch:** `josep/feature/prismpipe-organic-wiring`
- **Base:** `main`
- **Includes:** Organic Pipe fixes, Redis/Postgres storage, organism API, Deepiri nodes + `/pipelines/deepiri/health`, benches/tests, Bedd multi-stage Dockerfile (`ghcr.io/team-deepiri/bedd:0.8`), cyrex skip, `WEB_CONCURRENCY=1`, gunicorn timeout
- **Status:** uncommitted / unpushed local work on branch

### PR-2 — `deepiri-api-gateway`
- **Branch:** `josep/feature/prismpipe-gateway-wiring`
- **Change:** `/api/prism` proxy behind `PRISMPIPE_ENABLED` + `PRISMPIPE_URL` (~13 lines in `src/server.ts`)
- **Small, ship second**

### PR-3 — `deepiri-language-intelligence-service` (Bedd)
- **Branch:** `josep/feature/bedd-runtime-embed` (already has commit + local Dockerfile tweaks for multi-stage `0.8`)
- **Align** Dockerfile with published `bedd:0.8` multi-stage (no local retag)

### PR-4 — `deepiri-platform` (superproject)
- **Branch:** `josep/feature/bedd-bus-integration-perf` (or fresh prism branch after cyrex conflict resolved)
- **Files:** `docker-compose.dev.yml` (`x-bedd-build-args`, prism/LIS/gateway env, JWT_SECRET, CYREX_URL empty default), `.env.example`, `ops/k8s/configmaps/api-gateway-configmap.yaml`, `scripts/dev/prismpipe/*`, docs
- **After** PR-1..3 merge: bump submodule SHAs
- **Do not** force-reset unrelated dirty submodules (cyrex/helox/frontend/…)

### Auth service
- **No prism PR** — stayed on `main`; unchanged by this work

## Merge order

1. prismpipe  
2. api-gateway  
3. LIS Bedd (can parallel with 1–2)  
4. platform compose/scripts + submodule bumps  

## Improvements backlog

### P0
1. GHCR `read:packages` + rebuild from real `ghcr.io/team-deepiri/bedd:0.8` (compose already pinned; local rebuild used `deepiri-bedd:local` only as emergency)
2. Redis-backed ComputationGraph before `WEB_CONCURRENCY>1` / multi-replica
3. Migrate other workers off `COPY --from=${BEDD_IMAGE}` → multi-stage `FROM … AS bedd`, bump `0.6` → `0.8`

### P1 — make PrismPipe *actually* help services
4. Real capability nodes: auth validate/session, LIS ingest/lease, Cyrex inference — not only `/health`
5. Optional request coalescing / single-flight for identical in-flight cold probes (helps auth under thundering herd)
6. Bedd skill smoke in regression (`bedd doctor` / `eval echo` in container)
7. Compose profile `prism` (redis+auth+LIS+prismpipe+gateway) to avoid `--no-deps` / synapse bake failures

### P2
8. Metrics: hit_ratio, useful rate, auth probe QPS saved
9. Latency gate: refine dual threshold when absolute overhead is tiny
10. Seal/load local JWT secrets properly (stop compose one-offs)

## Commands

```bash
LIS_URL=http://127.0.0.1:5009 ./scripts/dev/prismpipe/service_impact_integration.sh
REQUIRE_USEFUL=1 REQUIRE_GATEWAY=1 LIS_URL=http://127.0.0.1:5009 \
  ./scripts/dev/prismpipe/full_regression.sh
```
