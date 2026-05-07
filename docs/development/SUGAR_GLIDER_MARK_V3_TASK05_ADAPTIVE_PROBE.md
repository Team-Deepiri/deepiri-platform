# Sugar Glider Mark v3 - Task 05 Adaptive Candidate Probe

Updated: 2026-04-25 (UTC)

## Objective

Roll out the Task 04 adaptive publish candidate locally and run the same targeted heavy-path probe used for the Task 02 Mark v3 control and Task 03 pipeline candidate.

## Rollout

Rebuilt and recreated the local Sugar Glider container with:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=true`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=true`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`

Verified `/v1/config`:

- `publish_pipeline_enabled=true`
- `publish_pipeline_adaptive_enabled=true`
- `publish_pipeline_min_batch=2`
- `publish_pipeline_queue_depth=0`

## Run

- Run ID:
  - `20260425T042907Z-adaptive-publish-heavy-probe`
- Probe command:
  - `node scripts/dev/sugarglider/e2e_gateway_probe.js --out-dir benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe`
- Matrix:
  - payload: `32768`
  - concurrency: `1,10`
  - repetitions: `5`
  - warmup ops: `500`
  - measure ops: `5000`

## Results vs Task 02 Control

| Cell | Control Throughput | Adaptive Throughput | Adaptive/Control | Control p95 | Adaptive p95 | Adaptive/Control p95 | Reliability |
|---|---:|---:|---:|---:|---:|---:|---|
| `32768B @ c=1` | `295.4990 ops/s` | `274.5694 ops/s` | `0.9292x` | `5.4277 ms` | `5.9506 ms` | `1.0963x` | clean |
| `32768B @ c=10` | `710.5128 ops/s` | `710.3862 ops/s` | `0.9998x` | `22.8464 ms` | `21.3146 ms` | `0.9330x` | clean |

Reliability:

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Results vs Task 03 Pipeline Candidate

- `32768B @ c=1`: `0.9878x` throughput, p95 `1.0027x`
- `32768B @ c=10`: `1.0227x` throughput, p95 `0.9270x`

## Results vs 2026-04-12 Baseline

- `32768B @ c=1`: `1.3367x` throughput, p95 `0.9031x`
- `32768B @ c=10`: `2.1200x` throughput, p95 `0.5224x`

## Runtime Metrics

Post-run Sugar Glider metrics:

- `publish_attempts=55000`
- `publish_success=55000`
- `publish_pipeline_adaptive_direct=36539`
- `publish_pipeline_enqueued=18461`
- `publish_pipeline_flushed_entries=18461`
- `publish_pipeline_fallback_direct=0`
- `publish_pipeline_errors=0`
- `dispatcher_dropped_subscribers=0`

The generic `errors=4` counter came from dispatcher consumer-group recreation warnings immediately after `FLUSHDB`, not benchmark delivery loss.

## Decision

Do not promote this adaptive candidate to full-matrix validation yet.

The candidate is reliable and fixes the Task 03 `c=10` weakness, but it still regresses the same-machine Mark v3 control at `32768B @ c=1`. That cell is the original blocker, so the candidate needs another tuning pass before any full-matrix rerun.

## Artifacts

- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/report.md`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/summary.csv`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/comparison_subset_vs_control.csv`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/comparison_subset_vs_control.md`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/comparison_subset_vs_pipeline.csv`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/comparison_subset_vs_pipeline.md`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/comparison_subset_vs_20260412.csv`
- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe/comparison_subset_vs_20260412.md`

## Outcome

Task 05 completed. The local rollout works, but the measured result is a no-go for promotion over Mark v3.
