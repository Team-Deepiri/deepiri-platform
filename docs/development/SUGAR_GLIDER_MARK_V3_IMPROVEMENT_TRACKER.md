# Sugar Glider Mark v3 Improvement Tracker

Updated: 2026-04-25 (UTC)

## Purpose

Track the post-Mark-v3 improvement loop. Mark v3 remains the control baseline while targeted probes test whether a candidate can improve the `32768B` low-concurrency cells that blocked the last final-push candidate.

## Task Status

- [x] Task 01: Add targeted heavy-path probe runner
- [x] Task 02: Run Mark v3 control probes
- [x] Task 03: Run current pipeline candidate probes
- [x] Task 04: Add adaptive publish candidate
- [x] Task 05: Run adaptive candidate probes
- [x] Task 06: Run final freeze-safe control validation
- [x] Task 07: Package comparison and final decision

## Task 01 - Targeted Heavy-Path Probe Runner (Completed)

Added:

- `scripts/dev/sugarglider/e2e_gateway_probe.js`

Default probe matrix:

- payload: `32768`
- concurrency: `1,10`
- warmup ops: `500`
- measure ops: `5000`
- repetitions: `5`

The runner uses the existing official benchmark engine through a temporary runtime copy with a patched matrix. This keeps `scripts/dev/sugarglider/e2e_gateway_benchmark.js` locked for official full-matrix benchmark runs.

Usage:

```bash
node scripts/dev/sugarglider/e2e_gateway_probe.js
node scripts/dev/sugarglider/e2e_gateway_probe.js --include-c50
node scripts/dev/sugarglider/e2e_gateway_probe.js --concurrency-levels 1,10 --repetitions 7
node scripts/dev/sugarglider/e2e_gateway_probe.js --dry-run
```

## Current Standing

No pipeline-enabled candidate has cleared the heavy-path promotion gate against the Mark v3 control on this machine. The optimization loop is closed for now with Mark v3 frozen as production fallback.

## Production Freeze (Completed)

Mark v3 is now frozen as fallback-safe baseline while optimization continues.

Reference:

- `docs/development/SUGAR_GLIDER_MARK_V3_PRODUCTION_FREEZE.md`

## Task 02 - Mark v3 Control Probes (Completed)

Run:

- `benchmarks/end-to-end/20260425T034824Z-mark-v3-control-heavy-probe`

Configuration:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- payload: `32768`
- concurrency: `1,10`
- repetitions: `5`

Results vs 2026-04-12 baseline:

- `32768B @ c=1`: `295.4990 ops/s`, `1.4386x`, p95 `0.8238x`, reliability clean
- `32768B @ c=10`: `710.5128 ops/s`, `2.1204x`, p95 `0.5600x`, reliability clean

Task detail:

- `docs/development/SUGAR_GLIDER_MARK_V3_TASK02_CONTROL_PROBE.md`

## Task 03 - Current Pipeline Candidate Probes (Completed)

Run:

- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe`

Configuration:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=true`
- payload: `32768`
- concurrency: `1,10`
- repetitions: `5`

Results vs Task 02 control:

- `32768B @ c=1`: `277.9572 ops/s`, `0.9406x` vs control, p95 `1.0933x` vs control, reliability clean
- `32768B @ c=10`: `694.6417 ops/s`, `0.9777x` vs control, p95 `1.0064x` vs control, reliability clean

Decision:

- Do not promote the current pipeline-enabled candidate. It stays reliable but loses to the same-machine Mark v3 control on both targeted cells.

Task detail:

- `docs/development/SUGAR_GLIDER_MARK_V3_TASK03_PIPELINE_PROBE.md`

## Task 04 - Adaptive Publish Candidate (Completed)

Added a gated adaptive publish candidate.

Default behavior remains unchanged:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`

Candidate behavior:

- Enable pipeline with `SIDECAR_PUBLISH_PIPELINE_ENABLED=true`.
- Enable adaptive routing with `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=true`.
- Route low-pressure publishes directly when both active publish pressure and queue depth are below `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH`.
- Keep the existing pipeline and fallback behavior once active publish pressure or queue pressure reaches the threshold.

New surfaced fields:

- `/v1/config`: `publish_pipeline_adaptive_enabled`
- `/v1/config`: `publish_pipeline_min_batch`
- `/metrics`: `synapse_sidecar_publish_pipeline_adaptive_direct_total`

Task detail:

- `docs/development/SUGAR_GLIDER_MARK_V3_TASK04_ADAPTIVE_PUBLISH.md`

## Task 05 - Adaptive Candidate Probes (Completed)

Run:

- `benchmarks/end-to-end/20260425T042907Z-adaptive-publish-heavy-probe`

Configuration:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=true`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=true`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`
- payload: `32768`
- concurrency: `1,10`
- repetitions: `5`

Results vs Task 02 control:

- `32768B @ c=1`: `274.5694 ops/s`, `0.9292x` vs control, p95 `1.0963x` vs control, reliability clean
- `32768B @ c=10`: `710.3862 ops/s`, `0.9998x` vs control, p95 `0.9330x` vs control, reliability clean

Runtime routing:

- `publish_pipeline_adaptive_direct=36539`
- `publish_pipeline_enqueued=18461`
- `publish_pipeline_fallback_direct=0`
- `publish_pipeline_errors=0`

Decision:

- Do not promote the current adaptive candidate. It matches Mark v3 at `c=10`, but still regresses the `32768B @ c=1` control cell.

Task detail:

- `docs/development/SUGAR_GLIDER_MARK_V3_TASK05_ADAPTIVE_PROBE.md`

## Task 06 - Final Freeze-Safe Control Validation (Completed)

Run:

- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe`

Configuration:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=false`
- payload: `32768`
- concurrency: `1,10`
- repetitions: `5`

Results vs original Task 02 control (`20260425T034824Z-mark-v3-control-heavy-probe`):

- `32768B @ c=1`: `304.5748 ops/s`, `1.0307x`, p95 `0.8955x`, reliability clean
- `32768B @ c=10`: `754.2041 ops/s`, `1.0615x`, p95 `0.8865x`, reliability clean

Task detail:

- `docs/development/SUGAR_GLIDER_MARK_V3_FREEZE_AND_OPTIMIZATION_SUMMARY.md`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/report.md`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_original_control.md`

## Task 07 - Comparison Package and Final Decision (Completed)

Packaged artifacts:

- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_original_control.csv`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_original_control.md`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_20260412.csv`
- `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_20260412.md`

Decision:

- Keep Mark v3 freeze profile as production default.
- Keep pipeline-enabled/adaptive behavior gated and disabled by default.
