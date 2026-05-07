# Sugar Glider Mark v4 - Task 24 Queue/Backpressure Snapshots

Updated: 2026-04-28 (UTC)

## Objective

Add and run queue-depth/backpressure telemetry snapshots so heavy probes include stage-pressure evidence, not only latency/throughput outputs.

## Implementation

Added script:

- `scripts/dev/sugarglider/capture_queue_backpressure_snapshots.js`

The sampler captures periodic snapshots from:

- `GET /v1/config` (Sugar Glider metrics and queue depth)
- `GET /health` (RTG summary)
- `GET /v1/streaming/profile` (RTG bucket event counters)

It writes:

- `queue_backpressure_snapshots.json`
- `queue_backpressure_snapshots.csv`
- `queue_backpressure_summary.md`

## Executions

1. Baseline live smoke (no heavy load overlap):
   - `benchmarks/end-to-end/20260429T004959Z-task24-backpressure-snapshots`
2. Emit-path A/B window (partial heavy overlap):
   - `benchmarks/end-to-end/20260429T012022Z-task24-emit-ab-b-snapshots`
3. Sidecar ACK-tuned window (full heavy overlap):
   - `benchmarks/end-to-end/20260429T012345Z-task24-sidecar-ack-ab-b-snapshots`

## Key Readout (Full-Overlap Snapshot Window)

From `20260429T012345Z-task24-sidecar-ack-ab-b-snapshots/queue_backpressure_summary.md`:

- samples: `234` (all successful)
- `publish_pipeline_queue_depth` min/avg/max: `0 / 0 / 0`
- `dispatcher_ack_queue_depth_peak` min/avg/max: `0 / 7.95 / 13`
- counter deltas:
  - `dispatcher_ack_flush_calls`: `+4832`
  - `dispatcher_ack_exec_duration_ms_total`: `+3148`
  - `ack_rpc_requests`: `+5603`
  - `acked_entries`: `+19200`
  - `rtg_profile_total_events`: `+19200`
  - `rtg_profile_32768_c10_events`: `+9600`
  - `rtg_profile_32768_c50_events`: `+9600`

## Interpretation

- Under heavy load, publish pipeline depth stayed flat while ACK queue pressure accumulated on the dispatcher side.
- Snapshot deltas align with benchmark event volumes and confirm the sampler is capturing meaningful under-load stage telemetry.

## Outcome

Task 24 completed. Queue/backpressure snapshots are now reproducible and integrated into heavy-lane probe workflows.
