-- Cyrex migration 120: durable Helox training bridge.

CREATE TABLE IF NOT EXISTS cyrex.helox_training_samples (
    record_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stream_type TEXT NOT NULL,
    producer TEXT NOT NULL,
    text TEXT,
    instruction TEXT,
    input_text TEXT,
    output_text TEXT,
    category TEXT,
    quality_score NUMERIC,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_helox_training_samples_stream
    ON cyrex.helox_training_samples (stream_type, created_at DESC);

CREATE TABLE IF NOT EXISTS cyrex.helox_sample_lineage (
    record_id UUID PRIMARY KEY
        REFERENCES cyrex.helox_training_samples(record_id) ON DELETE CASCADE,
    artifact_id UUID REFERENCES cyrex.artifacts(artifact_id) ON DELETE SET NULL,
    correction_id UUID REFERENCES cyrex.corrections(correction_id) ON DELETE SET NULL,
    run_id UUID REFERENCES cyrex.pipeline_runs(run_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.helox_export_batches (
    batch_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stream_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    record_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS cyrex.stream_mirror_offsets (
    stream_name TEXT PRIMARY KEY,
    offset_value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.dead_letter_records (
    dead_letter_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stream_name TEXT,
    record_id UUID REFERENCES cyrex.helox_training_samples(record_id) ON DELETE SET NULL,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.training_quality_gates (
    producer TEXT PRIMARY KEY,
    minimum_quality_score NUMERIC NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS cyrex.training_category_registry (
    producer TEXT NOT NULL,
    category TEXT NOT NULL,
    PRIMARY KEY (producer, category)
);
