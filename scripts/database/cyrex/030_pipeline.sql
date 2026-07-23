-- Cyrex migration 030: pipeline execution trace and resume state.

CREATE TABLE IF NOT EXISTS cyrex.pipeline_runs (
    run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'running',
    mode TEXT NOT NULL DEFAULT 'production',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_run_stages (
    run_id UUID NOT NULL,
    stage_name TEXT NOT NULL,
    status TEXT NOT NULL,
    duration_ms INTEGER,
    producer TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    PRIMARY KEY (run_id, stage_name)
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_stage_inputs (
    run_id UUID NOT NULL,
    stage_name TEXT NOT NULL,
    input_hash TEXT,
    input_ref TEXT,
    PRIMARY KEY (run_id, stage_name, input_ref)
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_stage_outputs (
    run_id UUID NOT NULL,
    stage_name TEXT NOT NULL,
    artifact_id UUID,
    output_type TEXT,
    PRIMARY KEY (run_id, stage_name, artifact_id)
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_errors (
    error_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID NOT NULL,
    stage_name TEXT NOT NULL,
    code TEXT,
    message TEXT NOT NULL,
    stack TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_checkpoints (
    run_id UUID PRIMARY KEY,
    checkpoint_json JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_run_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
