-- Cyrex migration 010: document ingest and parsing spine.

CREATE TABLE IF NOT EXISTS cyrex.documents (
    document_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_hash TEXT NOT NULL,
    source_url TEXT,
    mime_type TEXT,
    status TEXT NOT NULL DEFAULT 'uploaded',
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_documents_content_hash
    ON cyrex.documents (content_hash);

CREATE TABLE IF NOT EXISTS cyrex.document_versions (
    document_id UUID NOT NULL,
    version INTEGER NOT NULL,
    content_hash TEXT NOT NULL,
    supersedes_version INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (document_id, version)
);

CREATE TABLE IF NOT EXISTS cyrex.document_uploads (
    upload_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    actor_id TEXT,
    byte_size BIGINT,
    storage_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.document_blobs (
    blob_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    storage_key TEXT NOT NULL,
    checksum TEXT NOT NULL,
    byte_size BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.document_sections (
    section_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    title TEXT,
    page_start INTEGER,
    page_end INTEGER,
    char_start INTEGER,
    char_end INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cyrex.document_chunks (
    chunk_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL,
    chunk_order INTEGER NOT NULL,
    text TEXT NOT NULL,
    token_count INTEGER,
    char_start INTEGER,
    char_end INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (document_id, chunk_order)
);

CREATE TABLE IF NOT EXISTS cyrex.document_chunk_embeddings (
    chunk_id UUID NOT NULL,
    model TEXT NOT NULL,
    dims INTEGER NOT NULL,
    vector_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (chunk_id, model)
);

CREATE TABLE IF NOT EXISTS cyrex.document_dedup_index (
    content_hash TEXT PRIMARY KEY,
    document_id UUID NOT NULL,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
