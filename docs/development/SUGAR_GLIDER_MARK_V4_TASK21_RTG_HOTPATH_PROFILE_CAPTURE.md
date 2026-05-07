# Sugar Glider Mark v4 - Task 21 RTG Hot-Path Profile Capture

Updated: 2026-04-27 (UTC)

## Objective

Run a heavy-path websocket probe with RTG hot-path instrumentation enabled and capture parse/dispatch/emit timing evidence for target buckets `32768:10` and `32768:50`.

## Runtime Setup

RTG profile env (enabled during recreate):

- `STREAM_SOCKET_HOTPATH_PROFILE_ENABLED=true`
- `STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS=32768:10,32768:50`
- `STREAM_SOCKET_HOTPATH_PROFILE_SAMPLE_LIMIT=4096`

## Benchmark Run

- Run ID:
  - `20260427T034246Z-task5-rtg-hotpath-profile-run1`
- Command:
  - `node scripts/dev/sugarglider/e2e_gateway_probe.js --socket-transport websocket --payload-bytes 32768 --concurrency-levels 10,50 --warmup-ops 200 --measure-ops 3000 --repetitions 3 --out-dir benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1`

## Benchmark Outcome

From `report.md`:

- `32768 c10`:
  - throughput `370.2180 ops/s`
  - p95 `48.0343 ms`
- `32768 c50`:
  - throughput `394.4931 ops/s`
  - p95 `212.2217 ms`
- reliability:
  - `lost_events=0`
  - `failed_ops=0`
  - `error_rate_pct=0`

## RTG Hot-Path Profile Outcome

Snapshot:

- `GET /v1/streaming/profile`
- captured as:
  - `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/rtg_socket_hotpath_profile.json`

Summary highlights:

- total events tracked: `19200`
- bucket `32768:10` (`9600` events):
  - parse avg/p95: `0.0292 / 0.0550 ms`
  - dispatch avg/p95: `0.0059 / 0.0063 ms`
  - emit avg/p95: `0.5594 / 1.1281 ms`
  - emit share of profiled path: `94.10%`
- bucket `32768:50` (`9600` events):
  - parse avg/p95: `0.0268 / 0.0491 ms`
  - dispatch avg/p95: `0.0038 / 0.0051 ms`
  - emit avg/p95: `0.5200 / 1.1514 ms`
  - emit share of profiled path: `94.45%`

## Interpretation

- For tracked heavy buckets, RTG emit-stage time dominates the profiled parse+dispatch+emit path.
- Parse and dispatch are comparatively small in average contribution; emit-path reductions should be prioritized next.
- This evidence supports moving to dispatcher/ack micro-timing and downstream overlap checks in the next task.

## Artifacts

- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/report.md`
- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/summary.csv`
- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/rtg_socket_hotpath_profile.json`
- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/rtg_health_after_profile.json`
- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/rtg_socket_hotpath_profile.csv`
- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1/rtg_socket_hotpath_profile_summary.md`

## Outcome

Task 21 completed. We now have runtime-verified RTG hot-path timing evidence for heavy-path websocket traffic and a clear signal to target emit-path costs next.
