-- ===========================
-- DEEPIRI INTELLIGENCE POSTGRESQL SETUP
-- ===========================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Intelligence schema
CREATE SCHEMA IF NOT EXISTS intelligence;

-- Set search path (keep public so uuid-ossp/pg_trgm/btree_gin functions,
-- which install into public, remain resolvable without schema-qualifying
-- every call)
SET search_path TO intelligence, public;

-- ===========================
-- INTELLIGENCE TABLES
-- ===========================

-- Leases table (Phase 1)
CREATE TABLE IF NOT EXISTS intelligence.leases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_number VARCHAR(100) UNIQUE NOT NULL,
    tenant_name VARCHAR(255) NOT NULL,
    landlord_name VARCHAR(255),
    property_address VARCHAR(500) NOT NULL,
    property_type VARCHAR(100),
    square_footage INT,
    document_url TEXT,
    document_storage_key VARCHAR(255),
    raw_text TEXT,
    document_type VARCHAR(50) DEFAULT 'PDF',
    file_size INT,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'ERROR', 'ARCHIVED')),
    processing_status VARCHAR(50),
    processing_error TEXT,
    processed_at TIMESTAMP,
    processing_time_ms INT,
    abstracted_terms JSONB,
    financial_terms JSONB,
    key_dates JSONB,
    property_details JSONB,
    key_clauses JSONB,
    extraction_confidence FLOAT,
    validation_score FLOAT,
    user_id UUID,
    organization_id UUID,
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE INDEX idx_leases_lease_number ON intelligence.leases(lease_number);
CREATE INDEX idx_leases_tenant_name ON intelligence.leases(tenant_name);
CREATE INDEX idx_leases_status ON intelligence.leases(status);
CREATE INDEX idx_leases_user_id ON intelligence.leases(user_id);
CREATE INDEX idx_leases_organization_id ON intelligence.leases(organization_id);
CREATE INDEX idx_leases_start_date ON intelligence.leases(start_date);

-- Lease Versions table (Phase 1)
CREATE TABLE IF NOT EXISTS intelligence.lease_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_id UUID NOT NULL REFERENCES intelligence.leases(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    document_url TEXT NOT NULL,
    raw_text TEXT NOT NULL,
    abstracted_terms JSONB NOT NULL,
    changes JSONB,
    change_summary TEXT,
    change_type VARCHAR(50),
    significant_changes BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP DEFAULT NOW(),
    processing_time_ms INT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    UNIQUE(lease_id, version_number)
);

CREATE INDEX idx_lease_versions_lease_id ON intelligence.lease_versions(lease_id);
CREATE INDEX idx_lease_versions_version_number ON intelligence.lease_versions(version_number);

-- Contracts table (Phase 2)
CREATE TABLE IF NOT EXISTS intelligence.contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_number VARCHAR(100) UNIQUE NOT NULL,
    contract_name VARCHAR(255) NOT NULL,
    party_a VARCHAR(255) NOT NULL,
    party_b VARCHAR(255) NOT NULL,
    contract_type VARCHAR(100),
    jurisdiction VARCHAR(100),
    effective_date TIMESTAMP,
    expiration_date TIMESTAMP,
    document_url TEXT NOT NULL,
    document_storage_key VARCHAR(255),
    raw_text TEXT NOT NULL,
    document_type VARCHAR(50) DEFAULT 'PDF',
    file_size INT,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'ERROR', 'ARCHIVED')),
    processing_status VARCHAR(50),
    processing_error TEXT,
    processed_at TIMESTAMP,
    processing_time_ms INT,
    abstracted_terms JSONB,
    key_clauses JSONB,
    financial_terms JSONB,
    termination_terms JSONB,
    renewal_terms JSONB,
    extraction_confidence FLOAT,
    validation_score FLOAT,
    user_id UUID,
    organization_id UUID,
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE INDEX idx_contracts_contract_number ON intelligence.contracts(contract_number);
CREATE INDEX idx_contracts_party_a ON intelligence.contracts(party_a);
CREATE INDEX idx_contracts_party_b ON intelligence.contracts(party_b);
CREATE INDEX idx_contracts_status ON intelligence.contracts(status);
CREATE INDEX idx_contracts_user_id ON intelligence.contracts(user_id);
CREATE INDEX idx_contracts_organization_id ON intelligence.contracts(organization_id);
CREATE INDEX idx_contracts_effective_date ON intelligence.contracts(effective_date);

-- Contract Versions table (Phase 2)
CREATE TABLE IF NOT EXISTS intelligence.contract_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID NOT NULL REFERENCES intelligence.contracts(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    document_url TEXT NOT NULL,
    raw_text TEXT NOT NULL,
    abstracted_terms JSONB NOT NULL,
    changes JSONB,
    change_summary TEXT,
    change_type VARCHAR(50),
    significant_changes BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP DEFAULT NOW(),
    processing_time_ms INT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    UNIQUE(contract_id, version_number)
);

CREATE INDEX idx_contract_versions_contract_id ON intelligence.contract_versions(contract_id);
CREATE INDEX idx_contract_versions_version_number ON intelligence.contract_versions(version_number);

-- Clauses table (Phase 2)
CREATE TABLE IF NOT EXISTS intelligence.clauses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID NOT NULL REFERENCES intelligence.contracts(id) ON DELETE CASCADE,
    clause_number VARCHAR(50),
    clause_type VARCHAR(100) NOT NULL,
    clause_title VARCHAR(255),
    clause_text TEXT NOT NULL,
    clause_summary TEXT,
    section_number VARCHAR(50),
    page_number INT,
    version_number INT NOT NULL,
    extracted_at TIMESTAMP DEFAULT NOW(),
    previous_version_id UUID REFERENCES intelligence.clauses(id),
    changes JSONB,
    change_type VARCHAR(50),
    change_summary TEXT,
    significant_change BOOLEAN DEFAULT FALSE,
    confidence FLOAT,
    extraction_method VARCHAR(50),
    source_section VARCHAR(100),
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_clauses_contract_id_version ON intelligence.clauses(contract_id, version_number);
CREATE INDEX idx_clauses_clause_type ON intelligence.clauses(clause_type);
CREATE INDEX idx_clauses_change_type ON intelligence.clauses(change_type);
CREATE INDEX idx_clauses_previous_version_id ON intelligence.clauses(previous_version_id);

-- Obligations table (Phase 1 & 2 - shared)
CREATE TABLE IF NOT EXISTS intelligence.obligations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_id UUID REFERENCES intelligence.leases(id) ON DELETE CASCADE,
    contract_id UUID REFERENCES intelligence.contracts(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    obligation_type VARCHAR(50) NOT NULL,
    party VARCHAR(50),
    deadline TIMESTAMP,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    frequency VARCHAR(50),
    amount FLOAT,
    currency VARCHAR(10) DEFAULT 'USD',
    source_clause TEXT,
    confidence FLOAT,
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'OVERDUE', 'CANCELLED')),
    completed_at TIMESTAMP,
    owner VARCHAR(255),
    owner_email VARCHAR(255),
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_obligation_parent CHECK (lease_id IS NOT NULL OR contract_id IS NOT NULL)
);

CREATE INDEX idx_obligations_lease_id ON intelligence.obligations(lease_id);
CREATE INDEX idx_obligations_contract_id ON intelligence.obligations(contract_id);
CREATE INDEX idx_obligations_status ON intelligence.obligations(status);
CREATE INDEX idx_obligations_deadline ON intelligence.obligations(deadline);
CREATE INDEX idx_obligations_obligation_type ON intelligence.obligations(obligation_type);

-- Obligation Dependencies table (Phase 2)
CREATE TABLE IF NOT EXISTS intelligence.obligation_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_obligation_id UUID NOT NULL REFERENCES intelligence.obligations(id) ON DELETE CASCADE,
    target_obligation_id UUID NOT NULL REFERENCES intelligence.obligations(id) ON DELETE CASCADE,
    dependency_type VARCHAR(50) NOT NULL,
    description TEXT,
    confidence FLOAT,
    source_clause TEXT,
    target_clause TEXT,
    trigger_condition TEXT,
    source_contract_id UUID REFERENCES intelligence.contracts(id),
    target_contract_id UUID REFERENCES intelligence.contracts(id),
    source_lease_id UUID REFERENCES intelligence.leases(id),
    target_lease_id UUID REFERENCES intelligence.leases(id),
    strength VARCHAR(50),
    conditions JSONB,
    trigger_events TEXT[] DEFAULT '{}',
    cascade_depth INT DEFAULT 1,
    cascade_impact VARCHAR(50),
    detected_at TIMESTAMP DEFAULT NOW(),
    detected_by VARCHAR(100),
    verified BOOLEAN DEFAULT FALSE,
    verified_by UUID,
    verified_at TIMESTAMP,
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(source_obligation_id, target_obligation_id)
);

CREATE INDEX idx_obligation_dependencies_source ON intelligence.obligation_dependencies(source_obligation_id);
CREATE INDEX idx_obligation_dependencies_target ON intelligence.obligation_dependencies(target_obligation_id);
CREATE INDEX idx_obligation_dependencies_source_contract ON intelligence.obligation_dependencies(source_contract_id);
CREATE INDEX idx_obligation_dependencies_target_contract ON intelligence.obligation_dependencies(target_contract_id);
CREATE INDEX idx_obligation_dependencies_source_lease ON intelligence.obligation_dependencies(source_lease_id);
CREATE INDEX idx_obligation_dependencies_target_lease ON intelligence.obligation_dependencies(target_lease_id);
CREATE INDEX idx_obligation_dependencies_dependency_type ON intelligence.obligation_dependencies(dependency_type);
CREATE INDEX idx_obligation_dependencies_cascade_impact ON intelligence.obligation_dependencies(cascade_impact);
CREATE INDEX idx_obligation_dependencies_verified ON intelligence.obligation_dependencies(verified);

-- Comments
COMMENT ON SCHEMA intelligence IS 'Language Intelligence Platform: leases, contracts, obligations, dependencies (Phases 1-2)';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Deepiri Intelligence database initialized successfully!';
END $$;
