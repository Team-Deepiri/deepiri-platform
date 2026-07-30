# Platform PostgreSQL Plan (Non-Cyrex)

**Owner:** DeepIRI Platform
**Scope:** `postgres-auth`, `postgres-core`, `postgres-intelligence` from `docker-compose.dev.yml`
**Out of scope:** `postgres-cyrex` / `cyrex_db` — see Cyrex AGI artifact-store plan separately
**Status:** Target architecture (refined). Documents current state + migration direction.

**Coordination note:** This is a platform-side target, not the final cross-team
database allocation by itself. The final split between additional containers,
schemas, and service-owned databases still needs review with Connor, Daev,
Future, and Joe before migrations are implemented.

---

## Table of Contents

1. [Design principles](#1-design-principles)
2. [Compose topology](#2-compose-topology)
3. [What does not belong here](#3-what-does-not-belong-here)
4. [Database 1: postgres-auth](#4-database-1-postgres-auth)
5. [Database 2: postgres-core](#5-database-2-postgres-core)
6. [Database 3: postgres-intelligence](#6-database-3-postgres-intelligence)
7. [Service → database map](#7-service--database-map)
8. [Cross-database references](#8-cross-database-references)
9. [Init scripts vs Prisma](#9-init-scripts-vs-prisma)
10. [Migration phases](#10-migration-phases)
11. [DDL file layout (target)](#11-ddl-file-layout-target)
12. [Open issues](#12-open-issues)

---

## 1. Design principles

### 1.1 Three platform databases, one job each

| Instance | Job |
|----------|-----|
| **postgres-auth** | Identity, authorization, API keys |
| **postgres-core** | Product data: work management, projects, messaging, audit |
| **postgres-intelligence** | **Shrink to ops only** (MLflow metadata). Document/AI memory lives in **cyrex_db**. |

### 1.2 Explicit exclusions (this plan)

The following are **not** part of the target platform Postgres design:

- **Gamification / engagement analytics** — no `achievements`, `momentum`, `streaks`, `boosts`, `level_progress`, season/quest reward loops in Postgres
- **Lease / contract / obligation domain tables** — retired from `intelligence_db`
- **Cyrex agent memory, artifacts, training samples** — `postgres-cyrex` only
- **Vector embeddings** — Milvus (+ optional cyrex mirror), not platform Postgres
- **Time-series metrics** — InfluxDB / Prometheus, not platform Postgres

Engagement features, if revived later, should use **event streams + a dedicated store** (or Influx), not core relational schemas.

### 1.3 UUID identity across services

- Canonical user identity: `auth_db.users.id` (UUID)
- Platform services store `user_id UUID` **without FK** across database boundaries (compose uses separate Postgres containers)
- Cyrex/LIS reference the same UUID in `actor_id` / `user_id` columns

---

## 2. Compose topology

From `docker-compose.dev.yml`:

| Compose service | Host port | Container port | Database | Init script |
|-----------------|-----------|----------------|----------|-------------|
| `postgres-auth` | 5432 | 5432 | `auth_db` | `scripts/database/postgres-init-auth.sql` |
| `postgres-core` | 5433 | 5432 | `deepiri` | `scripts/database/postgres-init-core.sql` |
| `postgres-cyrex` | 5434 | 5432 | `cyrex_db` | `scripts/database/postgres-init-cyrex.sql` |
| `postgres-intelligence` | 5435 | 5432 | `intelligence_db` | `scripts/database/postgres-init-intelligence.sql` |

**Legacy:** `scripts/database/postgres-init.sql` is the old monolithic bootstrap. Compose uses the **split** init files above.

**Adminer** defaults to `postgres-core` only.

---

## 3. What does not belong here

| Data | Correct home |
|------|----------------|
| Artifact graph, citations, pipeline runs | `cyrex_db` |
| Helox training mirror (`helox_training_samples`) | `cyrex_db` |
| Agent workflows, memories, guardrails | `cyrex_db` |
| Document chunks for RAG / AGI | `cyrex_db` + Milvus |
| User login, roles, API keys | `auth_db` |
| Team tasks, projects, chat | `postgres-core` |
| ML experiment tracking | `intelligence_db` (MLflow) or external MLflow |

---

## 4. Database 1: postgres-auth

**Database name:** `auth_db`
**Primary service:** `deepiri-auth-service`
**Init:** `postgres-init-auth.sql`
**Extensions:** `uuid-ossp`

### 4.1 Target schemas

Single schema: **`public`** (no multi-schema complexity needed for auth).

### 4.2 Target tables

#### Core identity (keep)

| Table | Purpose | Owner |
|-------|---------|-------|
| `users` | Accounts | auth-service |
| `sessions` | Login sessions / tokens | auth-service |
| `roles` | Named roles | auth-service |
| `role_abilities` | RBAC ability grants | auth-service |
| `user_roles` | User ↔ role assignments | auth-service |

#### Service access (keep — Prisma today)

| Table | Purpose | Owner |
|-------|---------|-------|
| `api_keys` | Service account / ingestion keys | auth-service |

#### Social / profile (optional — keep if product uses it)

| Table | Purpose | Owner |
|-------|---------|-------|
| `social_connections` | User graph | auth-service |

#### Remove from auth target (gamification-adjacent)

| Table | Action | Rationale |
|-------|--------|-----------|
| `skill_trees` | **Remove** | Game progression, not identity |
| `skills` | **Remove** | Same |
| `progress_points` | **Remove** | Gamification counter |

If profile “skills” return as a product feature, model them in **core** as `user_competencies` tied to real work outcomes—not XP.

### 4.3 Target DDL sketch

```sql
-- auth_db / public
users (
  id UUID PK,
  email VARCHAR UNIQUE NOT NULL,
  password_hash VARCHAR NOT NULL,
  name VARCHAR NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  status VARCHAR DEFAULT 'active',
  email_verified BOOLEAN DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
)

sessions (
  id UUID PK,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR UNIQUE NOT NULL,
  ip_address INET,
  user_agent TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
)

roles ( id UUID PK, name VARCHAR UNIQUE, description TEXT, is_system BOOLEAN, ... )
role_abilities ( id UUID PK, role_id UUID FK, ability VARCHAR, resource VARCHAR, ... )
user_roles ( id UUID PK, user_id UUID FK, role_id UUID FK, ... )

api_keys (
  id UUID PK,
  hashed_key VARCHAR UNIQUE,
  owner_id UUID FK → users,
  label VARCHAR,
  scopes TEXT[],
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

### 4.4 Subscribers (who reads auth_db)

| Consumer | Reads | Pattern |
|----------|-------|---------|
| auth-service | all tables | CRUD |
| api-gateway | validates JWT / introspection | HTTP to auth |
| All platform services | `user_id` only | JWT claims, no direct DB |

No other service should connect to `auth_db` in the target design.

---

## 5. Database 2: postgres-core

**Database name:** `deepiri`
**Services:** workflow-orchestrator, incentive-engine (trimmed), messaging-service, decision-intelligence, communications-hub, external-bridge-service, adaptive-experience-engine, api-gateway (partial)
**Init:** `postgres-init-core.sql`
**Extensions:** `uuid-ossp`, `pg_trgm`, `btree_gin`

### 5.1 Target schemas

| Schema | Purpose |
|--------|---------|
| `public` | Work management: projects, tasks, dependencies |
| `messaging` | User/agent chat (Prisma-managed today) |
| `audit` | Compliance and entity change history |
| ~~`analytics`~~ | **Dropped** from platform Postgres target |

### 5.2 Target tables — `public`

#### Work management (keep)

| Table | Purpose | Primary owner |
|-------|---------|---------------|
| `projects` | User/team projects | platform |
| `project_milestones` | Project checkpoints | platform |
| `tasks` | Work items | workflow-orchestrator + incentive-engine (consolidate ownership) |
| `subtasks` | Checklist items on tasks | incentive-engine |
| `task_dependencies` | DAG edges between tasks | workflow-orchestrator |
| `task_versions` | Task edit history | workflow-orchestrator |

**`tasks` canonical fields (target):**

```sql
tasks (
  id UUID PK,
  user_id UUID NOT NULL,           -- logical ref to auth_db.users
  project_id UUID FK → projects,
  parent_task_id UUID FK → tasks,
  title VARCHAR(500) NOT NULL,
  description TEXT,
  status VARCHAR CHECK (...),       -- todo | in_progress | blocked | review | done | cancelled
  priority VARCHAR,
  due_date TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  estimated_minutes INT,
  actual_minutes INT,
  tags TEXT[],
  metadata JSONB DEFAULT '{}',      -- AI suggestions, integrations, etc.
  version INT DEFAULT 1,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  updated_by UUID
)
```

Remove gamification columns from tasks in target migrations: `momentum_reward`, difficulty-based reward hooks.

#### Remove from `public` target (gamification / seasons)

| Table | Action |
|-------|--------|
| `seasons` | **Remove** |
| `season_boosts` | **Remove** |
| `quests` | **Remove** (or rename to `goals` without XP if product still needs long-running objectives) |
| `quest_milestones` | **Remove** |
| `rewards` | **Remove** |

If the product still needs “long horizon objectives,” replace `quests` with a slim:

```sql
goals (
  id UUID PK,
  user_id UUID NOT NULL,
  project_id UUID FK NULL,
  title VARCHAR NOT NULL,
  status VARCHAR,
  target_date TIMESTAMPTZ,
  metadata JSONB,
  ...
)
```

No momentum, no rarity, no boost credits.

### 5.3 Target tables — `messaging`

Managed by **messaging-service** Prisma (`@@schema("messaging")`). Not in `postgres-init-core.sql` today — created by migrate.

| Table | Purpose |
|-------|---------|
| `messaging.chat_rooms` | Rooms (direct, group, agent) |
| `messaging.chat_participants` | Membership |
| `messaging.messages` | Message bodies |
| `messaging.message_read_receipts` | Read state |

**Add to init (target):** `CREATE SCHEMA IF NOT EXISTS messaging;` in core bootstrap so fresh installs do not rely on Prisma alone.

### 5.4 Target tables — `audit`

Keep audit **entity-focused**, not gamification-focused.

| Table | Purpose | Keep? |
|-------|---------|-------|
| `audit.activity_logs` | INSERT/UPDATE/DELETE via triggers | **Yes** |
| `audit.task_completions` | Task done events | **Yes** — strip `momentum_earned` |
| `audit.user_activity_summary` | Rollups | **Optional** — strip momentum counters |

**Target `task_completions`:**

```sql
audit.task_completions (
  id UUID PK,
  task_id UUID FK → public.tasks,
  user_id UUID NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  time_taken_minutes INT,
  quality_rating INT CHECK (1-5),
  auto_detected BOOLEAN DEFAULT FALSE,
  completion_method VARCHAR,
  metadata JSONB DEFAULT '{}'
)
```

### 5.5 Remove entire `analytics` schema (current → target)

**Current** (`postgres-init-core.sql`) — all **deprecated** in this plan:

| Table | Status |
|-------|--------|
| `analytics.momentum` | Remove |
| `analytics.level_progress` | Remove |
| `analytics.achievements` | Remove |
| `analytics.streaks` | Remove |
| `analytics.cashed_in_streaks` | Remove |
| `analytics.boosts` | Remove |
| `analytics.active_boosts` | Remove |
| `analytics.boost_history` | Remove |

**incentive-engine** Prisma models mapping to these tables should be deleted or the service scope reduced to task CRUD only on `public.tasks`.

### 5.6 What connects to postgres-core

| Service | Tables used (target) |
|---------|----------------------|
| workflow-orchestrator | `tasks`, `task_versions`, `task_dependencies` |
| messaging-service | `messaging.*` |
| incentive-engine | `tasks`, `subtasks` only (after trim) |
| decision-intelligence | read `tasks`, `projects` metadata (no new tables) |
| communications-hub | integration state in `metadata` JSONB or own small tables TBD |
| external-bridge-service | webhook delivery logs — **add** `audit.integration_events` if needed |
| adaptive-experience-engine | read preferences from `users.metadata` via API, not direct DB |

### 5.7 Optional future `public` tables (not gamification)

| Table | When |
|-------|------|
| `organizations` | Multi-tenant B2B |
| `organization_members` | Multi-tenant B2B |
| `user_preferences` | UX settings (or stay in auth `users.metadata`) |
| `notifications` | If not fully in Redis/Synapse |
| `files` | Platform file registry (S3 keys) — if not only MinIO catalog |

---

## 6. Database 3: postgres-intelligence

**Database name:** `intelligence_db`
**Primary service today:** `deepiri-language-intelligence-service`
**Also:** MLflow `BACKEND_STORE_URI` in compose
**Init:** `postgres-init-intelligence.sql`

### 6.1 Problem statement (current)

1. Init SQL creates **`intelligence.*`** domain tables (leases, contracts, obligations).
2. LIS Prisma creates **`public.*`** tables with the **same names** (no `@@schema("intelligence")` on models).
3. Generic models (`documents`, `document_chunks`, …) live here but **AGI document processing belongs in cyrex_db**.
4. Duplication and drift between SQL init and Prisma migrate.

### 6.2 Target role for intelligence_db

**Narrow ops database:**

| Keep | Remove |
|------|--------|
| MLflow experiment/run/artifact metadata (MLflow-managed tables) | All `intelligence.leases` … `obligation_dependencies` |
| Optional: `platform.document_uploads` staging index | LIS `leases`, `contracts`, `clauses`, `obligations`, … |
| | `documents`, `document_chunks`, `embeddings`, `analysis_*` (→ cyrex) |
| | LIS chat (`chat_sessions`, `messages`) → **messaging** or cyrex |

### 6.3 Target tables (minimal)

#### Option A — MLflow only (recommended)

Let `intelligence_db` be **MLflow backend** only. LIS becomes a thin API gateway to Cyrex:

- No LIS-owned document tables
- Upload flows: LIS → MinIO → Cyrex `POST /api/v1/artifacts/upload`
- `DATABASE_URL` for LIS either removed or pointed at a tiny config DB

#### Option B — Staging + MLflow

If LIS must retain a Postgres footprint before full Cyrex cutover:

```sql
-- intelligence_db / platform schema
CREATE SCHEMA IF NOT EXISTS platform;

platform.upload_jobs (
  job_id UUID PK,
  user_id UUID NOT NULL,
  storage_key TEXT NOT NULL,
  filename TEXT,
  mime_type VARCHAR,
  byte_size BIGINT,
  status VARCHAR,          -- pending | uploaded | handed_off | failed
  cyrex_document_id TEXT,  -- set after Cyrex ingest
  cyrex_run_id TEXT,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
)

platform.upload_job_events (
  event_id UUID PK,
  job_id UUID FK,
  event_type VARCHAR,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

No extracted fields, no embeddings, no domain JSON blobs.

### 6.4 Retire list (intelligence_db)

**From init SQL (`intelligence` schema):**

- `intelligence.leases`
- `intelligence.lease_versions`
- `intelligence.contracts`
- `intelligence.contract_versions`
- `intelligence.clauses`
- `intelligence.obligations`
- `intelligence.obligation_dependencies`

**From LIS Prisma (public):**

- `leases`, `lease_versions`, `contracts`, `contract_versions`, `clauses`, `obligations`, `obligation_dependencies`
- `documents`, `document_chunks`, `analysis_jobs`, `analysis_results`, `embeddings`
- `prompt_templates` → cyrex or config service
- `chat_sessions`, `messages` → `messaging` schema on core **or** drop if Cyrex playground replaces

### 6.5 LIS service target behavior

```
Client → LIS API → MinIO (blob) → Cyrex artifact pipeline → cyrex_db
                ↘ platform.upload_jobs (status only, optional)
```

LIS does **not** own document intelligence storage.

---

## 7. Service → database map

| Service | Database | Target tables |
|---------|----------|---------------|
| auth-service | postgres-auth | `users`, `sessions`, `roles`, `user_roles`, `role_abilities`, `api_keys` |
| workflow-orchestrator | postgres-core | `tasks`, `task_versions`, `task_dependencies` |
| messaging-service | postgres-core | `messaging.*` |
| incentive-engine | postgres-core | `tasks`, `subtasks` only |
| decision-intelligence | postgres-core | read-only `tasks`, `projects` |
| communications-hub | postgres-core | TBD audit/integration |
| external-bridge-service | postgres-core | TBD webhook audit |
| adaptive-experience-engine | postgres-core | via APIs |
| language-intelligence-service | **none or staging only** | `platform.upload_jobs` optional |
| mlflow | postgres-intelligence | MLflow schema |
| **cyrex** | **postgres-cyrex** | not this document |

---

## 8. Cross-database references

Postgres **cannot enforce FK** across compose services. Pattern:

```text
auth_db.users.id  =  UUID carried in JWT
core.tasks.user_id = same UUID (no FK)
cyrex.*.actor_id   = same UUID (no FK)
```

Document the UUID in API contracts; use integration tests for consistency.

---

## 9. Init scripts vs Prisma

| Source | Applies to | Notes |
|--------|------------|-------|
| `postgres-init-auth.sql` | auth | Baseline; Prisma adds extra tables today |
| `postgres-init-core.sql` | core | Contains **deprecated** analytics gamification |
| `postgres-init-intelligence.sql` | intelligence | Contains **deprecated** domain tables |
| Prisma migrate on boot | per service | Can duplicate or conflict with init SQL |

**Target rule:** Init SQL owns **baseline DDL**; Prisma migrations must **match** init, not invent parallel tables.

**Action items:**

1. Split `postgres-init-core.sql` → remove `analytics` section; add `CREATE SCHEMA messaging`.
2. Replace `postgres-init-intelligence.sql` → MLflow note + optional `platform.upload_jobs` only.
3. Align LIS Prisma with retire list (drop models).
4. Trim incentive-engine Prisma to tasks/subtasks.

---

## 10. Migration phases

### Phase 0 — Document & freeze (now)

- [ ] Mark `analytics.*` and `intelligence.*` domain as deprecated in runbooks
- [ ] Stop new features on achievements, momentum, streaks, quests
- [ ] New document features go to Cyrex only

### Phase 1 — Core cleanup

- [ ] New migration `core/002_drop_analytics_schema.sql` (backup first)
- [ ] Remove gamification columns from `tasks`, `subtasks`, `audit.task_completions`
- [ ] Add `messaging` schema to init SQL
- [ ] Trim incentive-engine service scope

### Phase 2 — Auth cleanup

- [ ] Migration drop `skill_trees`, `skills`, `progress_points`
- [ ] Export data if needed, then remove Prisma models

### Phase 3 — Intelligence shrink

- [ ] Stop LIS writes to domain + document tables
- [ ] Route uploads through Cyrex
- [ ] Migration drop `intelligence.*` + LIS document models
- [ ] Keep MLflow on `intelligence_db`

### Phase 4 — Optional consolidate

Long-term: consider **two** platform databases (`auth` + `core`) and drop `postgres-intelligence` if MLflow moves to S3/SQLite backend.

---

## 11. DDL file layout (target)

```text
scripts/database/
├── postgres-init-auth.sql          # identity only
├── postgres-init-core.sql          # public + messaging + audit (no analytics)
├── postgres-init-intelligence.sql  # MLflow comment + platform.upload_jobs optional
├── postgres-init-cyrex.sql         # (separate AGI doc)
├── migrations/
│   ├── auth/
│   │   └── 001_baseline.sql
│   │   └── 002_drop_skill_gamification.sql
│   ├── core/
│   │   └── 001_baseline.sql
│   │   └── 002_drop_analytics_schema.sql
│   │   └── 003_add_messaging_schema.sql
│   │   └── 004_strip_task_gamification_columns.sql
│   └── intelligence/
│       └── 001_drop_domain_schema.sql
│       └── 002_add_upload_jobs.sql
└── postgres-init.sql               # DEPRECATED — pointer README only
```

---

## 12. Open issues

| Issue | Impact |
|-------|--------|
| `intelligence.leases` vs `public.leases` duplicate | Fresh installs may have two lease models; fix in Phase 3 |
| incentive-engine owns analytics Prisma | Service must be refactored or renamed to task-service |
| `workflow-orchestrator` and incentive-engine both touch `tasks` | Document single write owner (recommend workflow-orchestrator) |
| MLflow + LIS share `intelligence_db` | Separate schemas; consider separate DB user permissions |
| Helox `POSTGRES_DSN` defaults to wrong host DB | Wire to `cyrex_db` in compose (Cyrex doc) |
| `postgres-init.sql` still in repo | Add deprecation banner; remove from docs |
| Final DB/container count may change | Review with Connor, Daev, Future, and Joe before implementing migrations |

---

## Summary

| Database | Target size | Core idea |
|----------|-------------|-----------|
| **auth_db** | ~6 tables | Who you are |
| **deepiri (core)** | ~12 tables + messaging | What you're working on + chat + audit |
| **intelligence_db** | MLflow (+ optional upload job index) | Not document AI |
| **cyrex_db** | separate plan | All AGI / document / training memory |

**No achievements. No momentum. No streaks. No lease tables in platform Postgres.**

---

*Related: Cyrex AGI artifact store and `helox_training_samples` belong in `docs/architecture/` Cyrex Postgres plan (separate document).*
