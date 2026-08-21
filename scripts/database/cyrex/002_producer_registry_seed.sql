-- Cyrex migration 002: register the Week 2 data producers.

INSERT INTO cyrex.producer_registry (producer_id, allowed_sinks, schema_version)
VALUES
    (
        'document_ingest',
        '["cyrex.documents", "cyrex.document_versions", "cyrex.document_uploads", "cyrex.document_blobs", "cyrex.document_dedup_index"]'::jsonb,
        'v1'
    ),
    (
        'parse_stage',
        '["cyrex.document_sections", "cyrex.document_chunks"]'::jsonb,
        'v1'
    ),
    (
        'artifact_store',
        '["cyrex.artifacts", "cyrex.artifact_refs", "cyrex.artifact_fields", "cyrex.citations", "cyrex.citation_locators"]'::jsonb,
        'v1'
    ),
    (
        'orchestrator',
        '["cyrex.pipeline_runs", "cyrex.pipeline_run_stages", "cyrex.pipeline_checkpoints", "cyrex.pipeline_run_events"]'::jsonb,
        'v1'
    ),
    (
        'reckoning_updater',
        '["cyrex.reckoning_corpus_stats", "cyrex.reckoning_field_priors", "cyrex.reckoning_anomalies"]'::jsonb,
        'v1'
    ),
    (
        'pressure_projector',
        '["cyrex.pressure_events", "cyrex.pressure_cells", "cyrex.pressure_cell_metrics", "cyrex.pressure_cell_artifacts"]'::jsonb,
        'v1'
    ),
    (
        'correction_writer',
        '["cyrex.learning_artifacts", "cyrex.corrections", "cyrex.correction_citations", "cyrex.correction_batches"]'::jsonb,
        'v1'
    ),
    (
        'training_emitter',
        '["cyrex.helox_training_samples", "cyrex.helox_sample_lineage", "cyrex.helox_export_batches", "cyrex.stream_mirror_offsets", "cyrex.dead_letter_records"]'::jsonb,
        'v1'
    )
ON CONFLICT (producer_id) DO NOTHING;
