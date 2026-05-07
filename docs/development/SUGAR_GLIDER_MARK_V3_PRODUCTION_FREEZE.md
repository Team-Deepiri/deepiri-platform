# Sugar Glider Mark v3 Production Freeze

Updated: 2026-04-25 (UTC)

## Objective

Freeze the current Mark v3 baseline as the fallback-safe production profile while additional optimization work continues.

## Frozen Baseline

Control run used as fallback reference:

- run id: `20260425T034824Z-mark-v3-control-heavy-probe`
- report: `benchmarks/end-to-end/20260425T034824Z-mark-v3-control-heavy-probe/report.md`
- commit (from run artifact): `6b699fd0e54993a6198a31f716d21e105ac241e3`

Latest freeze-safe validation run:

- run id: `20260425T054532Z-mark-v3-freeze-final-control-heavy-probe`
- report: `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/report.md`
- comparison vs original control: `benchmarks/end-to-end/20260425T054532Z-mark-v3-freeze-final-control-heavy-probe/comparison_subset_vs_original_control.md`

Target profile:

- `STREAM_TRANSPORT=sugar-glider-grpc`
- `STREAM_SHADOW_MODE=false`
- `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`
- `SIDECAR_PUBLISH_PIPELINE_MAX_BATCH=64`
- `SIDECAR_PUBLISH_PIPELINE_FLUSH_MS=0`
- `SIDECAR_PUBLISH_PIPELINE_QUEUE_SIZE=8192`
- `SIDECAR_PUBLISH_PIPELINE_MAX_BYTES=1048576`

## Operational Fallback Commands

Local fast rollback:

```bash
make rtg-up-v3-freeze
```

Local forced rollout of the freeze profile:

```bash
make rtg-rollout-v3-freeze
```

Validation checks:

```bash
curl -fsS http://127.0.0.1:8081/v1/config
curl -fsS http://127.0.0.1:8081/readyz
```

Expect:

- `publish_pipeline_enabled=false`
- `publish_pipeline_adaptive_enabled=false`

## Notes

This freeze does not block optimization work. It defines a known-good control profile that can be re-applied immediately if a candidate regresses.
