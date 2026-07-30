# Team inventory audit

Source of truth for this audit: current `team_dev_environments/<team>/{build,start,stop}.sh` and `team_submodule_commands/<team>/pull_submodules.sh`, cross-checked against `docker-compose.dev.yml` and `.gitmodules`.

Generated to freeze what each team needs **before** consolidating into one script + YAML manifests. Do not drop any row without an explicit decision.

---

## One script (not two)

Keep a **single entrypoint** (keep the name `setup-deepiri-dev.sh` or rename to `deepiri` — either is fine):

```bash
./setup-deepiri-dev.sh                 # interactive onboard (clone, prereqs, pick team, pull+build+start+seed)
./setup-deepiri-dev.sh pull ai-team
./setup-deepiri-dev.sh build ai-team
./setup-deepiri-dev.sh start ai-team
./setup-deepiri-dev.sh stop ai-team
./setup-deepiri-dev.sh restart ai-team
./setup-deepiri-dev.sh stop-rm ai-team
```

No separate `deepiri-team` binary. Onboarding is the default (no args / `setup`); day-to-day ops are subcommands on the same file. Team data lives under `teams/*.yml`.

---

## QA tiers (PR #301)

Interactive onboard and day-to-day aliases remap QA capacity to eng team YAMLs — **not** `qa-team.yml`:

| Tier | Alias | Uses |
|---|---|---|
| 1 | `qa-tier-1` / `qa:1` | `teams/frontend-team.yml` |
| 2 | `qa-tier-2` / `qa:2` | `teams/backend-team.yml` |
| 3 | `qa-tier-3` / `qa:3` | `teams/ai-team.yml` (includes livekit + speech) |

`teams/qa-team.yml` remains the optional monolithic full QA stack.

---

## Drift / hazards (fix before implementing)

| Issue | Where | Notes |
|---|---|---|
| `postgres` not in compose | ai-team, ml-team build/stop | Compose has `postgres-auth` / `postgres-core` / `postgres-cyrex` / `postgres-intelligence` only. Scripts still list bare `postgres`. |
| `challenge-service` not in compose | ai-team all scripts | No such service key in `docker-compose.dev.yml` (likely renamed / removed). |
| `jupyter` commented out | ai-team, ml-team, compose | Compose service is commented; scripts comment it too. Keep as disabled in YAML. |
| `platform-analytics-service` not in compose | ml-team build/stop | Listed in build/stop but missing from compose and from ml `start.sh`. |
| ml `start.sh` ≠ build/stop | ml-team | Start only brings up `synapse` + `synapse-sugar-glider` (deps via compose). Build/stop list postgres/redis/influxdb/mlflow/platform-analytics-service/synapse*. |
| infra `stop.sh` uses stale names | infrastructure-team | stop/stop_and_remove list `postgres`, `task-orchestrator`, `engagement-service`, `platform-analytics-service`, `notification-service`, `challenge-service` — none of those match current compose. Build/start match backend. Prefer build/start as canonical for infra. |
| qa start has duplicates | qa-team | SERVICES array repeats postgres*/redis/influxdb, synapse*, messaging-service, frontend-dev, adminer. |
| qa stop missing vs start | qa-team | stop omits `kafka` and `frontend-dev` that build/start include. |
| `deepiri-prismpipe` | all teams | Commented in most SERVICES lists; present in compose and most pull scripts. Treat as optional / coming-soon. |
| `postgres-cyrex` | compose only | In compose; no team script lists it except platform-engineers (`config --services` = all). |
| `deepiri-logger` | `.gitmodules` only | Never pulled by any team `pull_submodules.sh`. |
| `speech` / `livekit` | ai-team | In ai SERVICES; speech code is local (`platform-services/backend/deepiri-speech/`) — not a git submodule today. |
| platform-engineers | compose all | build = sequential `config --services`; start/stop = no service filter (entire project). pull = `git submodule update --init --recursive` (all). |

Canonical recommendation when build ≠ start ≠ stop: **union of build + start** for services the team needs to run; call out stop-only stale names as do-not-port.

---

## Per-team: compose services

### ai-team

**Sources:** build/start/stop/stop_and_remove agree (except MPS start filters `cyrex` + `ollama`).

| Service | Status |
|---|---|
| postgres | **STALE** (not in compose) |
| redis | ok |
| influxdb | ok |
| etcd | ok |
| minio | ok |
| milvus | ok |
| cyrex | ok (excluded on MPS at start) |
| cyrex-interface | ok |
| mlflow | ok |
| jupyter | disabled (commented) |
| challenge-service | **STALE** (not in compose) |
| api-gateway | ok |
| messaging-service | ok |
| realtime-gateway | ok |
| ollama | ok (pull-only image; excluded on MPS at start) |
| synapse | ok |
| synapse-sugar-glider | ok |
| livekit | ok (pull-only) |
| speech | ok |
| deepiri-prismpipe | commented / coming soon |

**Build quirks:** BuildKit on; `ensure_suite_images`; skip build for pull-only (`postgres|redis|influxdb|etcd|minio|milvus|ollama|livekit`); `docker pull ollama/ollama:latest`.

**Start quirks:** `--no-build --no-deps`; MPS backend detection.

### backend-team

**Sources:** build/start/stop/stop_and_remove agree.

| Service |
|---|
| postgres-auth |
| postgres-core |
| postgres-intelligence |
| redis |
| influxdb |
| api-gateway |
| auth-service |
| workflow-orchestrator |
| incentive-engine |
| decision-intelligence |
| communications-hub |
| external-bridge-service |
| adaptive-experience-engine |
| realtime-gateway |
| language-intelligence-service |
| messaging-service |
| synapse |
| synapse-sugar-glider |
| frontend-dev |
| adminer |
| deepiri-prismpipe (commented) |

**Build quirks:** BuildKit **off**; sequential build; `ensure_suite_images`.

### frontend-team

**Sources:** build/start/stop/stop_and_remove agree.

| Service |
|---|
| frontend-dev |
| api-gateway |
| auth-service |
| communications-hub |
| messaging-service |
| realtime-gateway |
| postgres-auth |
| postgres-core |
| postgres-intelligence |

**Build quirks:** BuildKit off; sequential; `ensure_suite_images`.

### infrastructure-team

**Canonical (build + start):** same set as backend-team.

| Service |
|---|
| postgres-auth |
| postgres-core |
| postgres-intelligence |
| redis |
| influxdb |
| api-gateway |
| auth-service |
| workflow-orchestrator |
| incentive-engine |
| decision-intelligence |
| communications-hub |
| external-bridge-service |
| adaptive-experience-engine |
| realtime-gateway |
| language-intelligence-service |
| messaging-service |
| frontend-dev |
| synapse |
| synapse-sugar-glider |
| adminer |
| deepiri-prismpipe (commented) |

**Start quirks:** skip service if submodule Dockerfile missing (api-gateway, auth-service, external-bridge-service, synapse, synapse-sugar-glider).

**Stop/stop_and_remove (DO NOT PORT as-is):** `postgres`, `pgadmin`, `adminer`, `redis`, `influxdb`, `etcd`, `minio`, `api-gateway`, `auth-service`, `task-orchestrator`, `engagement-service`, `platform-analytics-service`, `notification-service`, `external-bridge-service`, `challenge-service`, `realtime-gateway`, `language-intelligence-service`, `messaging-service`, `synapse`, `synapse-sugar-glider`.

### ml-team

**Build/stop list:**

| Service | Notes |
|---|---|
| postgres | **STALE** |
| redis | ok |
| influxdb | ok |
| mlflow | ok |
| jupyter | disabled |
| platform-analytics-service | **STALE** (not in compose) |
| synapse | ok |
| synapse-sugar-glider | ok |

**Start list (actual runtime):** `synapse`, `synapse-sugar-glider` (compose pulls deps: script comments say influxdb, milvus, etcd, minio).

**Build quirks:** BuildKit on; `ensure_suite_images`.

### platform-engineers

| Mode | Behavior |
|---|---|
| services | **all** (`docker compose config --services` / unfiltered up/stop) |
| build | sequential; BuildKit off; `ensure_suite_images` |
| start/stop | entire compose project |

### qa-team

**Canonical union (build + start, deduped):**

| Service | Notes |
|---|---|
| postgres-auth | |
| postgres-core | |
| postgres-intelligence | |
| redis | |
| influxdb | |
| kafka | build + start; **missing from stop** |
| api-gateway | |
| auth-service | |
| workflow-orchestrator | |
| incentive-engine | |
| decision-intelligence | |
| communications-hub | |
| external-bridge-service | |
| adaptive-experience-engine | |
| realtime-gateway | |
| language-intelligence-service | optional at start if image missing |
| messaging-service | |
| synapse | |
| synapse-sugar-glider | |
| frontend-dev | build + start; **missing from stop** |
| adminer | |
| deepiri-prismpipe | commented |

**Start quirks:** phased up (infra first, sleep 3, then backends); language-intelligence optional.

---

## Per-team: submodules (from pull_submodules.sh)

Paths are relative to repo root. `platform-engineers` and conceptually `all` = every path in `.gitmodules`.

| Submodule path | ai | backend | frontend | infra | ml | qa | platform / all | In `.gitmodules`? |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| diri-cyrex | ✓ | | | | | | ✓ | yes |
| diri-helox | | | | | ✓ | | ✓ | yes |
| deepiri-modelkit | ✓ | | | | ✓ | | ✓ | yes |
| deepiri-ollama-utils | ✓ | | | | ✓ | ✓ | ✓ | yes |
| deepiri-suite | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | yes |
| deepiri-web-frontend | | ✓ | ✓ | | | ✓ | ✓ | yes |
| deepiri-logger | | | | | | | ✓* | yes |
| platform-services/backend/deepiri-api-gateway | ✓ | ✓ | ✓ | ✓ | | ✓ | ✓ | yes |
| platform-services/backend/deepiri-auth-service | | ✓ | ✓ | ✓ | | ✓ | ✓ | yes |
| platform-services/backend/deepiri-external-bridge-service | | ✓ | | ✓ | | ✓ | ✓ | yes |
| platform-services/backend/deepiri-language-intelligence-service | | ✓ | | ✓ | | ✓ | ✓ | yes |
| platform-services/shared/deepiri-prismpipe | ✓ | ✓ | | ✓ | | ✓ | ✓ | yes |
| platform-services/shared/deepiri-shared-utils | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | yes |
| platform-services/shared/deepiri-synapse | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | yes |
| platform-services/shared/deepiri-sugar-glider | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | yes |

\* `deepiri-logger` is only covered when platform/all runs full `git submodule update --init --recursive` (or an explicit all-submodules list). No team script names it.

**Not a submodule today (compose-only / local):**

| Path / service | Notes |
|---|---|
| `platform-services/backend/deepiri-speech` | `speech` compose service; untracked local tree in working copy |
| Many backend microservices under `platform-services/backend/` (workflow-orchestrator, etc.) | Built from monorepo paths in compose, not separate gitmodules |

---

## Compose catalog (all services)

See `teams/all-services.yml` — every top-level service key in `docker-compose.dev.yml` (33 active). Commented `jupyter` noted separately.

## Submodule catalog (all repos)

See `teams/all-submodules.yml` — every path in `.gitmodules` (15).

---

## Suggested team YAML shape (later)

Each `teams/<team>.yml` should encode the **canonical** lists above (not the stale stop names), plus flags:

- `services` / `services: all`
- `submodules` / `submodules: all`
- `build.buildkit`, `build.sequential`, `build.ensure_suite_images`
- `build.pull_only` / `build.skip_build`
- `start.no_deps`, `start.exclude_on_mps`, `start.optional`, `start.require_dockerfile`
- disabled / coming-soon comments for jupyter + prismpipe
