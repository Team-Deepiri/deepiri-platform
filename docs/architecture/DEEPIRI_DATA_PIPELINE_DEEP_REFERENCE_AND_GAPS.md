# Deepiri Data Pipeline — Deep Reference & Gap Audit

> Companion to [DEEPIRI_DATA_PIPELINE_AUDIT.md](DEEPIRI_DATA_PIPELINE_AUDIT.md). Part A is the deep reference: full database schemas, every producer, and every wire payload. Part B is the gap audit with ranked recommendations.

---

# Part A — Deep Reference

## A1. PostgreSQL schemas

### A1.1 Language Intelligence Service (`deepiri_language_intelligence`, Prisma)

17 physical tables; 11 actively used. Key tables and columns:

| Table | Columns (type) | Notes |
|---|---|---|
| `unified_documents` | `id` uuid PK, `document_key` unique, `document_kind` string, `intelligence_profile` string, `profile_hints?` json, `document_url`, `document_storage_key?`, `raw_text?` text, `document_type`, `file_size?`, `status` enum, `processing_status?`, `processing_error?`, `processed_at?`, `processing_time_ms?`, `abstracted_terms` json, `financial_terms` json, `key_dates` json, `extracted_supplement?` json, `structured_segments?` json, `termination_details?` json, `renewal_details?` json, `extraction_confidence?`, `validation_score?`, `user_id?`, `organization_id?`, `tags` string[], `notes?`, `metadata` json, audit cols | primary modern ingestion table |
| `unified_document_versions` | FK → unified_documents, `version_number`, `document_url`, `raw_text`, `abstracted_terms`, `changes?`, `change_summary?`, `change_type?`, `significant_changes`, audit | unique `(intelligenceDocumentId, versionNumber)` |
| `leases` / `contracts` | business keys (`lease_number`/`contract_number` unique), parties, dates, `raw_text`, `abstracted_terms`/`key_clauses`/`financial_terms` (+`termination_terms`/`renewal_terms` for contracts) json, confidence/validation scores, org/user, tags, status enum | legacy-but-active flows |
| `lease_versions` / `contract_versions` | FK, `version_number`, snapshot fields, unique `(parent, version)` | |
| `clauses` | FK → contracts, `clause_type`, `clause_text`, `clause_summary?`, section/page, `version_number`, self-FK `previous_version_id` (evolution chain), `changes?`, `significant_change`, `confidence?` | |
| `obligations` | optional FKs to lease **or** contract **or** unified doc, `description`, `obligation_type` enum (15 values), `party`, `deadline?`, `frequency?`, `amount?`, `currency` default USD, `status` enum, owner fields | |
| `obligation_dependencies` | `source_obligation_id` + `target_obligation_id` FKs, `dependency_type` enum (`TRIGGERS, BLOCKS, MODIFIES, REQUIRES, PRECEDES, CONFLICTS`), trigger condition, both contract/lease role FKs, `verified`, unique pair | the dependency-graph edge table |
| `chat_sessions` / `messages` | session: user, context id/type (`CONTRACT|LEASE|REGULATORY_DOC`); message: FK, `role` (`user|assistant`), `content` | |
| `embeddings` | `chunk_id` FK, `model`, `dims`, `vector` **pgvector** + `vector_fallback` json | ⚠️ schema-only, never written by LIS code |
| `documents`, `document_chunks`, `analysis_jobs`, `analysis_results`, `prompt_templates` | generic analysis scaffolding | ⚠️ schema-only, unreferenced |

Enums: `LeaseStatus`/`ContractStatus`/`IntelligenceDocumentStatus` = `PENDING, PROCESSING, COMPLETED, ERROR, ARCHIVED`; `ObligationType` (15); `ObligationStatus`; `DependencyType` (6); `JobStatus`; `AnalysisType`.

### A1.2 Cyrex operational schema (`cyrex.*`, asyncpg)

Full DDL from `app/database/agent_tables.py`:

**`cyrex.agent_playground_messages`** — conversation history
- `message_id VARCHAR(255) PK`, `instance_id VARCHAR(255) NOT NULL`, `agent_id VARCHAR(255)`, `role VARCHAR(20) NOT NULL`, `content TEXT NOT NULL`, `tool_calls JSONB`, `is_error BOOL DEF false`, `metadata JSONB DEF {}`, `created_at TIMESTAMP DEF now()`
- idx: instance, agent, created_at

**`cyrex.workflows`** — workflow state
- `workflow_id VARCHAR(255) PK`, `name`, `description TEXT`, `workflow_type VARCHAR(100)`, `status VARCHAR(50) DEF 'pending'`, `current_step`, `total_steps INT DEF 0`, `completed_steps INT DEF 0`, `state_data JSONB DEF {}`, `step_results JSONB DEF {}`, `assigned_agents JSONB DEF []`, `checkpoints JSONB DEF []`, `error TEXT`, `error_count INT DEF 0`, `metadata JSONB`, `tags JSONB`, `created_at`, `updated_at`, `started_at?`, `completed_at?`, `deadline?`

**`cyrex.task_executions`**
- `execution_id PK`, `workflow_id FK→workflows ON DELETE SET NULL`, `agent_id`, `task_name NOT NULL`, `task_type`, `priority DEF 'normal'`, `status DEF 'pending'`, `input_data JSONB DEF {}`, `output_data JSONB`, `error`, `retry_count INT DEF 0`, `max_retries INT DEF 3`, `timeout_seconds INT DEF 300`, `execution_time_ms FLOAT`, timestamps

**`cyrex.events`** — audit log
- `event_id PK`, `event_type NOT NULL`, `entity_type`, `entity_id`, `workflow_id`, `agent_id`, `session_id`, `source DEF 'cyrex'`, `payload JSONB DEF {}`, `severity DEF 'info'`, `created_at`

**`cyrex.agent_metrics`** — sliding-window per-agent performance
- `id SERIAL PK`, `agent_id`, `role`, `recorded_at`, `window_start`, `window_end`, `total_invocations`, `success_count`, `error_count`, `guardrail_block_count`, `avg_duration_ms`, `p50/p95/p99_duration_ms`, `avg_confidence`, `tool_usage JSONB`

**`cyrex.spreadsheet_data`** — agent spreadsheet tool persistence
- `spreadsheet_id PK`, `user_id NOT NULL`, `instance_id`, `agent_name`, `columns JSONB DEF []`, `row_count INT DEF 20`, `data JSONB DEF {}`, timestamps

**`cyrex.document_parsing_templates`** — learned extraction templates
- `template_id PK`, `user_id NOT NULL`, `document_category NOT NULL`, `document_type`, `template_name`, `field_mappings JSONB`, `column_mappings JSONB`, `extraction_rules JSONB`, `correction_count`, `success_count`, `last_used_at`

**`cyrex.document_parsing_corrections`** — user corrections feeding template learning
- `correction_id PK`, `user_id NOT NULL`, `template_id FK ON DELETE SET NULL`, `document_category`, `original_extraction JSONB`, `corrected_data JSONB`, `correction_type` (`field_mapping|column_mapping|extraction_rule`), `correction_details JSONB`

Also in Cyrex land (SQLAlchemy, `SQL_URI` default `sqlite:///deepiri.db`): `TaskModel`, `ChallengeModel`, `UserPerformanceModel`. Long-term memory lives in a `memories` table via `MemoryManager` (Postgres).

### A1.3 Training samples mirror (`cyrex.helox_training_samples`) — canonical DDL

From `diri-helox/docs/HELOX_POSTGRES_MIRROR_CONTRACT.md` (Cyrex owns schema + write path):

```sql
CREATE TABLE IF NOT EXISTS cyrex.helox_training_samples (
    record_id      TEXT PRIMARY KEY,
    stream_type    TEXT NOT NULL CHECK (stream_type IN ('raw','structured')),
    producer       TEXT NOT NULL DEFAULT 'cyrex_realtime_pipeline',
    text           TEXT,                -- raw payload
    instruction    TEXT,                -- structured payload
    input_text     TEXT,
    output_text    TEXT,
    category       TEXT,
    quality_score  DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    metadata_json  JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- indexes: created_at DESC, stream_type, quality_score, producer
```

Contract rule: *every* publish to `pipeline.helox-training.raw/.structured` must also upsert here with matching `record_id` (Redis = low-latency source, Postgres = durable replay). **See gap G1 — Cyrex main implements this upsert; the platform submodule pin is stale and still lacks it.**

### A1.4 Dataset versioning (`dataset_versions`, SQLAlchemy)

Shared shape between dataset-processor and Helox migration `001_create_dataset_versions.sql`:

`id` PK · `dataset_name` (idx) · `version` · `dataset_type` · `storage_path` · `storage_backend` DEF `'s3'` · `total_samples` · `file_count` · `total_size_bytes` · `data_checksum` · `metadata_checksum` · `parent_version` · `change_summary` · `change_type` · `quality_score` · `validation_status` DEF `'PENDING'` · `validation_errors` JSON · `tags` JSON · `dataset_metadata` JSON · `created_at` · `created_by` · UNIQUE `(dataset_name, version, dataset_type)`

`DatasetType` taxonomy: `lease_abstraction`, `contract_intelligence`, `obligation_dependency`, `regulatory_language`, `clause_evolution`.
Filesystem fallback: `{metadata_dir}/{dataset_id}_version.json` + `dataset_lineage.json`.

### A1.5 PrismPipe stores

- Postgres: single KV table `prismpipe_kv (key TEXT PK, value JSONB, updated_at TIMESTAMPTZ)` + prefix index.
- SQLite document-operation store (`DocumentOperationRecord`): `operation_id`, `idempotency_key`, `request_fingerprint`, `document_id`, `manifest_version`, `capability`, `status` (`received→processing→succeeded|retryable_failure|terminal_failure|dead_lettered`), `attempt_count`, `claim_token`, `publication_state` (`none|pending|published`), outbound topic/message/payload.
- Redis: `prismpipe:` KV (TTL 86400), `prismpipe:cg:{capability}:{hash}` computation cache (per-capability TTL 15–30 s), `prismpipe:cg:sf:*` single-flight locks.
- Read-only memoization joins into `cyrex.pipeline_stage_inputs/outputs`, `cyrex.artifacts`, `cyrex.pipeline_run_stages` keyed by `(stage_name, input_hash)`.

### A1.6 Elkedel SQLite

- `artifacts/memory/elkedel.db`: **`traces`** (`centroid BLOB`, `strength`, `n_observations`, timestamps, `active`, `label`, `spatial JSON`, `history JSON`) + **`observations`** (append-only; idx on `trace_id`, `ts_ms`).
- `artifacts/sensory/elkedel_physical.db`: **`physical_observations`** (`obs_id`, `ts_ms`, `frame_id`, `novelty`, `depth_backend`, `dynamics_backend`, `stats JSON`, `snapshot BLOB` pickled float16 downsample).
- Stream artifact: `artifacts/sensory/stream.jsonl` — one JSON payload per line.

---

## A2. Redis Streams bus — topic matrix

Vocabulary duplicated across `shared-utils` (`StreamTopics`), `modelkit` (`StreamTopics`), `prismpipe` (`DeepiriStreamTopics`):

| Topic | Producers | Consumers |
|---|---|---|
| `platform-events` | LIS lifecycle events, backend services | messaging, realtime-gateway, Socket.IO fan-out |
| `ingestion-events` | LIS | analytics/audit consumers |
| `document.vectorize` | LIS routing publisher | PrismPipe `DocumentVectorizeNode` (idempotent processor) |
| `document.structured` / `document.training` / `document.artifacts` | LIS routing publisher | downstream route consumers |
| `pipeline.helox-training.raw` | Cyrex realtime pipeline Route 1 | Helox `StreamDataSource`/`CyrexTrainingStreamSource` |
| `pipeline.helox-training.structured` | Cyrex realtime pipeline Route 1 | Helox (same) |
| `training-jobs` | modelkit `TrainingJobQueue`, Cyrex agent-training service | Helox `TrainingJobWorker` |
| `training-events` | Helox/modelkit lifecycle publishers | platform monitoring |
| `model-events` | modelkit `ModelReadyEvent` etc. | Cyrex reload listener |
| `inference-events` | Cyrex orchestrator | monitoring/analytics |
| `agi-decisions` | Cyrex AGI decision layer | observability |
| `pipeline.pressure.events` / `pipeline.artifact.invalidation` / `pipeline.splice.events` | Cyrex artifact engine | PrismPipe/LIS side consumers |
| `pipeline.dead-letter` | Cyrex pipeline, PrismPipe ops store | ⚠️ no dedicated drainer (see G2) |
| `pipeline.metrics` | pipeline components | dashboards |
| `bedd.dlq` | Bedd redaction bus | — |

Retention: modelkit's `StreamingClient` publishes with `XADD maxlen 10000`; other clients do not trim consistently.

---

## A3. Producer catalog & exact payloads

### A3.1 Cyrex `PipelineRecord` → training streams (the flywheel intake)

Dataclass (`app/core/realtime_data_pipeline.py:98`): `record_id` uuid, `category` (enum), `route` (`HELOX|CYREX|BOTH`), `data_format` (`RAW|STRUCTURED`), `input_text`, `output_text`, `instruction`, `context`, `structured_payload?` dict, `schema_version` "1.0", `agent_id?`, `session_id?`, `user_id?`, `tool_name?`, `model_name?`, `quality_score?` 0–1, `execution_time_ms?`, `tags[]`, `metadata{}`, `timestamp`, processing state (`status`, `retry_count`, `max_retries=3`, `errors[]`), sha256-truncated `content_hash()` for dedup.

**Payload to `pipeline.helox-training.structured`** (`to_helox_training_format()`):
```json
{ "id": "...", "instruction": "...", "input": "...", "output": "...",
  "context": "...", "category": "agent_interaction", "data_format": "structured",
  "schema_version": "1.0", "agent_id": "...", "model_name": "...",
  "quality_score": 0.87, "tags": [], "timestamp": "ISO-8601",
  "structured_data": { } }
```
**Payload to `pipeline.helox-training.raw`** (`to_helox_raw_format()`):
```json
{ "id": "...", "text": "<built raw text>", "source": "cyrex.agent_interaction",
  "quality_score": 0.87, "timestamp": "ISO-8601" }
```
Validation rejects empty content and out-of-range quality; transform stage cleans text, redacts PII, enriches metadata (`has_structured_data`). Helox-side gate: `min_quality=0.4`.

### A3.2 Cyrex `TrainingDataStore` → CSV/JSONL files (`data/training/<kind>/`)

Four record kinds, each appended as CSV row + published to Synapse channel:

| Kind | Row fields (CSV header order) | Synapse channel |
|---|---|---|
| agent event | `event_id, event_type, agent_id, workflow_id, session_id, source, severity, timestamp, payload` | `training-data.agent_events` |
| agent task | `task_id, agent_id, instance_id, task_type, ...` | `training-data.agent_tasks` |
| tool execution | tool name, args/result summary, duration, success | `training-data.tool_executions` |
| workflow data | workflow id/type/steps/outcome | `training-data.workflows` |

### A3.3 Modelkit event contracts (`contracts/events.py`)

All extend `BaseEvent { event, timestamp, source, correlation_id? }`:

| Event | Fields |
|---|---|
| `ModelReadyEvent` → `model-events` | `model_name`, `version`, `registry_path` (S3/MLflow), `metadata{}`, `model_type?`, `accuracy?`, `size_mb?` |
| `ModelLoadedEvent` | `model_name`, `version`, `load_time_ms`, `cache_location?` |
| `InferenceEvent` → `inference-events` | `model_name`, `version`, `user_id?`, `request_id?`, `latency_ms`, `tokens_used?`, `cost?`, `confidence?`, `success=true` |
| `PlatformEvent` | `service`, `user_id?`, `action`, `data{}`, `organization_id?` |
| `AGIDecisionEvent` → `agi-decisions` | `decision_type`, `target_service?`, `action{}`, `reasoning?`, `confidence?` |
| `TrainingEvent` → `training-events` | `experiment_id`, `model_name`, `status`, `training_run_request_id?`, `progress?` 0–1, `metrics?{}`, `error?` |
| `PressureBusEvent` | `document_id`, `section_id`, `pressure_event_type`, `page?`, `artifact_id?`, `data{}` |
| `ArtifactInvalidationEvent` | `document_id`, `artifact_id?`, `reason`, `cascade=false`, `data{}` |
| `SpliceBusEvent` | `document_id`, `splice_id?`, `data{}` |

Training job message (`training/job_queue.py` on `training-jobs`): `TrainingRunRequest { experiment_id, model_name, fingerprint, dataset_manifest: DatasetManifest{id, version, path, content_hash, row_count, schema, produced_by, metadata}, priority: live|batch, hyperparameters{}, tags[] }`.

### A3.4 LIS event payloads (`src/streaming/eventPublisher.ts`)

Published to `platform-events` / `ingestion-events`: `document-created`, `document-processing-started`, `document-processed`, `document-version-created`, `document-processing-error`, `lease-created/processed`, `contract-created/processed`, `clause-evolution-tracked`, `dependency-graph-built`, obligation CRUD events, `document-ingestion-record`. Each carries `{event, timestamp, source, correlation_id?, documentId, documentKey, documentKind, intelligenceProfile, status, versionNumber?, processingTimeMs?, error?}` (flattened key/value pairs for XADD).

**Routing manifest** (`documentRoutePublisher.ts` → Sugar Glider `/v1/publish` or Redis XADD fallback) to `document.vectorize|.structured|.training|.artifacts`: `{ documentId, documentKey, documentKind, intelligenceProfile, versionNumber, storageKey, documentUrl, textFingerprint (sha256), schemaId ('unified.v1' | 'legacy.lease' | 'legacy.contract'), capabilities[], metadata.documentRouting outcome }`.

**Cyrex request bodies** (`cyrexClient.ts`): abstract pipelines send `{documentId, documentText, documentUrl, documentKey, versionNumber}` (+ profile hints); compare-versions sends both version texts; vector-store routes proxy to `/api/v1/documents/*` with collection enum `regulatory_documents, contracts, leases, obligations, clauses, compliance_patterns, version_drift, knowledge_base`.

### A3.5 Helox producers

- `ModelRegistrar` → MLflow registry + `ModelReadyEvent` (A3.3 shape) after evaluation.
- `DatasetVersionManager` → `dataset_versions` inserts (A1.4) on each versioned run.
- `TrainingJobWorker` consumes `training-jobs`, emits `TrainingEvent` lifecycle.
- DynamicTrainingPipeline writes split datasets (JSONL → HF `DatasetDict` with `text`/`label_id` features) and registers runs with dataset hash (SHA256 over file/dir incl. relative paths).

### A3.6 Elkedel payloads

`PhysicsTensor` wire form: JSON envelope `{ timestamp, frame_id, module: "elkedel.sensory_cortex", tensors: { flow, depth, normals, photometric, saliency } (float16+zlib+base64 data URIs), novelty_score }`. Memory trace: unit-sphere `(mu, R)` with leaky-integrator strength `R ← R·e^(−λ·dt)`; MCP tools `remember/where/what_changed/episode/forget/stats`.

---

# Part B — Gap Audit & Recommendations

Verdict up front: **the dataset processor needs targeted beefing-up (it is the weakest link for scale), the training orchestrator needs only small completions (it is intentionally minimal and mostly fine), and the biggest risks are pipeline-level (submodule-pin drift on the Helox mirror, DLQ drainage, topic-vocabulary drift).**

## B1. Ranked findings

| # | Severity | Area | Finding |
|---|---|---|---|
| G1 | **High** | Platform pin / Cyrex→Helox | Mirror contract requires upserting every streamed record into `cyrex.helox_training_samples`. **Cyrex `main` already implements the upsert** (Postgres durable path in `realtime_data_pipeline.py` / training emitter). The **platform submodule pin is older** than that commit, so a platform checkout still sees Redis-only capture — this is **submodule-pin staleness**, not an unresolved Cyrex gap. Bumping the pin restores the durable-replay promise. |
| G2 | **High** | Pipeline | `pipeline.dead-letter` and `bedd.dlq` have producers (Cyrex pipeline, PrismPipe ops store) but **no drainer/alerting consumer** anywhere. Poison records accumulate invisibly. |
| G3 | **High** | Dataset processor | Semantic dedup uses embedding cosine similarity with **optional LSH bucketing** (default on for corpora >50 rows) — not a pure O(n²) all-pairs scan. Still in-memory with no ANN index (no faiss/hnswlib), and loads whole corpora into memory — fine at ≤~50k rows; will not scale to real corpus sizes without chunked/streaming mode. |
| G4 | **Medium-High** | Dataset processor | `storage_backend="s3"` is the **default** in `dataset_versions` but raises `NotImplementedError` — only `local` works. Any consumer trusting the default fails at commit time. |
| G5 | **Medium** | Dataset processor | Quality checker **implements all 7 dimensions** (completeness, consistency, validity, uniqueness, timeliness, accuracy, integrity). The remaining gap is **silent/undisclosed skips** (e.g. accuracy returns no metrics when sample count is below the outlier threshold; some dimensions pass-with-assumption when columns are missing) — reports can overstate coverage without surfacing what was skipped. |
| G6 | **Medium** | Contracts | The 31-category label range (0–30) is hardcoded independently in **at least two verified places** (dataset-processor defaults and Helox `CATEGORY_MAP`; a synthetic generator path may duplicate it). Cyrex's BERT uses 50 abilities. No shared, enforced contract in modelkit. A drift here trains silently mislabeled models. |
| G7 | **Medium** | Shared vocabulary | Redis topic list is copy-pasted across shared-utils, modelkit, prismpipe. Already drifted once (prismpipe adds envelope-type mapping). One rename breaks consumers cross-repo with no CI guard. |
| G8 | **Medium** | Training orchestrator | Checkpoints are JSON `{step, metrics, fingerprint}` only — **no optimizer/model state**, so "resume" restarts weights from scratch; EarlyStopping sets a stop flag but never saves best weights (no best-checkpoint callback). |
| G9 | **Low-Medium** | LIS | pgvector extension + `embeddings` table provisioned but never written; plus 6 schema-only models (`documents`, `document_chunks`, `analysis_jobs`, `analysis_results`, `prompt_templates`). Dead schema invites confusion about where vectors live (answer: Milvus via Cyrex). |
| G10 | **Low-Medium** | Platform | `platform-services/shared/deepiri-prismpipe/` submodule is populated and pinned to a real commit; a checkout without `git submodule update --init` shows it as empty, which is easy to mistake for a broken/unwired submodule. Onboarding docs should call out the init step explicitly. |
| G11 | **Low-Medium** | LIS | Standalone repo vs platform submodule pin have diverged (standalone has unified-document ingestion, chat, obligations; submodule pin older). Consumers get different behavior depending on entry path. |
| G12 | **Low** | Capture quality | Auto-capture forwards everything to `helox-training.raw` with no confidence threshold at the producer; the only gate is Helox-side `min_quality=0.4`. Low-value interactions still consume stream capacity and pollute raw pre-training pools. |
| G13 | **Low** | Retention | modelkit trims streams at `maxlen 10000`; other publishers don't trim. Unbounded streams on long-lived Redis are a memory risk; inconsistent retention makes replay semantics unclear. |
| G14 | **Low** | Elkedel | Silent degradation: if DINOv2/torch missing, embedder falls back to a deterministic synthetic hash — memories still work but semantics are meaningless, with (at most) quiet logging. |
| G15 | **Low** | Testing | No end-to-end test exercises document → LIS → Cyrex → capture → Helox → MLflow → ModelReady → Cyrex reload. Each hop has unit tests; the flywheel itself is untested. |

## B2. Does the dataset processor need beefing up? — Yes, specifically:

1. **Scale path for dedup**: LSH bucketing already reduces pairwise work; add an ANN option (`hnswlib`/`faiss` extra) behind the existing `.encode()` injection point, and a chunked/streaming reader for JSONL larger than memory. Keep zero-dep core; put scale in extras like today.
2. **Fix the S3 default**: either implement the S3 backend (boto3 is already all over the platform) or flip the default to `local` and log loudly. One-line-class fix, high footgun removal.
3. **Disclose quality-checker skips**: all 7 dimensions are implemented — surface skipped/assumed dimensions explicitly in the report (and/or require columns) so scores aren't quietly overstated.
4. **Make the label contract explicit**: move `label_id` range + mapping validation into a modelkit contract (shared with Helox `CATEGORY_MAP`) instead of independent hardcoded copies.
5. **Optional**: pluggable PII detection hook (Bedd/presidio adapters) so cleaning-stage outputs are privacy-safe by construction rather than relying on upstream LIS Bedd or Cyrex transform-stage redaction.

## B3. Does the training orchestrator need beefing up? — Only small completions:

Its minimalism is a feature (framework-agnostic `train_step` + callbacks). Worth adding:

1. **Stateful checkpoints**: optional `save_state_fn/load_state_fn` hooks so `CheckpointCallback` can persist optimizer/model blobs (to MinIO/local) alongside the JSON metrics — completes the resume story.
2. **Best-checkpoint callback**: track best monitored metric, save marker + fingerprint, expose in `TrainingContext` — pairs with EarlyStopping.
3. **Tracking deps (current state)**: `wandb` is already an optional Poetry extra (`[tool.poetry.extras] wandb` / `full`). Legacy **DVC support was removed** (dataset versioning now goes through deepiri-dataset-processor); do not document DVC as an undeclared soft-import.
4. **Async eval support**: allow `eval_fn` to return an awaitable (Helox pipelines are increasingly async).
Skip: distributed training (correctly delegated to accelerate/DeepSpeed in Helox), schedulers (out of scope).

## B4. Pipeline-level recommendations (highest leverage first)

1. **Close G1 via pin bump**: fast-forward the platform `diri-cyrex` submodule to a revision that includes the `helox_training_samples` upsert (already on Cyrex `main`) + keep a reconciliation job that diffs Redis vs Postgres counts per day. Add a contract test so the pin can't regress silently behind Cyrex.
2. **Stand up a DLQ drainer (G2)**: one small consumer service (PrismPipe node or Helox worker) that reads `pipeline.dead-letter` + `bedd.dlq`, persists to a table, counts by reason, and alerts on growth. Dead letters are training-data loss.
3. **Single-source the stream topics (G7)**: make modelkit's `StreamTopics` the canonical package; shared-utils/prismpipe re-export or generate from it; add a CI check that fails on vocabulary diff. Cheapest possible fix for a whole class of silent breakage.
4. **Producer-side quality gate (G12)**: reuse the existing `quality_score` field — skip capture below ~0.3 at `capture_interaction` time (configurable), keeping the raw stream clean without changing Helox.
5. **Uniform stream retention (G13)**: standardize `XADD maxlen` (10k is reasonable) in shared-utils' `StreamingClient` and use it everywhere.
6. **Retire dead schema / clarify onboarding (G9/G10)**: drop unused LIS models in the next major Prisma migration (or annotate them "reserved"); add a note to onboarding docs that the prismpipe submodule requires `git submodule update --init` before it appears populated.
7. **Pin LIS divergence (G11)**: bump the platform submodule to the standalone repo's revision and add a CI drift check between the two checkouts.
8. **One flywheel e2e test (G15)**: a nightly compose-profile test that uploads a fixture document through the gateway and asserts a `ModelReadyEvent` within N minutes. This single test guards the entire product story.

## B5. What is already good (keep as-is)

- Clean runtime/training plane separation with explicit contracts (modelkit) and a documented mirror contract.
- Dedup-by-content-hash at capture (`PipelineRecord.content_hash`) and PrismPipe computation-graph memoization — both prevent duplicate training/compute spend.
- Idempotent, claim-tokened `document.vectorize` processing with publication states — correct at-least-once design.
- Reproducibility discipline (seeds, fingerprints, dataset hashes) is genuinely rare at this stage and worth protecting.
- Elkedel's dependency minimalism (numpy core, extras for vision/sensory/depth) is the right shape — just fix the silent-fallback logging (G14).
