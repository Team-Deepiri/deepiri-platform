# Sugar Glider Mark v4 - Task 13 Fast-Path Full WebSocket Run 2

Updated: 2026-04-27 (UTC)

## Run Metadata

- Run ID:
  - `20260427T020718Z-v4-iteration3-fastpath-run2`
- Matrix:
  - payload: `1024/8192/32768`
  - concurrency: `1/10/50`
  - warmup: `500`
  - measure: `5000`
  - repetitions: `3`
- Transport:
  - `websocket`

## Runtime Profile

Same restored fast-path profile as Task 12:

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

- run average throughput: `1040.9241 ops/s`
- run average p95: `36.3369 ms`

## Comparison Highlights

- vs `20260412T052514Z` baseline:
  - average throughput ratio: `2.2073x`
  - p95 pass rate at `<=1.20x` baseline: `9/9`
- vs Mark v3 fixed repeat2:
  - average throughput ratio: `0.9073x`
- vs prior v4 websocket-native full:
  - average throughput ratio: `0.6216x`
- vs autoplay Task 09 run2:
  - average throughput ratio: `1.0476x`

## Heavy Path (`32768B`) Snapshot

- `c=1`: `235.9827 ops/s`, p95 `6.2525 ms`
- `c=10`: `417.8794 ops/s`, p95 `40.4480 ms`
- `c=50`: `440.9222 ops/s`, p95 `166.4319 ms`

## Artifacts

- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2/report.md`
- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2/summary.csv`
- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2/comparison_vs_20260412.csv`
- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2/comparison_vs_v3_fixed_repeat2.csv`
- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2/comparison_vs_v4_websocket_native.csv`
- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2/comparison_vs_task9_run2.csv`

## Outcome

Task 13 completed (run executed and packaged).

