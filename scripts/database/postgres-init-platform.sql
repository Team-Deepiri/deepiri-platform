-- =============================================================================
-- Deepiri CLOUD: postgres-platform
-- Target DB name: platform
-- Schemas: identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta
-- NO Cyrex / NO language-intelligence tables here.
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

CREATE TABLE identity.users (
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
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT users_email_norm_unique UNIQUE (email_norm)
);

CREATE TABLE identity.roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  is_system   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE identity.user_roles (
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role_id     UUID NOT NULL REFERENCES identity.roles(id) ON DELETE CASCADE,
  granted_by  UUID REFERENCES identity.users(id),
  granted_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMPTZ,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE identity.sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  token_hash    TEXT NOT NULL UNIQUE,
  ip_address    INET,
  user_agent    TEXT,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE identity.api_keys (
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

CREATE TABLE identity.invites (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT NOT NULL,
  role_hint     TEXT,
  token_hash    TEXT NOT NULL UNIQUE,
  invited_by    UUID REFERENCES identity.users(id),
  accepted_at   TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_user ON identity.sessions(user_id);
CREATE INDEX idx_api_keys_user ON identity.api_keys(user_id);

INSERT INTO identity.roles (name, description, is_system) VALUES
  ('admin', 'Full portal administrator', TRUE),
  ('member', 'Standard Deepiri member', TRUE),
  ('guest', 'Limited invite access', TRUE)
ON CONFLICT (name) DO NOTHING;

DROP TRIGGER IF EXISTS trg_users_updated ON identity.users;
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON identity.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- org  (My Deepiri / project assignment)
-- =============================================================================

CREATE TABLE org.teams (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE org.team_members (
  team_id     UUID NOT NULL REFERENCES org.teams(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'member'
              CHECK (role IN ('owner', 'admin', 'member')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (team_id, user_id)
);

CREATE TABLE org.projects (
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
  metadata    JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE org.project_members (
  project_id  UUID NOT NULL REFERENCES org.projects(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'contributor'
              CHECK (role IN ('lead', 'contributor', 'viewer')),
  assigned_by UUID REFERENCES identity.users(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (project_id, user_id)
);

CREATE TABLE org.project_teams (
  project_id  UUID NOT NULL REFERENCES org.projects(id) ON DELETE CASCADE,
  team_id     UUID NOT NULL REFERENCES org.teams(id) ON DELETE CASCADE,
  PRIMARY KEY (project_id, team_id)
);

CREATE INDEX idx_project_members_user ON org.project_members(user_id);

DROP TRIGGER IF EXISTS trg_projects_updated ON org.projects;
CREATE TRIGGER trg_projects_updated BEFORE UPDATE ON org.projects
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- portal  (announcements / events)
-- =============================================================================

CREATE TABLE portal.announcements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  body_md       TEXT NOT NULL,
  author_id     UUID REFERENCES identity.users(id),
  pinned        BOOLEAN NOT NULL DEFAULT FALSE,
  published_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE portal.events (
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

CREATE TABLE portal.event_rsvps (
  event_id    UUID NOT NULL REFERENCES portal.events(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  status      TEXT NOT NULL CHECK (status IN ('going', 'maybe', 'no')),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id, user_id)
);

CREATE INDEX idx_events_starts ON portal.events(starts_at DESC);
CREATE INDEX idx_announcements_published ON portal.announcements(published_at DESC NULLS LAST);

-- =============================================================================
-- catalog  (tools install grid + artifacts + run records)
-- =============================================================================

CREATE TABLE catalog.tools (
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
  metadata      JSONB NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE catalog.project_tools (
  project_id  UUID NOT NULL REFERENCES org.projects(id) ON DELETE CASCADE,
  tool_id     UUID NOT NULL REFERENCES catalog.tools(id) ON DELETE CASCADE,
  PRIMARY KEY (project_id, tool_id)
);

CREATE TABLE catalog.artifacts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  tool_id     UUID REFERENCES catalog.tools(id) ON DELETE SET NULL,
  title       TEXT NOT NULL,
  type        TEXT NOT NULL
              CHECK (type IN ('dataset', 'doc', 'recording', 'other')),
  uri         TEXT NOT NULL,
  owner_id    UUID REFERENCES identity.users(id),
  meta        JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE catalog.run_records (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id     UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  tool_id        UUID REFERENCES catalog.tools(id) ON DELETE SET NULL,
  git_sha        TEXT,
  status         TEXT NOT NULL DEFAULT 'unknown'
                 CHECK (status IN ('pending', 'running', 'passed', 'failed', 'unknown')),
  summary        JSONB NOT NULL DEFAULT '{}',
  artifact_uris  TEXT[] NOT NULL DEFAULT '{}',
  created_by     UUID REFERENCES identity.users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tools_published ON catalog.tools(published, sort_order);
CREATE INDEX idx_artifacts_project ON catalog.artifacts(project_id);
CREATE INDEX idx_run_records_project ON catalog.run_records(project_id, created_at DESC);

-- Seed a few tools (extend to full 25 in a seed migration)
INSERT INTO catalog.tools (slug, name, summary, install_kind, categories, repo_url, sort_order) VALUES
  ('cyrex', 'Cyrex', 'Cyrex agentic runtime framework.', 'cli', ARRAY['CLI','Platform','AI/ML'], NULL, 10),
  ('helox', 'Helox', 'Model fine-tuning and model versioning framework.', 'cli', ARRAY['CLI','Platform','AI/ML'], NULL, 20),
  ('zepgpu', 'ZepGPU', 'GPU detection, scheduling, and acceleration utilities.', 'cli', ARRAY['CLI','Infrastructure'], NULL, 30),
  ('deepiri-platform', 'Deepiri Platform', 'Main Deepiri platform / portal stack.', 'platform', ARRAY['CLI','Platform','Infrastructure'], NULL, 40)
ON CONFLICT (slug) DO NOTHING;

-- =============================================================================
-- onboarding
-- =============================================================================

CREATE TABLE onboarding.tracks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  target_role  TEXT,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE onboarding.steps (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id    UUID NOT NULL REFERENCES onboarding.tracks(id) ON DELETE CASCADE,
  position    INT NOT NULL,
  title       TEXT NOT NULL,
  kind        TEXT NOT NULL
              CHECK (kind IN (
                'join_project', 'clone_repo', 'create_env', 'run_test',
                'read_doc', 'deploy_dev', 'custom'
              )),
  payload     JSONB NOT NULL DEFAULT '{}',
  UNIQUE (track_id, position)
);

CREATE TABLE onboarding.user_tracks (
  user_id       UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  track_id      UUID NOT NULL REFERENCES onboarding.tracks(id) ON DELETE CASCADE,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at  TIMESTAMPTZ,
  PRIMARY KEY (user_id, track_id)
);

CREATE TABLE onboarding.user_steps (
  user_id     UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  step_id     UUID NOT NULL REFERENCES onboarding.steps(id) ON DELETE CASCADE,
  done        BOOLEAN NOT NULL DEFAULT FALSE,
  done_at     TIMESTAMPTZ,
  evidence    JSONB NOT NULL DEFAULT '{}',
  PRIMARY KEY (user_id, step_id)
);

INSERT INTO onboarding.tracks (slug, name, target_role, description) VALUES
  ('ai-engineer', 'AI Engineer', 'AI Engineer', 'Join Cyrex/Helox, clone, env, first test, architecture, deploy')
ON CONFLICT (slug) DO NOTHING;

-- =============================================================================
-- vizult  (graphs produced by deepiri-vizult CLI on the VM)
-- =============================================================================

CREATE TABLE vizult.snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  scope           TEXT NOT NULL DEFAULT 'default',
  source_path     TEXT,
  format_version  TEXT,
  graph_json      JSONB,
  graph_uri       TEXT,
  stats           JSONB NOT NULL DEFAULT '{}',
  created_by      UUID REFERENCES identity.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (graph_json IS NOT NULL OR graph_uri IS NOT NULL)
);

CREATE TABLE vizult.nodes (
  snapshot_id  UUID NOT NULL REFERENCES vizult.snapshots(id) ON DELETE CASCADE,
  node_id      TEXT NOT NULL,
  label        TEXT,
  kind         TEXT,
  meta         JSONB NOT NULL DEFAULT '{}',
  PRIMARY KEY (snapshot_id, node_id)
);

CREATE TABLE vizult.edges (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id  UUID NOT NULL REFERENCES vizult.snapshots(id) ON DELETE CASCADE,
  from_id      TEXT NOT NULL,
  to_id        TEXT NOT NULL,
  edge_kind    TEXT,
  confidence   REAL,
  meta         JSONB NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_vizult_edges_snapshot ON vizult.edges(snapshot_id);
CREATE INDEX idx_vizult_snapshots_project ON vizult.snapshots(project_id, created_at DESC);

-- =============================================================================
-- integrations  (Plaky — owned by external-bridge-service)
-- =============================================================================

CREATE TABLE integrations.accounts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider         TEXT NOT NULL CHECK (provider IN ('plaky', 'github', 'other')),
  display_name     TEXT NOT NULL,
  credentials_ref  TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'disabled', 'error')),
  metadata         JSONB NOT NULL DEFAULT '{}',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE integrations.plaky_boards (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id          UUID NOT NULL REFERENCES integrations.accounts(id) ON DELETE CASCADE,
  external_board_id   TEXT NOT NULL,
  name                TEXT NOT NULL,
  project_id          UUID REFERENCES org.projects(id) ON DELETE SET NULL,
  meta                JSONB NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (account_id, external_board_id)
);

CREATE TABLE integrations.plaky_issues (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id                UUID NOT NULL REFERENCES integrations.plaky_boards(id) ON DELETE CASCADE,
  external_item_id        TEXT NOT NULL,
  title                   TEXT NOT NULL,
  status                  TEXT,
  priority                TEXT,
  assignee_external_ids   TEXT[] NOT NULL DEFAULT '{}',
  assignee_user_ids       UUID[] NOT NULL DEFAULT '{}',
  url                     TEXT,
  raw                     JSONB NOT NULL DEFAULT '{}',
  updated_at_external     TIMESTAMPTZ,
  synced_at               TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (board_id, external_item_id)
);

CREATE TABLE integrations.plaky_sync_cursors (
  board_id          UUID PRIMARY KEY REFERENCES integrations.plaky_boards(id) ON DELETE CASCADE,
  cursor            TEXT,
  last_success_at   TIMESTAMPTZ,
  last_error        TEXT
);

CREATE TABLE integrations.plaky_issue_links (
  issue_id    UUID NOT NULL REFERENCES integrations.plaky_issues(id) ON DELETE CASCADE,
  project_id  UUID REFERENCES org.projects(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES identity.users(id) ON DELETE CASCADE,
  link_kind   TEXT NOT NULL DEFAULT 'related',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (issue_id, link_kind, COALESCE(project_id, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::uuid))
);

CREATE INDEX idx_plaky_issues_board_status ON integrations.plaky_issues(board_id, status);
CREATE INDEX idx_plaky_issues_synced ON integrations.plaky_issues(synced_at DESC);

-- User email ↔ Plaky assignee mapping helper
CREATE TABLE integrations.identity_maps (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider          TEXT NOT NULL,
  external_user_id  TEXT NOT NULL,
  user_id           UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
  UNIQUE (provider, external_user_id)
);

-- =============================================================================
-- jobs_meta  (optional bookkeeping for cloud jobs service)
-- =============================================================================

CREATE TABLE jobs_meta.job_runs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type     TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'queued'
               CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
  payload      JSONB NOT NULL DEFAULT '{}',
  result       JSONB NOT NULL DEFAULT '{}',
  created_by   UUID REFERENCES identity.users(id),
  started_at   TIMESTAMPTZ,
  finished_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_job_runs_type_status ON jobs_meta.job_runs(job_type, status);

-- =============================================================================
-- Grants placeholder (adjust role names in compose)
-- =============================================================================
-- GRANT USAGE ON SCHEMA identity, org, portal, catalog, onboarding, vizult, integrations, jobs_meta TO deepiri_platform;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ... TO deepiri_platform;
