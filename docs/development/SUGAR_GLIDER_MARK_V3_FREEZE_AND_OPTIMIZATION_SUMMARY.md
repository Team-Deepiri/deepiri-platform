# Sugar Glider Mark v3 Freeze And Optimization Summary

Updated: 2026-04-25 (UTC)

## Objective

Freeze Mark v3 as a fast rollback-safe production baseline, then run focused optimization passes to see whether we can improve throughput without reliability regressions.

## Freeze Baseline

Fallback-safe profile (pipeline path disabled):

- `STREAM_TRANSPORT=sugar-glider-grpc`
- `STREAM_SHADOW_MODE=false`
- `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`
- `SIDECAR_PUBLISH_PIPELINE_MAX_BATCH=64`
- `SIDECAR_PUBLISH_PIPELINE_FLUSH_MS=0`
- `SIDECAR_PUBLISH_PIPELINE_QUEUE_SIZE=8192`
- `SIDECAR_PUBLISH_PIPELINE_MAX_BYTES=1048576`

Operational commands:

- `make rtg-up-v3-freeze`
- `make rtg-rollout-v3-freeze`

## Optimization Pass Summary

### Candidate 1: Pipeline Enabled

- run: `20260425T035753Z-pipeline-enabled-heavy-probe`
- result: regression vs Mark v3 control on both `32768B @ c=1` and `32768B @ c=10`
- decision: no promotion

### Candidate 2: Adaptive Pipeline Routing

- run: `20260425T042907Z-adaptive-publish-heavy-probe`
- result: near parity at `32768B @ c=10`, still regressed at `32768B @ c=1`
- decision: no promotion

### Safe Code-Level Improvement Kept

- module: `internal/redisstreams/publisher.go`
- change: pre-sized `values` slice in `BuildXAddArgs` to reduce hot-path allocation churn
- reliability: clean after rollout and probes

### Rejected Attempt (Rolled Back)

- attempt: pass payload to Redis as `json.RawMessage` form instead of string conversion
- observed impact: Redis marshal failures (`can't marshal json.RawMessage`) and stalled probes
- action: fully reverted

## Final Freeze-Safe Validation

Final run:

- `20260425T054532Z-mark-v3-freeze-final-control-heavy-probe`

Key results:

- `32768B @ c=1`: `304.5748 ops/s`, p95 `4.8607 ms`
- `32768B @ c=10`: `754.2041 ops/s`, p95 `20.2525 ms`
- reliability: `error_rate=0`, `failed_ops=0`, `lost_events=0`

Comparison vs original same-machine Mark v3 control (`20260425T034824Z-mark-v3-control-heavy-probe`):

- `32768B @ c=1`: throughput `1.0307x`, p95 `0.8955x`
- `32768B @ c=10`: throughput `1.0615x`, p95 `0.8865x`

## Outcome

- Mark v3 freeze profile is validated and rollback-ready.
- Pipeline-enabled and adaptive candidates are retained as optional experiments only, not production default.
- Current best production guidance remains Mark v3 freeze profile with pipeline disabled.

## Evidence

- `docs/development/SUGAR_GLIDER_MARK_V3_PRODUCTION_FREEZE.md`
- `docs/development/SUGAR_GLIDER_MARK_V3_IMPROVEMENT_TRACKER.md`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/report.md`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_original_control.md`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_20260412.md`
