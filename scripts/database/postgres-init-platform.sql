-- =============================================================================
-- Deepiri CLOUD postgres-platform — FULL INIT
-- DB name: platform  (container: postgres-platform)
-- Fits: internal portal, My Deepiri, tools catalog, onboarding, vizult, Plaky
-- Does NOT include: Cyrex, language-intelligence, milvus, etc.
-- Apply as DB owner after CREATE DATABASE platform.
-- Idempotent where possible (IF NOT EXISTS / ON CONFLICT).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS org;
CREATE SCHEMA IF NOT EXISTS portal;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS onboarding;
CREATE SCHEMA IF NOT EXISTS vizult;
CREATE SCHEMA IF NOT EXISTS integrations;
CREATE SCHEMA IF NOT EXISTS jobs_meta;
CREATE SCHEMA IF NOT EXISTS registry;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- identity
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           TEXT NOT NULL,
  email_norm      TEXT GENERATED ALWAYS AS (lower(email)) STORED,
  password_hash   TEXT,
  name            TEXT NOT NULL,
  avatar_url      TEXT,
  status          TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'inactive', 'suspended', 'invited')),
  email_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at   TIMESTAMPTZ,
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT users_email_norm_unique UNIQUE (email_norm)
);

CREATE TABLE IF NOT EXISTS identity.roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  is_system   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS identity.user_roles (
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role_id     UUID NOT NULL REFERENCES identity.roles(id) ON DELETE CASCADE,
  granted_by  UUID REFERENCES identity.users(id),
  granted_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMPTZ,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS identity.sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  token_hash    TEXT NOT NULL UNIQUE,
  ip_address    INET,
  user_agent    TEXT,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS identity.api_keys (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  key_hash      TEXT NOT NULL UNIQUE,
  scopes        TEXT[] NOT NULL DEFAULT '{}',
  expires_at    TIMESTAMPTZ,
  last_used_at  TIMESTAMPTZ,
  revoked_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS identity.invites (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT NOT NULL,
  role_hint     TEXT,
  token_hash    TEXT NOT NULL UNIQUE,
  invited_by    UUID REFERENCES identity.users(id),
  accepted_at   TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON identity.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON identity.sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_api_keys_user ON identity.api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_invites_email ON identity.invites(lower(email));

INSERT INTO identity.roles (name, description, is_system) VALUES
  ('admin', 'Full portal administrator', TRUE),
  ('member', 'Standard Deepiri member', TRUE),
  ('guest', 'Limited invite access', TRUE)
ON CONFLICT (name) DO NOTHING;

DROP TRIGGER IF EXISTS trg_users_updated ON identity.users;
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON identity.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- org
-- =============================================================================

CREATE TABLE IF NOT EXISTS org.teams (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS org.team_members (
  team_id     UUID NOT NULL REFERENCES org.teams(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'member'
              CHECK (role IN ('owner', 'admin', 'member')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (team_id, user_id)
);

CREATE TABLE IF NOT EXISTS org.projects (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  kind        TEXT NOT NULL DEFAULT 'product'
              CHECK (kind IN ('product', 'lib', 'infra', 'research', 'tool', 'other')),
  repo_url    TEXT,
  docs_url    TEXT,
  status      TEXT NOT NULL DEFAULT 'active'
              CHECK (status IN ('active', 'paused', 'archived')),
  metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS org.project_members (
  project_id  UUID NOT NULL REFERENCES org.projects(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'contributor'
              CHECK (role IN ('lead', 'contributor', 'viewer')),
  assigned_by UUID REFERENCES identity.users(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (project_id, user_id)
);

CREATE TABLE IF NOT EXISTS org.project_teams (
  project_id  UUID NOT NULL REFERENCES org.projects(id) ON DELETE CASCADE,
  team_id     UUID NOT NULL REFERENCES org.teams(id) ON DELETE CASCADE,
  PRIMARY KEY (project_id, team_id)
);

CREATE INDEX IF NOT EXISTS idx_project_members_user ON org.project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON org.team_members(user_id);

DROP TRIGGER IF EXISTS trg_teams_updated ON org.teams;
CREATE TRIGGER trg_teams_updated BEFORE UPDATE ON org.teams
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_projects_updated ON org.projects;
CREATE TRIGGER trg_projects_updated BEFORE UPDATE ON org.projects
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO org.projects (slug, name, description, kind, status) VALUES
  ('cyrex', 'Cyrex', 'Agentic runtime / AGI plane', 'product', 'active'),
  ('helox', 'Helox', 'Fine-tuning / model versioning library', 'lib', 'active'),
  ('zepgpu', 'ZepGPU', 'GPU rooms and scheduling', 'product', 'active'),
  ('platform', 'Deepiri Platform', 'Internal portal and cloud control surface', 'infra', 'active'),
  ('vizult', 'Deepiri Vizult', 'Architecture / dependency graph tooling', 'tool', 'active')
ON CONFLICT (slug) DO NOTHING;

-- =============================================================================
-- portal
-- =============================================================================

CREATE TABLE IF NOT EXISTS portal.announcements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  body_md       TEXT NOT NULL,
  author_id     UUID REFERENCES identity.users(id),
  pinned        BOOLEAN NOT NULL DEFAULT FALSE,
  published_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS portal.events (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title          TEXT NOT NULL,
  kind           TEXT NOT NULL
                 CHECK (kind IN ('meeting', 'demo', 'hackathon', 'research_talk', 'other')),
  starts_at      TIMESTAMPTZ NOT NULL,
  ends_at        TIMESTAMPTZ,
  location_url   TEXT,
  description_md TEXT,
  created_by     UUID REFERENCES identity.users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS portal.event_rsvps (
  event_id    UUID NOT NULL REFERENCES portal.events(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  status      TEXT NOT NULL CHECK (status IN ('going', 'maybe', 'no')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_events_starts ON portal.events(starts_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_published ON portal.announcements(published_at DESC NULLS LAST);

DROP TRIGGER IF EXISTS trg_announcements_updated ON portal.announcements;
CREATE TRIGGER trg_announcements_updated BEFORE UPDATE ON portal.announcements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_events_updated ON portal.events;
CREATE TRIGGER trg_events_updated BEFORE UPDATE ON portal.events
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- catalog (installable tools + shared artifacts/runs)
-- =============================================================================

CREATE TABLE IF NOT EXISTS catalog.tools (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  summary       TEXT NOT NULL DEFAULT '',
  install_kind  TEXT NOT NULL DEFAULT 'cli'
                CHECK (install_kind IN ('cli', 'desktop', 'cli_desktop', 'platform')),
  categories    TEXT[] NOT NULL DEFAULT '{}',
  install_url   TEXT,
  docs_url      TEXT,
  repo_url      TEXT,
  logo_url      TEXT,
  sort_order    INT NOT NULL DEFAULT 0,
  published     BOOLEAN NOT NULL DEFAULT TRUE,
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS catalog.project_tools (
  project_id  UUID NOT NULL REFERENCES org.projects(id) ON DELETE CASCADE,
  tool_id     UUID NOT NULL REFERENCES catalog.tools(id) ON DELETE CASCADE,
  PRIMARY KEY (project_id, tool_id)
);

CREATE TABLE IF NOT EXISTS catalog.artifacts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  tool_id     UUID REFERENCES catalog.tools(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  type        TEXT NOT NULL
              CHECK (type IN ('dataset', 'doc', 'recording', 'other')),
  uri         TEXT NOT NULL,
  owner_id    UUID REFERENCES identity.users(id),
  meta        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS catalog.run_records (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id     UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  tool_id        UUID REFERENCES catalog.tools(id) ON DELETE SET NULL,
  git_sha        TEXT,
  status         TEXT NOT NULL DEFAULT 'unknown'
                 CHECK (status IN ('pending', 'running', 'passed', 'failed', 'unknown')),
  summary        JSONB NOT NULL DEFAULT '{}'::jsonb,
  artifact_uris  TEXT[] NOT NULL DEFAULT '{}',
  created_by     UUID REFERENCES identity.users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tools_published ON catalog.tools(published, sort_order);
CREATE INDEX IF NOT EXISTS idx_artifacts_project ON catalog.artifacts(project_id);
CREATE INDEX IF NOT EXISTS idx_run_records_project ON catalog.run_records(project_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_tools_updated ON catalog.tools;
CREATE TRIGGER trg_tools_updated BEFORE UPDATE ON catalog.tools
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO catalog.tools (slug, name, summary, install_kind, categories, sort_order) VALUES
  ('cyrex', 'Cyrex', 'Cyrex agentic runtime framework.', 'cli', ARRAY['CLI','Platform','AI/ML'], 10),
  ('helox', 'Helox', 'Model fine-tuning and model versioning framework.', 'cli', ARRAY['CLI','Platform','AI/ML'], 20),
  ('agent-toolbox', 'Agent Toolbox', 'Toolkit for building, testing, and deploying Deepiri AI agents.', 'cli', ARRAY['CLI','Tools'], 30),
  ('training-orchestrator', 'Training Orchestrator', 'Orchestrate distributed ML training jobs.', 'cli', ARRAY['CLI','AI/ML','Infrastructure'], 40),
  ('dataset-processor', 'Dataset Processor', 'Preprocess, transform, and version datasets.', 'cli', ARRAY['CLI','Data','AI/ML'], 50),
  ('deepiri-emotion', 'Deepiri Emotion', 'AI-powered development environment with Cyrex integrations.', 'cli_desktop', ARRAY['CLI','Desktop','HCI'], 60),
  ('memorymesh', 'MemoryMesh', 'Distributed memory layer for long-context agents and RAG.', 'cli', ARRAY['CLI','AI/ML','Infrastructure'], 70),
  ('zepgpu', 'ZepGPU', 'GPU detection, scheduling, and acceleration utilities.', 'cli', ARRAY['CLI','Infrastructure'], 80),
  ('renderflow-studio', 'Renderflow Studio', 'Creative rendering studio for real-time visual pipelines.', 'cli_desktop', ARRAY['CLI','Desktop','Media'], 90),
  ('fuselk', 'Fuselk', 'JAX-accelerated tokamak simulator with hierarchical RL control.', 'desktop', ARRAY['Desktop','Platform'], 100),
  ('egottol', 'Egottol', 'Analog SPICE and VHDL simulation lab.', 'cli_desktop', ARRAY['CLI','Desktop','HCI'], 110),
  ('gpu-utils', 'GPU Utils', 'GPU health checks, profiling, and driver diagnostics.', 'cli', ARRAY['CLI','Infrastructure'], 120),
  ('calliope', 'Calliope', 'Local-first AI music studio stack.', 'desktop', ARRAY['Desktop','AI/ML','HCI'], 130),
  ('polylogue', 'Polylogue', 'Filesystem-first shared LLM Streaming Journal Network.', 'cli', ARRAY['CLI','AI/ML'], 140),
  ('prismpipe', 'Prismpipe', 'Capability-routed, self-improving API computation pipelines.', 'cli', ARRAY['CLI','Platform','Infrastructure'], 150),
  ('mudspeed', 'Mudspeed', 'Hybrid GPU emulator with Neural ODE acceleration.', 'cli', ARRAY['CLI','AI/ML','Infrastructure'], 160),
  ('topolsea', 'Topolsea', 'SIMD-accelerated GraphANN vector database.', 'cli', ARRAY['CLI','AI/ML','Infrastructure'], 170),
  ('universal-quantum-engine', 'Universal Quantum Engine', 'Quantum experimentation lab.', 'cli', ARRAY['CLI','AI/ML'], 180),
  ('agent-guardrails', 'Agent Guardrails', 'Safety and policy guardrails for autonomous agents.', 'cli', ARRAY['CLI','Ethics','AI/ML'], 190),
  ('aarflingo', 'Aarflingo', 'Language intelligence toolkit for parsing and analysis.', 'cli', ARRAY['CLI','AI/ML','Data'], 200),
  ('wooven', 'Wooven', 'Credentials manager tool.', 'cli', ARRAY['CLI','Platform'], 210),
  ('tombstone', 'Tombstone', 'Post-training eval harness with local Ollama.', 'cli', ARRAY['CLI','AI/ML','Infrastructure'], 220),
  ('voxier', 'Voxier', 'Godot-based game project by Deepiri.', 'desktop', ARRAY['Desktop','Media','HCI'], 230),
  ('ollama-utils', 'Ollama Utils', 'Utilities for managing Ollama models and local inference.', 'cli', ARRAY['CLI','AI/ML','Tools'], 240),
  ('deepiri-platform', 'Deepiri Platform', 'Main Deepiri portal / platform stack.', 'platform', ARRAY['CLI','Platform','Infrastructure'], 250),
  ('deepiri-vizult', 'Deepiri Vizult', 'Local-first architecture dependency graph scanner.', 'cli', ARRAY['CLI','Tools','Infrastructure'], 260)
ON CONFLICT (slug) DO NOTHING;

-- Link flagship projects to tools
INSERT INTO catalog.project_tools (project_id, tool_id)
SELECT p.id, t.id
FROM org.projects p
JOIN catalog.tools t ON t.slug = p.slug OR (p.slug = 'platform' AND t.slug = 'deepiri-platform')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- registry (cloud registry service — discoverable platform endpoints)
-- =============================================================================

CREATE TABLE IF NOT EXISTS registry.services (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          TEXT NOT NULL UNIQUE,
  display_name  TEXT NOT NULL,
  base_url      TEXT,
  health_url    TEXT,
  plane         TEXT NOT NULL DEFAULT 'cloud'
                CHECK (plane IN ('cloud', 'control_plane', 'external')),
  status        TEXT NOT NULL DEFAULT 'unknown'
                CHECK (status IN ('healthy', 'degraded', 'down', 'unknown', 'disabled')),
  owner_project UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
  last_seen_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_registry_services_plane ON registry.services(plane, status);

DROP TRIGGER IF EXISTS trg_registry_services_updated ON registry.services;
CREATE TRIGGER trg_registry_services_updated BEFORE UPDATE ON registry.services
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO registry.services (slug, display_name, plane, status, metadata) VALUES
  ('api-gateway', 'API Gateway', 'cloud', 'unknown', '{"role":"edge"}'::jsonb),
  ('auth-service', 'Auth Service', 'cloud', 'unknown', '{"role":"identity"}'::jsonb),
  ('jobs', 'Jobs', 'cloud', 'unknown', '{"role":"async"}'::jsonb),
  ('registry', 'Registry', 'cloud', 'unknown', '{"role":"discovery"}'::jsonb),
  ('external-bridge-service', 'External Bridge', 'cloud', 'unknown', '{"role":"integrations","plaky":true}'::jsonb),
  ('platform-frontend', 'Platform Frontend', 'cloud', 'unknown', '{"role":"ui"}'::jsonb)
ON CONFLICT (slug) DO NOTHING;

-- =============================================================================
-- onboarding
-- =============================================================================

CREATE TABLE IF NOT EXISTS onboarding.tracks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  target_role  TEXT,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS onboarding.steps (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id    UUID NOT NULL REFERENCES onboarding.tracks(id) ON DELETE CASCADE,
  position    INT NOT NULL,
  title       TEXT NOT NULL,
  kind        TEXT NOT NULL
              CHECK (kind IN (
                'join_project', 'clone_repo', 'create_env', 'run_test',
                'read_doc', 'deploy_dev', 'custom'
              )),
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (track_id, position)
);

CREATE TABLE IF NOT EXISTS onboarding.user_tracks (
  user_id       UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  track_id      UUID NOT NULL REFERENCES onboarding.tracks(id) ON DELETE CASCADE,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at  TIMESTAMPTZ,
  PRIMARY KEY (user_id, track_id)
);

CREATE TABLE IF NOT EXISTS onboarding.user_steps (
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  step_id     UUID NOT NULL REFERENCES onboarding.steps(id) ON DELETE CASCADE,
  done        BOOLEAN NOT NULL DEFAULT FALSE,
  done_at     TIMESTAMPTZ,
  evidence    JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, step_id)
);

INSERT INTO onboarding.tracks (slug, name, target_role, description) VALUES
  ('ai-engineer', 'AI Engineer', 'AI Engineer',
   'Welcome path: join projects, clone, env, first Cyrex test, architecture, deploy')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO onboarding.steps (track_id, position, title, kind, payload)
SELECT t.id, s.position, s.title, s.kind, s.payload::jsonb
FROM onboarding.tracks t
CROSS JOIN (VALUES
  (1, 'Join required projects (Cyrex, Helox)', 'join_project',
   '{"project_slugs":["cyrex","helox"]}'),
  (2, 'Clone repositories', 'clone_repo',
   '{"project_slugs":["cyrex","helox"]}'),
  (3, 'Create development environment', 'create_env',
   '{"hint":"control-plane compose"}'),
  (4, 'Run first Cyrex test', 'run_test',
   '{"project_slug":"cyrex"}'),
  (5, 'Read architecture (Vizult graph)', 'read_doc',
   '{"tool_slug":"deepiri-vizult"}'),
  (6, 'Deploy / verify against cloud portal', 'deploy_dev',
   '{}')
) AS s(position, title, kind, payload)
WHERE t.slug = 'ai-engineer'
ON CONFLICT (track_id, position) DO NOTHING;

-- =============================================================================
-- vizult
-- =============================================================================

CREATE TABLE IF NOT EXISTS vizult.snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  scope           TEXT NOT NULL DEFAULT 'default',
  source_path     TEXT,
  format_version  TEXT,
  graph_json      JSONB,
  graph_uri       TEXT,
  stats           JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by      UUID REFERENCES identity.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT vizult_snapshots_payload_chk CHECK (graph_json IS NOT NULL OR graph_uri IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS vizult.nodes (
  snapshot_id  UUID NOT NULL REFERENCES vizult.snapshots(id) ON DELETE CASCADE,
  node_id      TEXT NOT NULL,
  label        TEXT,
  kind         TEXT,
  meta         JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (snapshot_id, node_id)
);

CREATE TABLE IF NOT EXISTS vizult.edges (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id  UUID NOT NULL REFERENCES vizult.snapshots(id) ON DELETE CASCADE,
  from_id      TEXT NOT NULL,
  to_id        TEXT NOT NULL,
  edge_kind    TEXT,
  confidence   REAL,
  meta         JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_vizult_edges_snapshot ON vizult.edges(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_vizult_snapshots_project ON vizult.snapshots(project_id, created_at DESC);

-- =============================================================================
-- integrations (Plaky — external-bridge-service)
-- =============================================================================

CREATE TABLE IF NOT EXISTS integrations.accounts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider         TEXT NOT NULL CHECK (provider IN ('plaky', 'github', 'other')),
  display_name     TEXT NOT NULL,
  credentials_ref  TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'disabled', 'error')),
  metadata         JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS integrations.plaky_boards (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id          UUID NOT NULL REFERENCES integrations.accounts(id) ON DELETE CASCADE,
  external_board_id   TEXT NOT NULL,
  name                TEXT NOT NULL,
  project_id          UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  meta                JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (account_id, external_board_id)
);

CREATE TABLE IF NOT EXISTS integrations.plaky_issues (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id                UUID NOT NULL REFERENCES integrations.plaky_boards(id) ON DELETE CASCADE,
  external_item_id        TEXT NOT NULL,
  title                   TEXT NOT NULL,
  status                  TEXT,
  priority                TEXT,
  assignee_external_ids   TEXT[] NOT NULL DEFAULT '{}',
  assignee_user_ids       UUID[] NOT NULL DEFAULT '{}',
  url                     TEXT,
  raw                     JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at_external     TIMESTAMPTZ,
  synced_at               TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (board_id, external_item_id)
);

CREATE TABLE IF NOT EXISTS integrations.plaky_sync_cursors (
  board_id          UUID PRIMARY KEY REFERENCES integrations.plaky_boards(id) ON DELETE CASCADE,
  cursor            TEXT,
  last_success_at   TIMESTAMPTZ,
  last_error        TEXT
);

CREATE TABLE IF NOT EXISTS integrations.plaky_issue_links (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id    UUID NOT NULL REFERENCES integrations.plaky_issues(id) ON DELETE CASCADE,
  project_id  UUID REFERENCES org.projects(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES identity.users(id) ON DELETE CASCADE,
  link_kind   TEXT NOT NULL DEFAULT 'related',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_plaky_issue_links
  ON integrations.plaky_issue_links (issue_id, link_kind, project_id, user_id)
  NULLS NOT DISTINCT;

CREATE INDEX IF NOT EXISTS idx_plaky_issues_board_status ON integrations.plaky_issues(board_id, status);
CREATE INDEX IF NOT EXISTS idx_plaky_issues_synced ON integrations.plaky_issues(synced_at DESC);
CREATE INDEX IF NOT EXISTS idx_plaky_issues_title_trgm ON integrations.plaky_issues USING gin (title gin_trgm_ops);

CREATE TABLE IF NOT EXISTS integrations.identity_maps (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider          TEXT NOT NULL,
  external_user_id  TEXT NOT NULL,
  user_id           UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  UNIQUE (provider, external_user_id)
);

DROP TRIGGER IF EXISTS trg_integrations_accounts_updated ON integrations.accounts;
CREATE TRIGGER trg_integrations_accounts_updated BEFORE UPDATE ON integrations.accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- jobs_meta
-- =============================================================================

CREATE TABLE IF NOT EXISTS jobs_meta.job_runs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type     TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'queued'
               CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
  payload      JSONB NOT NULL DEFAULT '{}'::jsonb,
  result       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by   UUID REFERENCES identity.users(id),
  started_at   TIMESTAMPTZ,
  finished_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_job_runs_type_status ON jobs_meta.job_runs(job_type, status);
CREATE INDEX IF NOT EXISTS idx_job_runs_created ON jobs_meta.job_runs(created_at DESC);

-- =============================================================================
-- Grants for app role (created by bootstrap shell if missing)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'deepiri_platform') THEN
    EXECUTE 'GRANT USAGE ON SCHEMA identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta, registry TO deepiri_platform';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta, registry TO deepiri_platform';
    EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta, registry TO deepiri_platform';
    EXECUTE 'ALTER DEFAULT PRIVILEGES IN SCHEMA identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta, registry GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO deepiri_platform';
  END IF;
END $$;
