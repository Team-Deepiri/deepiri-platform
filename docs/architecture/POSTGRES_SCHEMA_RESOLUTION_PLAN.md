# PostgreSQL Schema Resolution & Intelligence Schema Plan

## 🎯 Goals
1. **Resolve `tasks` table conflict** - Multiple services creating same table
2. **Create `intelligence` schema** - For Language Intelligence Platform (Phases 1-2)
3. **Document Phase 1/2 table requirements** - Based on implementation plan

---

## ⚠️ Issue 1: Tasks Table Conflict

### Current State
**Three places creating `tasks` table:**
1. `scripts/postgres-init.sql` → Creates `public.tasks`
2. `task-orchestrator/prisma/schema.prisma` → Creates `tasks` (defaults to `public`)
3. `engagement-service/prisma/schema.prisma` → Creates `tasks` in `public` schema

### Problem
- Both services try to create the same table
- Risk of migration conflicts
- Unclear ownership

### Solution: Unified Tasks Table

**Approach:** Keep ONE `tasks` table in `public` schema, both services reference it.

**Implementation:**
1. **Primary Definition:** `postgres-init.sql` (already exists)
2. **Task Orchestrator:** Reference existing table (no CREATE)
3. **Engagement Service:** Reference existing table (no CREATE)

**Prisma Schema Updates:**

**For Task Orchestrator:**
```prisma
// Remove table creation, just reference
model Task {
  // ... fields ...
  @@schema("public")
  @@map("tasks")
}
```

**For Engagement Service:**
```prisma
// Already uses @@schema("public"), keep as-is
// But ensure it references the same table structure
model Task {
  // ... fields ...
  @@schema("public")
  @@map("tasks")
}
```

**Migration Strategy:**
- Ensure both Prisma schemas match `postgres-init.sql` structure
- Use Prisma's `db push` or migrations to sync
- Document that `tasks` table is shared

---

## ✅ Solution 2: Intelligence Schema for Language Intelligence Platform

### Schema Purpose
Store all Language Intelligence Platform data:
- **Phase 1:** Lease abstraction (leases, lease_versions, obligations)
- **Phase 2:** Contract intelligence (contracts, contract_versions, clauses, obligation_dependencies)

### Schema Structure

```sql
-- Create intelligence schema
CREATE SCHEMA IF NOT EXISTS intelligence;

-- ============================================
-- PHASE 1: LEASE ABSTRACTION TABLES
-- ============================================

-- Leases table
CREATE TABLE IF NOT EXISTS intelligence.leases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_number VARCHAR(100) UNIQUE NOT NULL,
    tenant_name VARCHAR(255) NOT NULL,
    landlord_name VARCHAR(255),
    property_address VARCHAR(500) NOT NULL,
    property_type VARCHAR(100), -- 'OFFICE', 'RETAIL', 'INDUSTRIAL', etc.
    square_footage INT,
    
    -- Document storage
    document_url TEXT,
    document_storage_key VARCHAR(255),
    raw_text TEXT,
    document_type VARCHAR(50) DEFAULT 'PDF',
    file_size INT,
    
    -- Dates
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    
    -- Processing status
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'ERROR', 'ARCHIVED')),
    processing_status VARCHAR(50),
    processing_error TEXT,
    processed_at TIMESTAMP,
    processing_time_ms INT,
    
    -- Abstracted data (JSONB for flexibility)
    abstracted_terms JSONB,
    financial_terms JSONB,
    key_dates JSONB,
    property_details JSONB,
    key_clauses JSONB,
    
    -- Confidence scores
    extraction_confidence FLOAT,
    validation_score FLOAT,
    
    -- User/tenant information
    user_id UUID,
    organization_id UUID,
    
    -- Metadata
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

-- Lease Versions table
CREATE TABLE IF NOT EXISTS intelligence.lease_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_id UUID NOT NULL REFERENCES intelligence.leases(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    document_url TEXT NOT NULL,
    raw_text TEXT NOT NULL,
    abstracted_terms JSONB NOT NULL,
    
    -- Change tracking
    changes JSONB, -- Diff from previous version
    change_summary TEXT,
    change_type VARCHAR(50), -- 'AMENDMENT', 'RENEWAL', 'TERMINATION', 'NEW_VERSION'
    significant_changes BOOLEAN DEFAULT FALSE,
    
    -- Processing metadata
    processed_at TIMESTAMP DEFAULT NOW(),
    processing_time_ms INT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    
    UNIQUE(lease_id, version_number)
);

CREATE INDEX idx_lease_versions_lease_id ON intelligence.lease_versions(lease_id);
CREATE INDEX idx_lease_versions_version_number ON intelligence.lease_versions(version_number);

-- ============================================
-- PHASE 2: CONTRACT INTELLIGENCE TABLES
-- ============================================

-- Contracts table
CREATE TABLE IF NOT EXISTS intelligence.contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_number VARCHAR(100) UNIQUE NOT NULL,
    contract_name VARCHAR(255) NOT NULL,
    party_a VARCHAR(255) NOT NULL,
    party_b VARCHAR(255) NOT NULL,
    contract_type VARCHAR(100), -- 'SERVICE', 'SUPPLY', 'MSA', 'NDA', etc.
    jurisdiction VARCHAR(100),
    
    -- Document storage
    document_url TEXT NOT NULL,
    document_storage_key VARCHAR(255),
    raw_text TEXT NOT NULL,
    document_type VARCHAR(50) DEFAULT 'PDF',
    file_size INT,
    
    -- Processing status
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'ERROR', 'ARCHIVED')),
    processing_status VARCHAR(50),
    processing_error TEXT,
    processed_at TIMESTAMP,
    processing_time_ms INT,
    
    -- Abstracted data
    abstracted_terms JSONB,
    key_clauses JSONB,
    financial_terms JSONB,
    
    -- Confidence scores
    extraction_confidence FLOAT,
    validation_score FLOAT,
    
    -- User/tenant information
    user_id UUID,
    organization_id UUID,
    
    -- Metadata
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

-- Contract Versions table
CREATE TABLE IF NOT EXISTS intelligence.contract_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID NOT NULL REFERENCES intelligence.contracts(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    document_url TEXT NOT NULL,
    raw_text TEXT NOT NULL,
    abstracted_terms JSONB NOT NULL,
    
    -- Change tracking
    changes JSONB,
    change_summary TEXT,
    change_type VARCHAR(50), -- 'AMENDMENT', 'RENEWAL', 'TERMINATION', 'NEW_VERSION'
    significant_changes BOOLEAN DEFAULT FALSE,
    
    -- Processing metadata
    processed_at TIMESTAMP DEFAULT NOW(),
    processing_time_ms INT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    
    UNIQUE(contract_id, version_number)
);

CREATE INDEX idx_contract_versions_contract_id ON intelligence.contract_versions(contract_id);
CREATE INDEX idx_contract_versions_version_number ON intelligence.contract_versions(version_number);

-- Clauses table
CREATE TABLE IF NOT EXISTS intelligence.clauses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID NOT NULL REFERENCES intelligence.contracts(id) ON DELETE CASCADE,
    clause_number VARCHAR(50),
    clause_type VARCHAR(100) NOT NULL, -- 'TERMINATION', 'PAYMENT', 'LIABILITY', etc.
    clause_title VARCHAR(255),
    clause_text TEXT NOT NULL,
    version_number INT NOT NULL,
    extracted_at TIMESTAMP DEFAULT NOW(),
    
    -- Evolution tracking
    previous_version_id UUID REFERENCES intelligence.clauses(id),
    changes JSONB,
    change_type VARCHAR(50), -- 'ADDED', 'MODIFIED', 'DELETED', 'UNCHANGED'
    change_summary TEXT,
    significant_change BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    confidence FLOAT,
    source_section VARCHAR(100),
    page_number INT,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    
    -- Relations
    CONSTRAINT fk_clause_previous_version FOREIGN KEY (previous_version_id) REFERENCES intelligence.clauses(id)
);

CREATE INDEX idx_clauses_contract_id_version ON intelligence.clauses(contract_id, version_number);
CREATE INDEX idx_clauses_clause_type ON intelligence.clauses(clause_type);
CREATE INDEX idx_clauses_change_type ON intelligence.clauses(change_type);
CREATE INDEX idx_clauses_previous_version_id ON intelligence.clauses(previous_version_id);

-- ============================================
-- SHARED: OBLIGATIONS & DEPENDENCIES
-- ============================================

-- Obligations table (shared between leases and contracts)
CREATE TABLE IF NOT EXISTS intelligence.obligations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lease_id UUID REFERENCES intelligence.leases(id) ON DELETE CASCADE,
    contract_id UUID REFERENCES intelligence.contracts(id) ON DELETE CASCADE,
    
    description TEXT NOT NULL,
    obligation_type VARCHAR(50) NOT NULL, -- 'PAYMENT', 'MAINTENANCE', 'NOTIFICATION', etc.
    party VARCHAR(50), -- 'TENANT', 'LANDLORD', 'PARTY_A', 'PARTY_B', 'BOTH'
    
    -- Dates
    deadline TIMESTAMP,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    
    -- Frequency
    frequency VARCHAR(50), -- 'ONE_TIME', 'MONTHLY', 'QUARTERLY', 'ANNUAL', 'ONGOING'
    
    -- Financial
    amount FLOAT,
    currency VARCHAR(10) DEFAULT 'USD',
    
    -- Source
    source_clause TEXT,
    confidence FLOAT,
    
    -- Status
    status VARCHAR(50) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'OVERDUE', 'CANCELLED')),
    completed_at TIMESTAMP,
    
    -- Assignment
    owner VARCHAR(255),
    owner_email VARCHAR(255),
    
    -- Metadata
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Ensure at least one parent reference
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
    dependency_type VARCHAR(50) NOT NULL, -- 'TRIGGERS', 'BLOCKS', 'MODIFIES', 'REQUIRES', 'PRECEDES', 'ENABLES', 'INVALIDATES'
    description TEXT,
    
    -- Source and target context
    source_contract_id UUID REFERENCES intelligence.contracts(id),
    target_contract_id UUID REFERENCES intelligence.contracts(id),
    source_lease_id UUID REFERENCES intelligence.leases(id),
    target_lease_id UUID REFERENCES intelligence.leases(id),
    
    -- Dependency strength and metadata
    confidence FLOAT, -- 0-1 confidence in dependency
    strength VARCHAR(50), -- 'STRONG', 'MODERATE', 'WEAK'
    conditions JSONB, -- Conditions under which dependency applies
    trigger_events TEXT[] DEFAULT '{}', -- Events that trigger dependency
    
    -- Cascade analysis
    cascade_depth INT DEFAULT 1, -- How many levels deep
    cascade_impact VARCHAR(50), -- 'HIGH', 'MEDIUM', 'LOW'
    
    -- Metadata
    detected_at TIMESTAMP DEFAULT NOW(),
    detected_by VARCHAR(100), -- 'AI', 'MANUAL', 'RULE'
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
CREATE INDEX idx_obligation_dependencies_dependency_type ON intelligence.obligation_dependencies(dependency_type);
CREATE INDEX idx_obligation_dependencies_cascade_impact ON intelligence.obligation_dependencies(cascade_impact);
```

---

## 📋 Phase 1/2 Table Requirements Summary

### Phase 1: Lease Abstraction (Months 1-6)

**Required Tables:**
1. ✅ `intelligence.leases` - Main lease documents
2. ✅ `intelligence.lease_versions` - Version tracking
3. ✅ `intelligence.obligations` - Extracted obligations (shared with Phase 2)

**Key Features:**
- Document upload and storage
- Text extraction (PDF/DOCX)
- Structured data extraction (financial terms, dates, clauses)
- Obligation extraction and tracking
- Version comparison

### Phase 2: Contract Intelligence (Months 7-12)

**Required Tables:**
1. ✅ `intelligence.contracts` - Main contract documents
2. ✅ `intelligence.contract_versions` - Version tracking
3. ✅ `intelligence.clauses` - Extracted clauses with evolution tracking
4. ✅ `intelligence.obligation_dependencies` - Dependency graph

**Key Features:**
- Contract document processing
- Clause extraction and classification
- Clause evolution tracking (version-to-version changes)
- Obligation dependency graph building
- Cross-document dependency detection

---

## 🔄 Migration Plan

### Step 1: Create Intelligence Schema
```sql
-- Run in postgres-init.sql or separate migration
CREATE SCHEMA IF NOT EXISTS intelligence;
```

### Step 2: Create Tables
- Add all table creation SQL to `postgres-init.sql`
- Or create separate migration file: `migrations/001_create_intelligence_schema.sql`

### Step 3: Update Prisma Schemas

**For Language Intelligence Service:**
```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  schemas  = ["intelligence", "public"]
}

// All models use @@schema("intelligence")
model Lease {
  // ... fields ...
  @@schema("intelligence")
  @@map("leases")
}
```

### Step 4: Resolve Tasks Conflict

**Option A: Use postgres-init.sql as source of truth**
- Remove `CREATE TABLE` from Prisma migrations
- Use Prisma only for type definitions
- Run `postgres-init.sql` first

**Option B: Use Prisma as source of truth**
- Remove `CREATE TABLE` from `postgres-init.sql`
- Let Prisma migrations create the table
- Document which service "owns" the table

**Recommended: Option A** (postgres-init.sql as source of truth)

---

## 📊 Final Schema Organization

```
PostgreSQL Database
│
├── public (Core Platform Data)
│   ├── users, sessions, roles (auth service)
│   ├── tasks, task_versions, task_dependencies (SHARED - from postgres-init.sql)
│   ├── projects (platform)
│   ├── quests, seasons, rewards (engagement service)
│   └── subtasks (engagement service)
│
├── analytics (Gamification Data)
│   ├── momentum, streaks, boosts (engagement service)
│   └── achievements (engagement service)
│
├── audit (Audit Logs)
│   ├── activity_logs (platform)
│   ├── task_completions (engagement service)
│   └── user_activity_summary (platform)
│
├── cyrex (AI/Agent System) ✅
│   └── All AI/agent tables
│
└── intelligence (Language Intelligence Platform) ✅ NEW!
    ├── leases (Phase 1)
    ├── lease_versions (Phase 1)
    ├── contracts (Phase 2)
    ├── contract_versions (Phase 2)
    ├── clauses (Phase 2)
    ├── obligations (Phase 1 & 2 - shared)
    └── obligation_dependencies (Phase 2)
```

---

## ✅ Action Items

1. **Create Intelligence Schema**
   - [ ] Add schema creation to `postgres-init.sql`
   - [ ] Create all Phase 1 tables (leases, lease_versions, obligations)
   - [ ] Create all Phase 2 tables (contracts, contract_versions, clauses, obligation_dependencies)

2. **Resolve Tasks Conflict**
   - [ ] Document that `tasks` table is shared
   - [ ] Ensure both Prisma schemas match `postgres-init.sql` structure
   - [ ] Update documentation

3. **Update Prisma Schemas**
   - [ ] Language Intelligence Service: Add `intelligence` schema support
   - [ ] Task Orchestrator: Ensure references `public.tasks`
   - [ ] Engagement Service: Ensure references `public.tasks`

4. **Documentation**
   - [ ] Update `COMPREHENSIVE_POSTGRES_REORGANIZATION.md`
   - [ ] Create migration guide
   - [ ] Document table ownership

---

## 🎯 Next Steps

1. **Immediate:** Create intelligence schema SQL
2. **Short-term:** Update Prisma schemas
3. **Long-term:** Migrate existing data (if any) to new schema

