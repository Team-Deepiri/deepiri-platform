# Sugar Glider Final Push - Task 08 Metrics/Config Surfacing

Updated: 2026-04-23 (UTC)

## Objective

Expose publish pipeline state in runtime config and metrics so rollout diagnostics are observable without code inspection.

## Config Surfacing

`/v1/config` now includes:

- `publish_pipeline_enabled`
- `publish_pipeline_max_batch`
- `publish_pipeline_flush_ms`
- `publish_pipeline_queue_size`
- `publish_pipeline_max_bytes`
- `publish_pipeline_queue_depth`

## Metrics Surfacing

`/metrics` now exposes:

- `synapse_sidecar_publish_pipeline_enqueued_total`
- `synapse_sidecar_publish_pipeline_flushed_batches_total`
- `synapse_sidecar_publish_pipeline_flushed_entries_total`
- `synapse_sidecar_publish_pipeline_fallback_direct_total`
- `synapse_sidecar_publish_pipeline_errors_total`
- `synapse_sidecar_publish_pipeline_queue_depth`

These are also included in the JSON metrics snapshot returned by `/v1/config`.

## Outcome

Task 08 completed.

