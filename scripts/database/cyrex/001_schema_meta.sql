-- Cyrex migration 001: migration and producer metadata.
-- The runner creates schema_migrations before applying this file so that
-- existing databases initialized by postgres-init-cyrex.sql are supported.

CREATE SCHEMA IF NOT EXISTS cyrex;

CREATE TABLE IF NOT EXISTS cyrex.schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    checksum TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.producer_registry (
    producer_id TEXT PRIMARY KEY,
    allowed_sinks JSONB NOT NULL DEFAULT '[]'::jsonb,
    schema_version TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
