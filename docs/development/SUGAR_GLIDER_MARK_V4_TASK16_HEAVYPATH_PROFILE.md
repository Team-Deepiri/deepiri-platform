# Sugar Glider Mark v4 - Task 16 Heavy-Path CPU/RAM Profile

Updated: 2026-04-27 (UTC)

## Objective

Capture resource usage during heavy-path websocket traffic to identify next optimization targets beyond knob tuning.

## Profile Run

- Run ID:
  - `20260427T021623Z-task16-heavypath-profile`
- Probe matrix:
  - payload: `32768`
  - concurrency: `10,50`
  - warmup: `200`
  - measure: `3000`
  - repetitions: `3`
- Transport:
  - `websocket`

## Reliability and Throughput

From `report.md`:

- reliability:
  - `lost_events=0`
  - `failed_ops=0`
  - `error_rate_pct=0`
- throughput:
  - `32768 c10`: `381.1949 ops/s` (p95 `44.0726 ms`)
  - `32768 c50`: `416.6839 ops/s` (p95 `201.9771 ms`)

## Resource Sampling Method

- Collected `docker stats --no-stream` every ~2 seconds while probe executed.
- Sampled containers:
  - `deepiri-realtime-gateway-rtg-local`
  - `deepiri-synapse-sugar-glider-rtg-local`
  - `deepiri-redis-rtg-local`
- Samples captured: `19`

## Peak Resource Observations

| Container | Peak CPU % | Peak Memory (MiB) |
|---|---:|---:|
| `deepiri-realtime-gateway-rtg-local` | `114.85` | `106.30` |
| `deepiri-synapse-sugar-glider-rtg-local` | `134.14` | `46.55` |
| `deepiri-redis-rtg-local` | `84.31` | `390.00` |

## Interpretation

- CPU pressure is concentrated in RTG and Sugar Glider during heavy-path runs, with both sustaining near/over one full core.
- Redis memory footprint is stable and high relative to app containers, while CPU spikes remain below RTG/Sugar Glider peaks.
- The next throughput gains are likely to come from CPU-path reductions in:
  - RTG socket delivery and event handling (`32768 c10/c50`)
  - Sugar Glider dispatch/ack hot path at high concurrency

## Artifacts

- `benchmarks/end-to-end/20260427T021623Z-task16-heavypath-profile/report.md`
- `benchmarks/end-to-end/20260427T021623Z-task16-heavypath-profile/summary.csv`
- `benchmarks/end-to-end/20260427T021623Z-task16-heavypath-profile/docker_stats.log`

## Outcome

Task 16 completed (profiling baseline captured for next optimization round).

