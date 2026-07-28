# PrismPipe Organic Production Implementation Plan

> Executed 2026-07-27. Checkbox status reflects completion.

**Goal:** Make Organic Pipe claims real, measure them, regression-gate before wiring.

## Tasks

- [x] 1.1 Fix ComputationGraph output restore + tests
- [x] 1.2 Finish Swarm worker execution + tests
- [x] 1.3 Wire Mutation/Watcher/EventBus into OrganismExecutor
- [x] 1.4 Redis + Postgres storage backends + persistence round-trip
- [x] 1.5 Organism HTTP API, route order, `/metrics`
- [x] 1.6 TimeSplitter cancel losers + budgets
- [x] 1.7 Dockerfile COPY src + `organic_api` canonical surface
- [x] 2.x Bench harness, scenarios, baselines, `run_bench_gate.sh`
- [x] 3.x Compose deps/healthcheck, integration/regression suites, CI, Go/No-Go doc

## Verify

```bash
cd platform-services/shared/deepiri-prismpipe
poetry run pytest tests/ -v
./scripts/bench/run_bench_gate.sh
```
