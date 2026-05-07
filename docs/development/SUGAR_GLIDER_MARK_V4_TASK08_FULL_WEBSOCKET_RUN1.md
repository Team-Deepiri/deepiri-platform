# Sugar Glider Mark v4 - Task 08 Full WebSocket Benchmark Run 1

Updated: 2026-04-27 (UTC)

## Run Metadata

- Run ID:
  - `20260427T014408Z-task8-full-websocket-run1`
- Matrix:
  - payload: `1024/8192/32768`
  - concurrency: `1/10/50`
  - warmup: `500`
  - measure: `5000`
  - repetitions: `3`
- Transport:
  - `websocket`

## Candidate Runtime (Locked For This Run)

- Sidecar dispatcher profile (Task 06 winner):
  - `SIDECAR_DISPATCHER_READ_COUNT=2048`
  - `SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER=4096`
  - `SIDECAR_DISPATCHER_ACK_BATCH_SIZE=512`
  - `SIDECAR_DISPATCHER_ACK_FLUSH_CONCURRENCY=16`
  - `SIDECAR_DISPATCHER_ACK_FLUSH_MS=4`
  - `SIDECAR_DISPATCHER_ACK_QUEUE_SIZE=65536`
- RTG profile (Task 07 winner):
  - `STREAM_SUBSCRIBE_BATCH_SIZE=128`
  - `STREAM_EVENT_MAX_IN_FLIGHT=1024`
  - `STREAM_EVENT_RESUME_IN_FLIGHT=768`
  - `STREAM_ACK_BATCH_SIZE=256`
  - `STREAM_ACK_FLUSH_MS=6`
  - `STREAM_ACK_FLUSH_CONCURRENCY=8`
  - `STREAM_ACK_LOW_TRAFFIC_FLUSH_MS=1`
  - `STREAM_ACK_LOW_TRAFFIC_GAP_MS=16`
  - `STREAM_ACK_LOW_TRAFFIC_MAX_PENDING=32`

## Reliability

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Throughput Snapshot

- run average throughput: `978.2768 ops/s`
- run average p95: `40.1081 ms`

## Comparison Highlights

From generated comparison artifacts:

- vs `20260412T052514Z` baseline:
  - average throughput ratio: `2.0636x`
  - p95 pass rate at `<=1.20x` baseline: `9/9`
- vs Mark v3 fixed repeat2 (`20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`):
  - average throughput ratio: `0.8503x`
- vs prior v4 websocket native full (`20260426T225038Z-v4-websocket-native-full`):
  - average throughput ratio: `0.5781x`

## Heavy Path (`32768B`) Ratios

- `c=1`: `1.0641x` vs 20260412, `0.8701x` vs v3 fixed repeat2
- `c=10`: `1.2051x` vs 20260412, `0.6221x` vs v3 fixed repeat2
- `c=50`: `1.2007x` vs 20260412, `0.5854x` vs v3 fixed repeat2

## Artifacts

- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/report.md`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/summary.csv`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/comparison_vs_20260412.csv`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/comparison_vs_20260412.md`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/comparison_vs_v3_fixed_repeat2.csv`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/comparison_vs_v3_fixed_repeat2.md`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/comparison_vs_v4_websocket_native.csv`
- `benchmarks/end-to-end/20260427T014408Z-task8-full-websocket-run1/comparison_vs_v4_websocket_native.md`

## Outcome

Task 08 completed (run executed and packaged).

