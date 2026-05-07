# Sugar Glider Mark v3 - Task 04 Adaptive Publish Candidate

Updated: 2026-04-24 (UTC)

## Objective

Add a guarded adaptive publish candidate that preserves Mark v3 behavior by default and only changes routing when explicitly enabled.

## Candidate Behavior

The new candidate keeps the publish pipeline available, but routes low-pressure publishes through the direct Redis publish path when both active publish pressure and current queue depth are below the configured minimum batch threshold.

Enabled configuration:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=true`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=true`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`

Default behavior remains unchanged:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=false`
- `SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2`

## Implementation

Changed:

- `platform-services/shared/deepiri-sugar-glider/internal/config/config.go`
- `platform-services/shared/deepiri-sugar-glider/internal/service/service.go`
- `platform-services/shared/deepiri-sugar-glider/internal/config/config_test.go`
- `platform-services/shared/deepiri-sugar-glider/internal/service/publish_fallback_test.go`
- `docker-compose.rtg-sugar-glider.local.yml`

Runtime rule:

- If the publish pipeline is disabled, use direct publish as Mark v3 does.
- If the pipeline is enabled and adaptive mode is disabled, use the existing pipeline behavior.
- If adaptive mode is enabled and both `active_publish_calls < SIDECAR_PUBLISH_PIPELINE_MIN_BATCH` and `queue_depth + 1 < SIDECAR_PUBLISH_PIPELINE_MIN_BATCH`, use direct publish and increment `publish_pipeline_adaptive_direct`.
- Otherwise, use the publish pipeline and keep existing fallback/error handling.

## Surfaced Controls

New config fields in `/v1/config`:

- `publish_pipeline_adaptive_enabled`
- `publish_pipeline_min_batch`

New metric:

- `synapse_sidecar_publish_pipeline_adaptive_direct_total`

## Expected Probe

Task 05 should run the targeted heavy-path probe with:

```bash
SIDECAR_PUBLISH_PIPELINE_ENABLED=true \
SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=true \
SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2 \
make rtg-up
```

Then:

```bash
node scripts/dev/sugarglider/e2e_gateway_probe.js --out-dir benchmarks/end-to-end/<run-id>-adaptive-publish-heavy-probe
```

Decision target:

- Must beat the Task 02 Mark v3 control on `32768B @ c=1` or stay effectively neutral.
- Must not regress `32768B @ c=10` materially.
- Must keep `lost_events=0`, `failed_ops=0`, and `error_rate_pct=0`.

## Outcome

Task 04 completed. Proceed to Task 05: run adaptive candidate probes against the same targeted heavy-path matrix.
