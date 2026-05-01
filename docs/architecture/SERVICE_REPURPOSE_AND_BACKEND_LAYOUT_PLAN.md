# Service Repurpose And Backend Layout Plan

## Scope

This plan covers:

- GitHub org scan findings for Team-Deepiri
- Repurpose strategy for:
  - `deepiri-challenge-service`
  - `deepiri-engagement-service`
  - `deepiri-notification-service`
  - `deepiri-platform-analytics-service`
  - `deepiri-realtime-gateway`
  - `deepiri-task-orchestrator`
- Proposed post-repurpose `platform-services/backend` layout

## Findings

### 1) Repo existence (Team-Deepiri org)

The six target services are present in the monorepo under `platform-services/backend`, but **do not currently exist as standalone Team-Deepiri GitHub repos**:

- `deepiri-challenge-service` (missing as standalone repo)
- `deepiri-engagement-service` (missing as standalone repo)
- `deepiri-notification-service` (missing as standalone repo)
- `deepiri-platform-analytics-service` (missing as standalone repo)
- `deepiri-realtime-gateway` (missing as standalone repo)
- `deepiri-task-orchestrator` (missing as standalone repo)

### 2) Runtime wiring is already active

These services are actively referenced by platform runtime configuration:

- `docker-compose.dev.yml`
- `skaffold/skaffold.yaml`
- team skaffold overlays (`skaffold-*-team.yaml`)
- API gateway service routing in `platform-services/backend/deepiri-api-gateway/src/server.ts`

### 3) Realtime gateway is used (do not remove)

`deepiri-realtime-gateway` is currently used by API gateway via `REALTIME_GATEWAY_URL` and Socket.IO proxying logic.

This service should be treated as active production plumbing, not dead code.

## Repurpose + Rename Strategy

## Goal

Externalize the six services into dedicated repos without breaking current platform behavior, then reconnect cleanly as submodules.

## Phase 0 - Contract freeze

For each service, capture and freeze:

- health endpoint behavior
- route surface
- event in/out contracts
- env vars and ports
- dependencies on Redis/Postgres/Socket.IO/shared-utils

No behavior changes in this phase.

## Phase 1 - Create and seed repos

Create six **repurposed capability repos** and seed them from existing code:

- `deepiri-challenge-service` -> `deepiri-adaptive-experience-engine`
- `deepiri-engagement-service` -> `deepiri-incentive-engine`
- `deepiri-notification-service` -> `deepiri-communications-hub`
- `deepiri-platform-analytics-service` -> `deepiri-decision-intelligence`
- `deepiri-realtime-gateway` -> `deepiri-realtime-gateway` (name kept, scope expanded)
- `deepiri-task-orchestrator` -> `deepiri-workflow-orchestrator`

Seed each renamed repo from its current monorepo directory first (lift-and-shift baseline), then refactor internally.

## Phase 2 - Shared dependency hardening

Current services use local shared utils path references (`file:../../shared/deepiri-shared-utils`).

After split, replace local path dependency with one of:

- published npm package (preferred for stable DX), or
- git dependency pinning (acceptable interim)

Do this before final CI rollout.

## Phase 3 - Platform reconnection

Reconnect the six repos to `deepiri-platform` as submodules under current backend paths.

Keep service names and hostnames stable to avoid compose/skaffold and gateway breakage.

## Phase 4 - Verification gates

Run service-by-service checks:

- container build
- health route
- API gateway proxy path
- event flow smoke tests
- websocket proxy validation for realtime gateway

## Canonical naming and scope guardrails

To avoid drift across docs, repos, CI, and overlays, the notification repurpose uses one canonical target name only:

- Canonical name: `deepiri-communications-hub`
- Deprecated alias (do not use for new artifacts): `deepiri-communications-service`

All future references in this plan, repo creation requests, submodule paths, and deployment manifests must use `deepiri-communications-hub`.

## Release, versioning, and deprecation policy

- Base branch policy:
  - default branch for each extracted repo is `main`
  - protected branch required before production cutover
- Initial versioning:
  - each new repo starts at `v0.1.0` after lift-and-shift baseline is tagged
  - first post-baseline compatible release increments minor (`v0.2.0`)
- Breaking changes:
  - SemVer major bump required for any contract break
  - minimum one release deprecation window for route/event removals
  - API gateway contract compatibility matrix must be updated with each major

## Task orchestrator direction (FastAPI vs Django)

Decision recommendation: **FastAPI-first** for orchestration core.

Rationale:

- async and event-driven orchestration fit
- easier incremental migration from current API-centric orchestrator surface
- lower framework overhead than Django for worker/orchestration tasks

Django is still valid if full built-in admin/data modeling is a primary requirement, but default path should be FastAPI.

### Migration shape for task orchestrator

1. Keep current TypeScript orchestrator in new standalone repo (stability baseline)
2. Add FastAPI orchestrator module side-by-side
3. Shift selected endpoints/jobs incrementally behind unchanged gateway contract
4. Decommission TS orchestration slices only after parity + load checks

## Phase exit criteria and rollback playbook

Each phase is complete only when all exit criteria pass. Every phase must also define and test rollback.

### Phase 0 exit criteria (contract freeze)

- service contract pack exists for each service:
  - `contracts/routes.md`
  - `contracts/events.md`
  - `contracts/env.md`
  - `contracts/health.md`
- architecture owner + service owner sign-off recorded
- snapshot test fixtures captured for health and key routes

Rollback:

- no code rollback required (documentation-only phase)
- if gaps are found, reopen freeze checklist and block Phase 1 start

### Phase 1 exit criteria (repo creation and seed)

- 6 repos created in Team-Deepiri with canonical names
- lift-and-shift baseline imported with unchanged runtime behavior
- each repo has passing baseline CI (`build`, `unit`, `container boot`, `health`)
- baseline tag pushed (`v0.1.0`) for each repo

Rollback:

- archive failed new repo attempt and recreate from monorepo snapshot
- reset submodule prep branch to pre-extraction commit references

### Phase 2 exit criteria (shared dependency hardening)

- all `file:../../shared/deepiri-shared-utils` references removed
- dependency strategy selected and documented:
  - preferred: published npm package
  - interim: git dependency pinning with immutable refs
- lockfiles updated and reproducible install verified in CI

Rollback:

- temporarily pin last known-good shared-utils ref/package version
- block Phase 3 until deterministic install is restored

### Phase 3 exit criteria (platform reconnection)

- all six repos connected as submodules under target backend layout
- compose/skaffold overlays updated with stable hostnames and env
- gateway routing validated against unchanged contracts

Rollback:

- revert submodule pointers to previous known-good SHAs
- redeploy previous image tags from release registry
- toggle gateway route config back to previous endpoints if needed

### Phase 4 exit criteria (verification and cutover)

- service-by-service verification suite passes in CI and pre-prod
- realtime websocket proxy smoke tests pass under reconnect scenarios
- event flow smoke tests confirm end-to-end contract integrity
- on-call runbook updated for cutover/revert operations

Rollback:

- execute staged rollback order:
  1. gateway route toggle rollback
  2. submodule SHA rollback
  3. image tag rollback
  4. re-run post-rollback smoke suite

## Rename Map Backed By Current Routes

- `deepiri-challenge-service` -> `deepiri-adaptive-experience-engine`
  - Current behavior: `/generate` challenge endpoint + health.
- `deepiri-engagement-service` -> `deepiri-incentive-engine`
  - Current behavior: currency, badges, leaderboard, momentum, streaks, boosts, odysseys, rewards.
- `deepiri-notification-service` -> `deepiri-communications-hub`
  - Current behavior: push send/send-multiple, VAPID key, subscription lifecycle, websocket status.
- `deepiri-platform-analytics-service` -> `deepiri-decision-intelligence`
  - Current behavior: time-series analytics, clustering, predictive forecasts/recommendations.
- `deepiri-realtime-gateway` -> `deepiri-realtime-gateway` (keep name)
  - Current behavior: Socket.IO connection/rooms + gamification emit endpoint.
- `deepiri-task-orchestrator` -> `deepiri-workflow-orchestrator`
  - Current behavior: task lifecycle + task versioning + dependency graph APIs.

## Capability Expansion For Maximum Reusability

### `deepiri-incentive-engine` (from engagement-service)

General incentive platform (not app-gamification only):

- scoring, credits, reputation, milestones, and rewards as reusable policy modules
- anti-abuse and fraud controls (rate caps, trust thresholds, anomaly flags)
- tenant/product-level incentive policy packs
- configurable ledgers and audit trails for every award or deduction
- reusable for community, marketplace, education, and contributor ecosystems

### `deepiri-communications-hub` (from notification-service)

Unified multi-channel communications platform:

- transactional and campaign messaging separation
- adapters for email, push, in-app inbox, webhooks, Slack/Discord
- templates, localization, and versioned message contracts
- preference center + policy routing (quiet hours, channel fallback, priority)
- delivery observability (queued/sent/delivered/opened/failed) and retry logic

### `deepiri-decision-intelligence` (from platform-analytics-service)

Decision layer for product and operations:

- behavioral analytics + segmentation
- anomaly detection and incident early warning signals
- forecasting and recommendation signals for downstream services
- experimentation telemetry and effect measurement
- shared feature/insight APIs consumable by every product surface

### `deepiri-adaptive-experience-engine` (from challenge-service)

Dynamic experience generation engine for multiple surfaces:

- objective/mission/prompt generation with context + user state inputs
- personalized onboarding, learning paths, contributor task streams
- adaptive difficulty, pacing, and next-best-action generation
- policy-driven generation constraints for safety and brand consistency
- reusable for human workflows and agentic workflows

## Realtime Gateway Beef-Up Scope

`deepiri-realtime-gateway` keeps its name and gets expanded from a simple Socket.IO bridge into a core realtime/event edge service:

- multi-channel event fanout (user, party, org, global channels)
- durable stream consumption with replay cursor support
- delivery guarantees with idempotency keys and ack tracking
- rate limiting and auth-aware room join policies
- presence/session tracking with heartbeat timeouts
- backpressure and queue depth telemetry
- gateway-level observability (latency, drop rate, reconnect rate)

## Proposed `platform-services/backend` Layout

This is the target shape after extraction and reconnection:

```text
platform-services/backend/
  deepiri-api-gateway/                      # existing standalone repo/submodule
  deepiri-auth-service/                     # existing standalone repo/submodule
  deepiri-external-bridge-service/          # existing standalone repo/submodule
  deepiri-language-intelligence-service/    # existing standalone repo/submodule

  deepiri-adaptive-experience-engine/       # repurposed from challenge-service
  deepiri-incentive-engine/                 # repurposed from engagement-service
  deepiri-communications-hub/               # repurposed from notification-service
  deepiri-decision-intelligence/            # repurposed from platform-analytics-service
  deepiri-realtime-gateway/                 # keep name, beefed up scope
  deepiri-workflow-orchestrator/            # repurposed from task-orchestrator

  deepiri-messaging-service/                # keep as first-class service
```

## Suggested ownership and sequencing

Recommended order:

1. `deepiri-realtime-gateway` (because it is critical for websocket path stability)
2. `deepiri-workflow-orchestrator`
3. `deepiri-incentive-engine`
4. `deepiri-communications-hub`
5. `deepiri-adaptive-experience-engine`
6. `deepiri-decision-intelligence`

This order reduces blast radius by stabilizing core event/orchestration plumbing first.

## RACI and ownership model

| Workstream | Responsible | Accountable | Consulted | Informed |
| --- | --- | --- | --- | --- |
| Contract freeze artifacts | Service owner | Platform architecture owner | API gateway owner, SRE | Product/PM |
| Repo creation and baseline seed | Platform backend lead | Engineering manager | Service owner, DevEx | Product/PM |
| Shared-utils packaging migration | DevEx/package owner | Platform architecture owner | Service owners | Engineering |
| Submodule reconnection | Platform backend lead | Platform architecture owner | Infra/SRE | Engineering |
| Gateway and websocket validation | API gateway + realtime owners | Platform architecture owner | QA/SRE | Engineering |
| Cutover and rollback readiness | SRE/on-call lead | Engineering manager | Service owners, API gateway owner | Product/PM |

## Rollout waves and target timeline

| Wave | Services | Primary objective | Target duration |
| --- | --- | --- | --- |
| Wave 1 | `deepiri-realtime-gateway`, `deepiri-workflow-orchestrator` | Stabilize realtime and orchestration plumbing first | 2 weeks |
| Wave 2 | `deepiri-incentive-engine`, `deepiri-communications-hub` | Migrate cross-user engagement and comms flows | 2 weeks |
| Wave 3 | `deepiri-adaptive-experience-engine`, `deepiri-decision-intelligence` | Migrate generation and intelligence layers | 2 weeks |

Total target: 6 weeks excluding contingency. Add 1 additional week if shared-utils packaging strategy is delayed.

## CI/CD gate template (applies to each extracted service)

- `build`: TypeScript/Python compile + static checks
- `unit`: core logic and contract-unit suite
- `container`: image build and container boot
- `health`: `/health` assertion and readiness
- `gateway-proxy`: route pass-through from API gateway
- `event-smoke`: event publish/consume round-trip (where applicable)
- `websocket-smoke`: required for `deepiri-realtime-gateway` and dependent websocket flows

A service cannot advance wave or phase status until all required gates are green in CI.

## Decision deadline for shared-utils distribution

- Decision owner: Platform architecture owner
- Decision due date: before end of Phase 1 (hard gate for entering Phase 3)
- Decision options:
  - publish `deepiri-shared-utils` package (preferred)
  - use git dependency pinning with immutable SHA references (interim)
- Non-decision outcome:
  - extraction can continue in isolated branches
  - production reconnection is blocked until decision is ratified

## Risks and mitigations

- Shared-utils packaging risk:
  - Mitigation: finalize dependency distribution strategy before CI cutover.
- Env drift across skaffold overlays:
  - Mitigation: centralize env var template and validate all overlays in CI.
- Realtime regressions:
  - Mitigation: explicit websocket proxy smoke test gate on every rollout.

## Deliverables

- 6 renamed Team-Deepiri capability repos created and initialized
- `deepiri-platform` updated to track them as submodules
- compose/skaffold/gateway integration validated
- task orchestrator modernization track started (FastAPI-first)
