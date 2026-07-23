-- Cyrex migration 080: pressure events and document read models.

CREATE TABLE IF NOT EXISTS cyrex.pressure_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL,
    document_id TEXT NOT NULL,
    section_id TEXT,
    page INTEGER,
    artifact_id TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.pressure_cells (
    document_id TEXT NOT NULL,
    section_id TEXT,
    page INTEGER,
    score NUMERIC NOT NULL DEFAULT 0,
    is_fault_zone BOOLEAN NOT NULL DEFAULT FALSE,
    cell_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, section_id, page)
);

CREATE TABLE IF NOT EXISTS cyrex.pressure_cell_metrics (
    document_id TEXT NOT NULL,
    section_id TEXT,
    page INTEGER,
    discrepancy_count INTEGER NOT NULL DEFAULT 0,
    reflect_failures INTEGER NOT NULL DEFAULT 0,
    low_confidence_count INTEGER NOT NULL DEFAULT 0,
    duel_disagreements INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, section_id, page)
);

CREATE TABLE IF NOT EXISTS cyrex.pressure_cell_artifacts (
    document_id TEXT NOT NULL,
    section_id TEXT,
    page INTEGER,
    artifact_id TEXT NOT NULL,
    PRIMARY KEY (document_id, section_id, page, artifact_id)
);

CREATE TABLE IF NOT EXISTS cyrex.fault_zone_history (
    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id TEXT NOT NULL,
    section_id TEXT,
    page INTEGER,
    is_fault_zone BOOLEAN NOT NULL,
    score NUMERIC,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
