-- Cyrex migration 020: artifact graph and provenance.

CREATE TABLE IF NOT EXISTS cyrex.artifacts (
    artifact_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    version INTEGER NOT NULL,
    artifact_type TEXT NOT NULL,
    confidence NUMERIC,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    provenance_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_artifacts_document_type
    ON cyrex.artifacts (document_id, artifact_type, version DESC);

CREATE TABLE IF NOT EXISTS cyrex.artifact_refs (
    from_artifact UUID NOT NULL,
    to_artifact UUID NOT NULL,
    ref_type TEXT NOT NULL,
    weight NUMERIC,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (from_artifact, to_artifact, ref_type)
);

CREATE TABLE IF NOT EXISTS cyrex.artifact_fields (
    artifact_id UUID NOT NULL,
    field_name TEXT NOT NULL,
    value_json JSONB NOT NULL,
    confidence NUMERIC,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (artifact_id, field_name)
);

CREATE TABLE IF NOT EXISTS cyrex.citations (
    citation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artifact_id UUID NOT NULL,
    document_id UUID NOT NULL,
    quote TEXT NOT NULL,
    confidence NUMERIC,
    extraction_pass TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.citation_locators (
    citation_id UUID NOT NULL,
    locator_type TEXT NOT NULL,
    char_start INTEGER,
    char_end INTEGER,
    page_start INTEGER,
    page_end INTEGER,
    element_id TEXT,
    PRIMARY KEY (citation_id, locator_type)
);

CREATE TABLE IF NOT EXISTS cyrex.artifact_field_citations (
    artifact_id UUID NOT NULL,
    field_name TEXT NOT NULL,
    citation_id UUID NOT NULL,
    PRIMARY KEY (artifact_id, field_name, citation_id)
);

CREATE TABLE IF NOT EXISTS cyrex.artifact_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artifact_id UUID NOT NULL,
    payload_json JSONB NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.invalidation_queue (
    artifact_id UUID PRIMARY KEY,
    enqueued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed BOOLEAN NOT NULL DEFAULT FALSE,
    priority INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS cyrex.invalidation_cascade_log (
    cascade_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    root_artifact_id UUID NOT NULL,
    affected_artifact_ids_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    trigger TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.rebase_audit (
    artifact_id UUID PRIMARY KEY,
    actor_id TEXT,
    rebased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT
);

CREATE TABLE IF NOT EXISTS cyrex.artifact_tags (
    artifact_id UUID NOT NULL,
    tag TEXT NOT NULL,
    source_producer TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (artifact_id, tag)
);

CREATE TABLE IF NOT EXISTS cyrex.document_artifact_index (
    document_id UUID NOT NULL,
    artifact_type TEXT NOT NULL,
    latest_artifact_id UUID NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, artifact_type)
);
