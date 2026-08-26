-- Cyrex migration 140: Elkedel episodic visual memory (shared with elkedel-runtime).

CREATE SCHEMA IF NOT EXISTS cyrex;

CREATE TABLE IF NOT EXISTS cyrex.elkedel_traces (
    trace_id TEXT PRIMARY KEY,
    centroid BYTEA NOT NULL,
    strength DOUBLE PRECISION NOT NULL DEFAULT 0,
    n_observations INTEGER NOT NULL DEFAULT 0,
    first_seen_ms BIGINT NOT NULL,
    last_seen_ms BIGINT NOT NULL,
    last_updated_ms BIGINT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    label TEXT NOT NULL DEFAULT 'object',
    spatial JSONB NOT NULL DEFAULT '{}'::jsonb,
    history JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS cyrex.elkedel_observations (
    obs_id TEXT PRIMARY KEY,
    trace_id TEXT REFERENCES cyrex.elkedel_traces(trace_id) ON DELETE SET NULL,
    ts_ms BIGINT NOT NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 1,
    label TEXT NOT NULL DEFAULT 'object',
    spatial JSONB NOT NULL DEFAULT '{}'::jsonb,
    source TEXT NOT NULL DEFAULT 'perception'
);

CREATE INDEX IF NOT EXISTS idx_elkedel_obs_trace
    ON cyrex.elkedel_observations (trace_id);

CREATE INDEX IF NOT EXISTS idx_elkedel_obs_ts
    ON cyrex.elkedel_observations (ts_ms DESC);

CREATE INDEX IF NOT EXISTS idx_elkedel_traces_active
    ON cyrex.elkedel_traces (active) WHERE active = TRUE;

-- Live-scene document for VisualObservation artifacts (requires migration 010 documents).
-- Seeded at runtime by Cyrex ElkedelEyesSync when cyrex.documents exists.
