-- Cyrex migration 110: corrections and learning lineage.

CREATE TABLE IF NOT EXISTS cyrex.learning_artifacts (
    learning_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    field_name TEXT NOT NULL,
    original_value JSONB,
    corrected_value JSONB NOT NULL,
    actor_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.corrections (
    correction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artifact_id UUID NOT NULL,
    field_name TEXT NOT NULL,
    corrected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.correction_citations (
    correction_id UUID NOT NULL,
    citation_id UUID NOT NULL,
    PRIMARY KEY (correction_id, citation_id)
);

CREATE TABLE IF NOT EXISTS cyrex.correction_batches (
    batch_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id TEXT,
    correction_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.few_shot_examples (
    example_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    learning_id UUID NOT NULL,
    example_json JSONB NOT NULL,
    quality_score NUMERIC,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.learning_artifact_lineage (
    learning_id UUID NOT NULL,
    record_id UUID NOT NULL,
    PRIMARY KEY (learning_id, record_id)
);
