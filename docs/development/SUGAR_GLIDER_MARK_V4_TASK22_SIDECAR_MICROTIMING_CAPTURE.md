# Sugar Glider Mark v4 - Task 22 Sidecar Micro-Timing Capture

Updated: 2026-04-28 (UTC)

## Objective

Capture sidecar dispatcher and ACK micro-timing during a heavy websocket probe to isolate read, fan-out, and ACK flush cost distribution.

## Run

- Run ID:
  - `20260427T035403Z-task6-sidecar-microtiming-run2`
- Probe command:
  - `node scripts/dev/sugarglider/e2e_gateway_probe.js --socket-transport websocket --payload-bytes 32768 --concurrency-levels 10,50 --warmup-ops 200 --measure-ops 3000 --repetitions 3 --out-dir benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2`

## Benchmark Outcome

From `report.md`:

- `32768 c10`:
  - throughput `422.5194 ops/s`
  - p95 `41.3852 ms`
- `32768 c50`:
  - throughput `405.9560 ops/s`
  - p95 `194.9500 ms`
- reliability:
  - `lost_events=0`
  - `failed_ops=0`
  - `error_rate_pct=0`

## Sidecar Timing Delta (post - pre)

From `sidecar_dispatcher_microtiming_summary.md`:

- `dispatcher_read_samples=18114`
- `dispatcher_read_duration_ms_total=191847`
- `dispatcher_fanout_samples=17401`
- `dispatcher_fanout_duration_ms_total=59`
- `dispatcher_ack_flush_calls=5734`
- `dispatcher_ack_flush_duration_ms_total=6521`
- `dispatcher_ack_exec_samples=5734`
- `dispatcher_ack_exec_duration_ms_total=6416`
- `dispatcher_ack_queue_depth_peak=4`
- `ack_rpc_requests=6400`
- `acked_entries=19200`

Derived:

- read avg/sample: `10.5911 ms`
- fan-out avg/sample: `0.003391 ms`
- ack flush avg/call: `1.1373 ms`
- ack pipeline exec avg/sample: `1.1189 ms`
- ack exec share of flush duration: `98.39%`

## Interpretation

- Sidecar fan-out overhead is very small at this load profile.
- Dispatcher ACK flush time is dominated by Redis pipeline execution time.
- Combined with Task 21 RTG profile (emit dominates RTG hot path), this confirms the heavy-path bottleneck sits in downstream delivery and ACK pipeline cost, not basic publish correctness.

## Artifacts

- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/report.md`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/summary.csv`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/sidecar_config_pre.json`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/sidecar_config_post.json`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/sidecar_metrics_pre.prom`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/sidecar_metrics_post.prom`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/sidecar_dispatcher_microtiming_delta.csv`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/sidecar_dispatcher_microtiming_summary.md`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2/rtg_socket_hotpath_profile_post.json`

## Outcome

Task 22 completed. We now have stage-level sidecar timing evidence for heavy websocket buckets and clear prioritization for next tuning passes (RTG emit path and sidecar ACK execution path).
