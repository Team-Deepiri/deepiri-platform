-- Cyrex migration 030: pipeline execution trace and resume state.

CREATE TABLE IF NOT EXISTS cyrex.pipeline_runs (
    run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'running',
    mode TEXT NOT NULL DEFAULT 'production',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_document_id
    ON cyrex.pipeline_runs (document_id);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_run_stages (
    run_id UUID NOT NULL REFERENCES cyrex.pipeline_runs(run_id) ON DELETE CASCADE,
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
    input_ref TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (run_id, stage_name, input_ref),
    FOREIGN KEY (run_id, stage_name)
        REFERENCES cyrex.pipeline_run_stages(run_id, stage_name) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_stage_outputs (
    run_id UUID NOT NULL,
    stage_name TEXT NOT NULL,
    artifact_id UUID NOT NULL REFERENCES cyrex.artifacts(artifact_id) ON DELETE CASCADE,
    output_type TEXT,
    PRIMARY KEY (run_id, stage_name, artifact_id),
    FOREIGN KEY (run_id, stage_name)
        REFERENCES cyrex.pipeline_run_stages(run_id, stage_name) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_errors (
    error_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID NOT NULL REFERENCES cyrex.pipeline_runs(run_id) ON DELETE CASCADE,
    stage_name TEXT NOT NULL,
    code TEXT,
    message TEXT NOT NULL,
    stack TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_checkpoints (
    run_id UUID PRIMARY KEY REFERENCES cyrex.pipeline_runs(run_id) ON DELETE CASCADE,
    checkpoint_json JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.pipeline_run_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID NOT NULL REFERENCES cyrex.pipeline_runs(run_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_run_id
    ON cyrex.pipeline_run_events (run_id);
