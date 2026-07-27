-- Cyrex migration 080: pressure events and document read models.
-- document_id / artifact_id are UUID to match documents/artifacts.
-- section_id stays TEXT: pressure grid keys may be logical section names
-- (e.g. financial_terms) before or beside parse-stage UUID sections.

CREATE TABLE IF NOT EXISTS cyrex.pressure_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL,
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    section_id TEXT NOT NULL DEFAULT '',
    page INTEGER,
    artifact_id UUID,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pressure_events_document_id
    ON cyrex.pressure_events (document_id, created_at DESC);

CREATE TABLE IF NOT EXISTS cyrex.pressure_cells (
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    section_id TEXT NOT NULL DEFAULT '',
    page INTEGER NOT NULL DEFAULT -1,
    score NUMERIC NOT NULL DEFAULT 0,
    is_fault_zone BOOLEAN NOT NULL DEFAULT FALSE,
    cell_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, section_id, page)
);

CREATE TABLE IF NOT EXISTS cyrex.pressure_cell_metrics (
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    section_id TEXT NOT NULL DEFAULT '',
    page INTEGER NOT NULL DEFAULT -1,
    discrepancy_count INTEGER NOT NULL DEFAULT 0,
    reflect_failures INTEGER NOT NULL DEFAULT 0,
    low_confidence_count INTEGER NOT NULL DEFAULT 0,
    duel_disagreements INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, section_id, page)
);

-- artifact_id is UUID for joinability with cyrex.artifacts, but no FK:
-- pressure projection may record artifact refs slightly ahead of artifact rows.
CREATE TABLE IF NOT EXISTS cyrex.pressure_cell_artifacts (
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    section_id TEXT NOT NULL DEFAULT '',
    page INTEGER NOT NULL DEFAULT -1,
    artifact_id UUID NOT NULL,
    PRIMARY KEY (document_id, section_id, page, artifact_id)
);

CREATE TABLE IF NOT EXISTS cyrex.fault_zone_history (
    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    section_id TEXT NOT NULL DEFAULT '',
    page INTEGER,
    is_fault_zone BOOLEAN NOT NULL,
    score NUMERIC,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fault_zone_history_document_id
    ON cyrex.fault_zone_history (document_id, created_at DESC);
