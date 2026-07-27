-- Cyrex migration 001: extensions, migration ledger, and producer metadata.
-- All schema prerequisites live here so SQL can be applied without runner
-- side effects beyond the ledger safety-net bootstrap.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

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
