-- ===========================
-- DEEPIRI CYREX POSTGRESQL SETUP
-- ===========================
-- Runtime ops baseline only (agents / workflows / memories / events).
-- AGI artifact-plane tables are owned by numbered migrations under
-- scripts/database/cyrex/ and applied by run-cyrex-migrations.py.
-- Do not duplicate AGI DDL here.

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Cyrex schema
CREATE SCHEMA IF NOT EXISTS cyrex;

-- Set search path
SET search_path TO cyrex;

-- Agents
CREATE TABLE IF NOT EXISTS cyrex.agents (
    agent_id VARCHAR(255) PRIMARY KEY,
    role VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    capabilities JSONB,
    tools JSONB,
    model_config JSONB,
    temperature FLOAT DEFAULT 0.7,
    max_tokens INTEGER DEFAULT 2000,
    system_prompt TEXT,
    guardrails JSONB,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_agents_role ON cyrex.agents(role);
CREATE INDEX IF NOT EXISTS idx_agents_name ON cyrex.agents(name);

-- Workflows
CREATE TABLE IF NOT EXISTS cyrex.workflows (
    workflow_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    description TEXT,
    workflow_type VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending',
    current_step VARCHAR(255),
    total_steps INTEGER DEFAULT 0,
    completed_steps INTEGER DEFAULT 0,
    state_data JSONB DEFAULT '{}'::jsonb,
    step_results JSONB DEFAULT '{}'::jsonb,
    assigned_agents JSONB DEFAULT '[]'::jsonb,
    checkpoints JSONB DEFAULT '[]'::jsonb,
    error TEXT,
    error_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    deadline TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_workflows_status ON cyrex.workflows(status);
CREATE INDEX IF NOT EXISTS idx_workflows_type ON cyrex.workflows(workflow_type);
CREATE INDEX IF NOT EXISTS idx_workflows_created ON cyrex.workflows(created_at);
CREATE INDEX IF NOT EXISTS idx_workflows_updated ON cyrex.workflows(updated_at);

-- Memories
CREATE TABLE IF NOT EXISTS cyrex.memories (
    memory_id VARCHAR(255) PRIMARY KEY,
    session_id VARCHAR(255),
    user_id VARCHAR(255),
    memory_type VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB,
    importance FLOAT DEFAULT 0.5,
    access_count INTEGER DEFAULT 0,
    last_accessed TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_memories_session_id ON cyrex.memories(session_id);
CREATE INDEX IF NOT EXISTS idx_memories_user_id ON cyrex.memories(user_id);
CREATE INDEX IF NOT EXISTS idx_memories_type ON cyrex.memories(memory_type);
CREATE INDEX IF NOT EXISTS idx_memories_expires_at ON cyrex.memories(expires_at);

-- Events
CREATE TABLE IF NOT EXISTS cyrex.events (
    event_id VARCHAR(255) PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id VARCHAR(255),
    workflow_id VARCHAR(255),
    agent_id VARCHAR(255),
    session_id VARCHAR(255),
    source VARCHAR(100) DEFAULT 'cyrex',
    payload JSONB DEFAULT '{}'::jsonb,
    severity VARCHAR(20) DEFAULT 'info',
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_entity ON cyrex.events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON cyrex.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_workflow ON cyrex.events(workflow_id);
CREATE INDEX IF NOT EXISTS idx_events_agent ON cyrex.events(agent_id);
CREATE INDEX IF NOT EXISTS idx_events_created ON cyrex.events(created_at);
CREATE INDEX IF NOT EXISTS idx_events_severity ON cyrex.events(severity);

-- Comments
COMMENT ON SCHEMA cyrex IS 'AI/Agent System: workflows, agents, memories, events, AGI artifacts';

-- ===========================
-- AGI artifact graph (Track A/C)
-- ===========================
CREATE TABLE IF NOT EXISTS cyrex.artifacts (
    artifact_id      TEXT PRIMARY KEY,
    document_id      TEXT    NOT NULL,
    version          INTEGER NOT NULL DEFAULT 1,
    artifact_type    TEXT    NOT NULL,
    source_doc_hash  TEXT    NOT NULL,
    confidence       DOUBLE PRECISION NOT NULL,
    payload_json     JSONB   NOT NULL DEFAULT '{}'::jsonb,
    provenance_json  JSONB   NOT NULL DEFAULT '{}'::jsonb,
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cyrex_artifacts_doc ON cyrex.artifacts(document_id);
CREATE INDEX IF NOT EXISTS idx_cyrex_artifacts_doc_type ON cyrex.artifacts(document_id, artifact_type);

CREATE TABLE IF NOT EXISTS cyrex.artifact_refs (
    from_artifact TEXT NOT NULL,
    to_artifact   TEXT NOT NULL,
    ref_type      TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (from_artifact, to_artifact, ref_type)
);
CREATE INDEX IF NOT EXISTS idx_cyrex_refs_from ON cyrex.artifact_refs(from_artifact);
CREATE INDEX IF NOT EXISTS idx_cyrex_refs_to ON cyrex.artifact_refs(to_artifact);

CREATE TABLE IF NOT EXISTS cyrex.citations (
    citation_id      TEXT PRIMARY KEY,
    artifact_id      TEXT NOT NULL REFERENCES cyrex.artifacts(artifact_id) ON DELETE CASCADE,
    document_id      TEXT NOT NULL,
    source_doc_hash  TEXT NOT NULL,
    locator_type     TEXT NOT NULL,
    char_start       INTEGER,
    char_end         INTEGER,
    page_start       INTEGER,
    page_end         INTEGER,
    element_id       TEXT,
    quote            TEXT NOT NULL,
    confidence       DOUBLE PRECISION NOT NULL,
    extraction_pass  INTEGER
);
CREATE INDEX IF NOT EXISTS idx_cyrex_citations_doc_span
    ON cyrex.citations(document_id, char_start, char_end);

CREATE TABLE IF NOT EXISTS cyrex.learning_artifacts (
    artifact_id      TEXT PRIMARY KEY,
    document_id      TEXT NOT NULL,
    field_name       TEXT NOT NULL,
    original_value   JSONB,
    corrected_value  JSONB NOT NULL,
    citation_json    JSONB NOT NULL,
    actor_id         TEXT NOT NULL,
    timestamp        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    exported         BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_cyrex_learning_exported ON cyrex.learning_artifacts(exported);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Deepiri Cyrex database initialized successfully';
END $$;
