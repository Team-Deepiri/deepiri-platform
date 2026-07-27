-- Cyrex migration 070: anticipation and reckoning read models.
-- document_id is UUID to match cyrex.documents (joinable / FK-ready).

CREATE TABLE IF NOT EXISTS cyrex.reckoning_corpus_stats (
    field_name TEXT PRIMARY KEY,
    doc_count INTEGER NOT NULL DEFAULT 0,
    mean NUMERIC,
    std NUMERIC,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.reckoning_field_priors (
    field_name TEXT PRIMARY KEY,
    predicted_range_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_prior_update TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.reckoning_records (
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    record_json JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'no_prior',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, field_name)
);

CREATE TABLE IF NOT EXISTS cyrex.reckoning_actuals (
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    actual_value JSONB NOT NULL,
    confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, field_name)
);

CREATE TABLE IF NOT EXISTS cyrex.reckoning_anomalies (
    document_id UUID NOT NULL REFERENCES cyrex.documents(document_id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    sigma_delta NUMERIC,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, field_name)
);
