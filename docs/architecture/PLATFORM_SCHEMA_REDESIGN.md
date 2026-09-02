# Platform (`postgres-platform`) schema redesign

Fits the cloud goal: **internal Deepiri portal** — people, projects, tools catalog, onboarding, “My Deepiri”, events/announcements, artifacts/runs, **vizult graphs**, **Plaky issues**.

No Cyrex/LIS schemas here. No `hub-api`. Cloud API front door = **`api-gateway`**.

Related: `DATABASES_AND_COMPOSE_BY_PLANE.md`.

---

## 1. Cloud services that own this data

| Service | Owns / writes |
|---------|----------------|
| `auth-service` | `identity.*` |
| `api-gateway` | routes only — **no** Plaky business logic |
| `jobs` | onboarding automation, vizult scan jobs, sync triggers |
| `registry` | tool/package catalog pointers (optional cache of install metadata) |
| **`external-bridge-service`** (cloud) | **Plaky** (and later GitHub) sync — **not** the gateway |
| `platform-frontend` | UI only |
| **`deepiri-vizult`** (CLI on VM, not a long-running DB owner) | produces `graph.json` → jobs/bridge ingest into `vizult.*` |

**Plaky decision:** handle in **`external-bridge-service`** (integrations worker).  
`api-gateway` only exposes `/api/integrations/plaky/*` → bridge.  
Do **not** put Plaky tokens/polling inside the gateway. Bridge already exists for webhooks/integrations; extend it. On cloud, run bridge **without Kafka** if needed (HTTP poll + DB queue) so you don’t drag Kafka onto the VPS.

**Vizult on the VM:** yes — clone/install `deepiri-vizult` on the box (or in a one-shot job container). It stays a **scanner CLI**, not a microservice with its own Postgres. Output lands in `postgres-platform`.

---

## 2. Logical layout inside `postgres-platform`

One container, one database `platform` (name TBD), **schemas**:

| Schema | Purpose |
|--------|---------|
| `identity` | users, sessions, roles, invites, API keys |
| `org` | teams, projects, membership, ownership, roles-on-project |
| `portal` | announcements, events, RSVPs |
| `catalog` | tools (the 25 installables), artifacts, run_records |
| `onboarding` | tracks, steps, per-user progress |
| `vizult` | stored architecture graphs + node/edge snapshots |
| `integrations` | Plaky (and later GH) sync state + mirrored issues |
| `jobs_meta` | optional job run metadata if jobs service needs PG |

Drop old gamification seasons/quests from *cloud* SoT unless you explicitly still want them — they don’t match this portal goal.

---

## 3. Schema details (v1)

### `identity` (from auth, cleaned)

```text
users              id, email, name, avatar_url, status, email_verified, last_login_at, metadata, created_at, updated_at
roles              id, name, description, is_system
user_roles         user_id, role_id, granted_by, expires_at
sessions           id, user_id, token_hash, expires_at, ip, user_agent
api_keys           id, user_id, name, key_hash, scopes[], expires_at, last_used_at
invites            id, email, role_hint, token_hash, invited_by, accepted_at, expires_at
```

Portal roles examples: `admin`, `member`, `guest`.

---

### `org` — “My Deepiri” + assign projects

```text
teams              id, slug, name, description
team_members       team_id, user_id, role  -- owner|admin|member

projects           id, slug, name, description, kind, repo_url, status, metadata
                   -- kind: product|lib|infra|research|tool
project_members    project_id, user_id, role  -- lead|contributor|viewer
project_teams      project_id, team_id        -- optional team ownership

-- Optional links from a portal "tool" to a project
project_tools      project_id, tool_id
```

**My Deepiri** = `project_members` (+ teams) for the logged-in user.  
Admins **assign** via `project_members` inserts (UI + API through gateway → small org handlers in auth or a thin org module; can live in auth-service or jobs/registry — prefer **auth-service extended** or a tiny `org` route module behind gateway reading `org.*`).

Practical v1: **auth-service** owns `identity` + `org` membership tables (one service, one DB). Keep it simple.

---

### `portal` — off Discord

```text
announcements      id, title, body_md, author_id, pinned, published_at, created_at
events             id, title, kind, starts_at, ends_at, location_url, description_md, created_by
                   -- kind: meeting|demo|hackathon|research_talk|other
event_rsvps        event_id, user_id, status  -- going|maybe|no
```

---

### `catalog` — tools site + shared files/runs

```text
tools              id, slug, name, summary, install_kind, categories[],
                   install_url, docs_url, repo_url, logo_url, sort_order, published
                   -- install_kind: cli|desktop|cli_desktop|platform
                   -- mirrors deepiri.com/tools cards (Cyrex, Helox, ZepGPU, …)

artifacts          id, project_id?, tool_id?, title, type, uri, owner_id, meta, created_at
                   -- type: dataset|doc|recording|other
                   -- uri: Drive/S3/HF/Git — pointers only

run_records        id, project_id, tool_id?, git_sha, status, summary jsonb,
                   artifact_uris[], created_by, created_at
```

Seed `tools` from the public tools list (25 rows). Portal “Install Deepiri Tools” reads `catalog.tools`.

---

### `onboarding`

```text
onboarding_tracks     id, slug, name, target_role  -- e.g. ai_engineer
onboarding_steps      id, track_id, position, title, kind, payload jsonb
                      -- kind: join_project|clone_repo|create_env|run_test|read_doc|deploy_dev|custom
                      -- payload: { project_slug?, repo_url?, doc_url?, job_name? }

user_onboarding       user_id, track_id, started_at, completed_at
user_onboarding_steps user_id, step_id, done, done_at, evidence jsonb
```

Example track “AI Engineer”: join Cyrex+Helox → clone → env → first Cyrex test → read architecture → deploy to dev.  
**jobs** can mark steps done when a job succeeds (e.g. “run first Cyrex test” locally reported via API, or cloud smoke job).

---

### `vizult` — dependency graphs in the portal

Vizult remains local-first CLI; cloud **stores scan results** for the UI.

```text
vizult_snapshots     id, project_id?, scope, source_path, created_by, created_at,
                     graph_json jsonb,  -- full graph.json (or S3 uri if huge)
                     format_version, stats jsonb

vizult_nodes         snapshot_id, node_id, label, kind, meta jsonb
vizult_edges         snapshot_id, from_id, to_id, edge_kind, confidence, meta jsonb
```

**VM integration:**

1. Clone `deepiri-vizult` onto the cloud VM (or bake into a `jobs` runner image).  
2. `jobs` schedule / manual: `vizult scan <repos> --siblings-scan` → write `vizult-output/graph.json`.  
3. Ingest job upserts `vizult_snapshots` (+ optional normalized nodes/edges for query).  
4. `platform-frontend` renders interactive graph (Cytoscape — vizult already emits HTML/JSON).

You do **not** need a permanent “vizult microservice.” Optional: sidecar container `vizult-runner` used only by jobs.

---

### `integrations` — Plaky (and friends)

```text
integration_accounts  id, provider, display_name, credentials_ref,  -- vault/env ref, not raw in UI
                      status, created_at
                      -- provider: plaky|github|…

plaky_boards          id, account_id, external_board_id, name, project_id?, meta

plaky_issues          id, board_id, external_item_id, title, status, priority,
                      assignee_external_ids[], assignee_user_ids uuid[],  -- mapped when possible
                      url, raw jsonb, updated_at_external, synced_at

plaky_sync_cursors    board_id, cursor, last_success_at, last_error

-- optional link issue ↔ portal project/onboarding
plaky_issue_links     issue_id, project_id?, user_id?, link_kind
```

**Who runs sync:** `external-bridge-service`  
- Poll Plaky API and/or webhooks → upsert `plaky_issues`  
- `api-gateway` GET `/api/plaky/issues?project=` → reads DB via bridge or shared read API  

Map Plaky assignees → `identity.users` when emails match.

---

## 4. What we are *not* putting in `postgres-platform`

| Data | Where it stays |
|------|----------------|
| Cyrex AGI tables | `postgres-cyrex-db` |
| LIS documents / intel | `cp_intel` on control plane |
| Helox | no DB |
| Milvus vectors / MinIO blobs for AI | control plane / Cyrex |
| Discord messages | Discord |

---

## 5. Cloud compose add-ons for this goal

Already on cloud: `postgres-platform`, `redis`, `auth-service`, `api-gateway`, `jobs`, `registry`, `platform-frontend`, nginx/certbot/backup.

**Add for this redesign:**

| Service | Why |
|---------|-----|
| `external-bridge-service` | Plaky sync (cloud config, **no Kafka** if possible) |
| `vizult` usage via **jobs** (image or host clone) | Scan → ingest graphs |

---

## 6. API surface (gateway routes → owners)

| Route | Service |
|-------|---------|
| `/api/auth/*` | auth-service |
| `/api/me`, `/api/me/projects` | auth-service (org membership) |
| `/api/projects/*`, `/api/teams/*` | auth-service (org) |
| `/api/announcements/*`, `/api/events/*` | auth-service or small portal module |
| `/api/tools/*` | registry (catalog) or auth portal module |
| `/api/artifacts/*`, `/api/runs/*` | registry or jobs |
| `/api/onboarding/*` | auth-service + jobs callbacks |
| `/api/vizult/snapshots/*` | jobs (write) + read API |
| `/api/plaky/*` | **external-bridge-service** |
| `/api/jobs/*` | jobs |

---

## 7. Migration stance from old auth/core/intelligence

| Old | Action |
|-----|--------|
| `users` / roles / sessions | Move → `identity.*` on `postgres-platform` |
| `projects` in core (if useful) | Rehome → `org.projects` (new columns: kind, repo_url) |
| seasons / gamification / chat tables | **Do not** bring to cloud SoT unless still required |
| intelligence / LIS DDL | Control plane `cp_intel` only |
| New tables | onboarding, tools, vizult_*, plaky_*, artifacts, run_records, announcements |

Greenfield migrations preferred for cloud; one-time user export optional.

---

## 8. Success criteria

- [ ] New join → onboarding track with assignable projects (Cyrex/Helox/…)  
- [ ] “My Deepiri” shows assigned projects  
- [ ] Tools page lists installable Deepiri tools from DB  
- [ ] Vizult scan on VM lands in portal dependency graph UI  
- [ ] Plaky issues visible in portal via **external-bridge**, not gateway guts  
- [ ] Zero Cyrex/LIS tables on `postgres-platform`

---

## 9. Picture

```
platform-frontend
       │
  api-gateway
       ├── auth-service ──────── identity + org + portal + onboarding
       ├── jobs ──────────────── vizult scan ingest, onboarding hooks
       ├── registry ──────────── tools catalog (optional artifacts)
       └── external-bridge ───── Plaky sync → integrations.*

postgres-platform
  identity | org | portal | catalog | onboarding | vizult | integrations

[VM] deepiri-vizult CLI ──(jobs)──▶ vizult.snapshots
```
