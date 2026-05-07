# Sugar Glider Mark v4 - Task 12 Fast-Path Full WebSocket Run 1

Updated: 2026-04-27 (UTC)

## Run Metadata

- Run ID:
  - `20260427T020235Z-v4-iteration3-fastpath-run1`
- Matrix:
  - payload: `1024/8192/32768`
  - concurrency: `1/10/50`
  - warmup: `500`
  - measure: `5000`
  - repetitions: `3`
- Transport:
  - `websocket`

## Runtime Profile

Restored fast-path profile (native websocket + sidecar defaults):

- Sidecar:
  - `SIDECAR_DISPATCHER_READ_COUNT=512`
  - `SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER=1024`
  - `SIDECAR_DISPATCHER_ACK_BATCH_SIZE=256`
  - `SIDECAR_DISPATCHER_ACK_FLUSH_CONCURRENCY=8`
  - `SIDECAR_DISPATCHER_ACK_FLUSH_MS=6`
  - `SIDECAR_DISPATCHER_ACK_QUEUE_SIZE=16384`
- RTG:
  - `STREAM_SUBSCRIBE_BATCH_SIZE=128`
  - `STREAM_EVENT_MAX_IN_FLIGHT=1024`
  - `STREAM_EVENT_RESUME_IN_FLIGHT=768`
  - `STREAM_ACK_BATCH_SIZE=256`
  - `STREAM_ACK_FLUSH_MS=6`
  - `STREAM_ACK_FLUSH_CONCURRENCY=8`

## Reliability

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Throughput Snapshot

- run average throughput: `1011.4769 ops/s`
- run average p95: `40.0598 ms`

## Comparison Highlights

- vs `20260412T052514Z` baseline:
  - average throughput ratio: `2.1314x`
  - p95 pass rate at `<=1.20x` baseline: `9/9`
- vs Mark v3 fixed repeat2:
  - average throughput ratio: `0.8698x`
- vs prior v4 websocket-native full:
  - average throughput ratio: `0.5930x`
- vs autoplay Task 08 run1:
  - average throughput ratio: `1.0316x`

## Heavy Path (`32768B`) Snapshot

- `c=1`: `227.9721 ops/s`, p95 `6.7296 ms`
- `c=10`: `415.9424 ops/s`, p95 `41.3184 ms`
- `c=50`: `423.3824 ops/s`, p95 `188.5295 ms`

## Artifacts

- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1/report.md`
- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1/summary.csv`
- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1/comparison_vs_20260412.csv`
- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1/comparison_vs_v3_fixed_repeat2.csv`
- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1/comparison_vs_v4_websocket_native.csv`
- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1/comparison_vs_task8_run1.csv`

## Outcome

Task 12 completed (run executed and packaged).

