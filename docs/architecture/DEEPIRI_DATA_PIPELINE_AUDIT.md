# Deepiri Data Pipeline Audit

> Full inventory of every data library and tool, the end-to-end pipeline, the types of data Deepiri moves, and how each store maps to the system.
>
> Audit performed against the following repos (as of Aug 2026):
> `deepiri-platform`, `deepiri-language-intelligence-service`, `deepiri-shared-utils`, `deepiri-dataset-processor`, `diri-cyrex`, `deepiri-prismpipe`, `deepiri-modelkit`, `diri-helox`, `deepiri-training-orchestrator`, `deepiri-elkedel`.

---

## 0. One picture

Deepiri is a **gamified productivity platform** with an **AI/ML training-to-inference flywheel** on top. There are two data planes:

1. **Runtime plane** — the user-facing microservices (gateway → auth → engagement → language-intelligence → PrismPipe → Cyrex) and their stores (PostgreSQL, Redis, Milvus, InfluxDB, MinIO/S3).
2. **Training plane** — "the factory": raw interaction/training data is captured from runtime, cleaned/versioned by `deepiri-dataset-processor`, trained by `diri-helox` driven by `deepiri-training-orchestrator`, registered via `deepiri-modelkit`, and consumed back at runtime by Cyrex.

The contract glue that connects the two planes is the **Redis Stream bus** (shared topic vocabulary in `deepiri-shared-utils`, `deepiri-modelkit`, and `deepiri-prismpipe`) plus the **MLflow model registry**.

```
                  RUNTIME PLANE (serves users, gathers signal)
 ┌────────────────────────────────────────────────────────────────────────┐
 │  deepiri-web-frontend (:5173)                                          │
 │        │                                                               │
 │  deepiri-api-gateway (:5100)  ── auth (:5001), external-bridge (:5006) │
 │        │                                                               │
 │  ┌─────┴───────────────┬───────────────────────────────┐               │
 │  │ deepiri-language-   │  deepiri-prismpipe (:5011)     │               │
 │  │ intelligence (:5010)│  capability-routed pipeline    │               │
 │  │ document→LLM        │  (auth→LIS→cyrex→aggregate)    │               │
 │  └─────┬───────────────┴───────────────┬───────────────┘               │
 │        │ documents, obligations        │ RequestEnvelopes              │
 │        ▼                               ▼                               │
 │  diri-cyrex (:8000)  AGI agent — LLM orchestration, tools, RAG, memory │
 │        │                                                               │
 │  stores: PostgreSQL, Redis, Milvus, InfluxDB, MinIO/S3, MLflow         │
 └────────┼───────────────────────────────────────────────────────────────┘
          │  auto-capture: every agent interaction / tool result
          ▼
                  TRAINING PLANE (factory)
 ┌────────────────────────────────────────────────────────────────────────┐
 │  Redis Streams (pipeline.helox-training.raw/.structured, training-jobs)│
 │        │                                                               │
 │  deepiri-dataset-processor   clean → dedup → leakage → quality → version│
 │        │                                                               │
 │  deepiri-training-orchestrator  seeds, fingerprint, MLflow, callbacks   │
 │        │                                                               │
 │  diri-helox   DynamicTrainingPipeline / LoRA / DeepSpeed / RAG         │
 │        │                                                               │
 │  deepiri-modelkit  registry (MLflow/S3) → ModelReadyEvent → Redis      │
 │        ▼                                                               │
 │  diri-cyrex downloads model → serves inference (closes the loop)       │
 └────────────────────────────────────────────────────────────────────────┘
```

Peripheral: `deepiri-elkedel` (Cyrex's "eyes") is a sensory/perception sidecar that streams physics tensors + episodic visual memory to ground Cyrex in the physical world.

---

## 1. deepiri-platform (umbrella)

**Role:** monorepo + submodule aggregator, Docker Compose dev stack, K8s/Skaffold deploy, team environments.

**Services hosted (ports):** API Gateway (5100), Auth (5001), Task Orchestrator (5002), Engagement (5003), Platform Analytics (5004), Notification (5005), External Bridge (5006), Challenge (5007), Realtime Gateway (5008), Messaging (5009), Language Intelligence (5010), PrismPipe (5011); AI: Cyrex (8000), Cyrex Interface (5175), Jupyter (8888), MLflow (5500), Ollama (11434); Infra: PostgreSQL (5432), Redis (6379), InfluxDB (8086), MinIO (9000), Milvus (19530), Synapse (8002), etcd (2379).

**Data infrastructure provisioned here:**
- **PostgreSQL** — primary relational store (users, tasks, quests, per-service schemas).
- **Redis** — cache, sessions, **pub/sub stream bus** (the spine of the pipeline).
- **InfluxDB** — time-series metrics/analytics.
- **MinIO** — S3-compatible object storage (documents, MLflow artifacts).
- **Milvus** — vector DB for embeddings (Cyrex RAG, Helox training data).
- **MLflow** — experiment tracking + model registry.
- **Ollama** — local LLM inference runtime.

---

## 2. deepiri-language-intelligence-service (LIS) — "lease & contract intelligence"

**Role:** document → structured-data processing service. Uploads PDF/DOCX leases, contracts, and generic documents; extracts structured abstractions via **Cyrex** (LLM); tracks versions/evolution; builds obligation dependency graphs; chat over documents. No local NLP libs — all intelligence is delegated to Cyrex over HTTP.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `@prisma/client` / `prisma` | PostgreSQL ORM (all persistence) |
| `@aws-sdk/client-s3`, `lib-storage` | Object storage (MinIO/S3) |
| `pdf-parse`, `mammoth` | Local PDF/DOCX → text extraction |
| `multer`, `express-validator`, `express-rate-limit` | Upload, validation, rate limiting |
| `axios` | HTTP client to Cyrex (LLM abstraction, OCR, vector store) |
| `socket.io` | Real-time event broadcast |
| `winston` | Logging (via shared-utils) |
| `@team-deepiri/shared-utils` | `StreamingClient` (Redis Streams), `secureLog`, logger |
| `uuid`, `dotenv`, `mime-types` | IDs, config, MIME |
| Redis Streams | `platform-events`, `ingestion-events`, `document.*` bus |
| Sugar Glider / Synapse sidecar | Preferred transport for the `document.*` bus |
| Bedd (optional) | PII-redaction binary (fail-open) |
| MinIO/S3 | bucket `language-intelligence-documents` |

### Database schema (PostgreSQL, DB `deepiri_language_intelligence`, pgvector enabled)
| Prisma model | Table | Active in code |
|---|---|---|
| `Lease` | `leases` | ✅ |
| `LeaseVersion` | `lease_versions` | ✅ |
| `Contract` | `contracts` | ✅ |
| `ContractVersion` | `contract_versions` | ✅ |
| `Clause` | `clauses` | ✅ |
| `Obligation` | `obligations` | ✅ |
| `ObligationDependency` | `obligation_dependencies` | ✅ |
| `IntelligenceDocument` | `unified_documents` | ✅ |
| `IntelligenceDocumentVersion` | `unified_document_versions` | ✅ |
| `ChatSession` / `Message` | `chat_sessions` / `messages` | ✅ |
| `Document` | `documents` | schema-only |
| `DocumentChunk` | `document_chunks` | schema-only |
| `AnalysisJob` / `AnalysisResult` | `analysis_jobs` / `analysis_results` | schema-only |
| `Embedding` | `embeddings` (pgvector `vector` type) | schema-only (vector work lives in Cyrex/Milvus) |
| `PromptTemplate` | `prompt_templates` | schema-only |

**Data flowing through:** raw document text (`rawText`), structured extractions (`abstractedTerms`, `financialTerms`, `keyDates`, `keyClauses`, `structuredSegments`, `terminationDetails`, `renewalDetails`), obligations + dependency graphs, chat content, SHA-256 text fingerprints, and (via routing) embeddings metadata. Publish-to-bus topics: `document.vectorize`, `document.structured`, `document.training`, `document.artifacts`.

**Pipeline:** upload → MinIO → `unified_documents` row → async process (extract text → fingerprint → version → Cyrex pipeline A/B by `intelligenceProfile` → persist + version snapshot → extract obligations → Bedd PII sanitize → publish document routes) → events on Redis/Sugar Glider + Socket.IO.

---

## 3. deepiri-shared-utils — "transport glue" (`@team-deepiri/shared-utils`)

**Role:** the shared event/security/logging layer consumed by ~10 backend services. Explicitly **transport/event infrastructure only** — no product logic, no DB models.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `ioredis` | Redis client + `StreamingClient` (XADD/XREAD/XGROUP/XACK with hardened ack/retry) |
| `winston` | JSON logger factory, rotating files |
| `dotenv` | env config |
| node `crypto` | SHA-256 API-key hashing |

### Data contracts it owns
- **Redis stream topology** — `StreamTopics` vocabulary shared by the whole platform: `model-events`, `inference-events`, `platform-events`, `agi-decisions`, `training-events`, `training-jobs`, `document.vectorize/training/structured/artifacts`, `pipeline.helox-training.raw/.structured`, `pipeline.pressure.events`, `pipeline.artifact.invalidation`, `pipeline.splice.events`, `pipeline.dead-letter`, `pipeline.metrics`, plus `SUGAR_GLIDER_STREAM_ALLOWLIST`.
- **Secret validators** (password/API-key/token/URL), `secureLog` (redaction), `createRedisClient`.
- **Types:** `ApiKeyScope` (`ingestion:write | analytics:read | admin:all`), `ApiKeyCachePayload`, `StreamEvent`.

**Consumers:** api-gateway, auth, external-bridge, jobs, language-intelligence, messaging, realtime-gateway, registry, telemetry, truss.

---

## 4. deepiri-dataset-processor — "data kitchen"

**Role:** reusable preprocessing **library** upstream of training: clean → dedup → safety-check → quality → version.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `networkx` | Pipeline DAG build, topo sort, cycle detection (`PipelineOrchestrator`) |
| `numpy` | Embedding cosine similarity, quality math |
| `sentence-transformers` (extra `semantic`) | Semantic dedup embedding provider (any `.encode()` object works; optional LSH bucketing for scale) |
| `sqlalchemy` (extra `versioning`) | `dataset_versions` table + session management |
| `pydantic` (extra `versioning`) | `DatasetVersionMetadata` schema |
| `pandas` (extra `quality`) | DataFrame checks (completeness/consistency/uniqueness) |
| stdlib: `hashlib`, `re`, `json` | MD5/SHA dedup, boilerplate removal, JSONL |
| No `datasets`/`transformers`/`torch`/Redis/Milvus/MinIO | in-memory lists + JSONL on disk |

### Data types
- **Input:** `List[str]` texts, `List[Dict]` records (`text` + `label` required), JSONL (primary) / JSON / CSV / Parquet.
- **Output:** `ProcessedData` `{data, metadata, quality_metrics, schema_version}`; quality reports (all 7 dims implemented: completeness/consistency/validity/uniqueness/timeliness/accuracy/integrity — some dims may silently skip or assume-pass when columns/sample thresholds are unmet); dedup reports; leakage reports; version records.
- **Label contract:** string label → `label_id` int, range 0–30 ("31 categories"; verified in dataset-processor + Helox).

### Stages (`DatasetPipeline` / networkx `PipelineOrchestrator`)
`data_loading → data_cleaning → data_validation → data_routing → label_validation → data_transformation` + standalone `quality_check`. Helpers: `TextCleaner`, `ExactDeduplicator`, `SemanticDeduplicationEngine`, `DataLeakageDetector`, `QualityChecker`.

### Database
- Optional SQLAlchemy table **`dataset_versions`** (`dataset_name`, `version`, `dataset_type`, `storage_path`, `storage_backend` (default `s3`, **not implemented**), `total_samples`, `file_count`, `total_size_bytes`, checksums, `parent_version`, `change_summary`, `quality_score`, `validation_status`, JSON metadata). Filesystem fallback: `data/metadata/{dataset_id}_version.json` + `dataset_lineage.json`.
- Dataset taxonomy (`DatasetType`): `lease_abstraction`, `contract_intelligence`, `obligation_dependency`, `regulatory_language`, `clause_evolution`.

---

## 5. diri-cyrex — the AGI agent ("runtime brain")

**Role:** FastAPI AI microservice (port 8000): chat, task decomposition, document/vendor analysis, RAG, multi-agent orchestration, LangGraph + a custom PDGE parallel tool executor, memory, real-time data capture that feeds the training plane.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `fastapi`, `uvicorn`, `pydantic` | API runtime |
| `langchain` / `langgraph` (+langgraph-checkpoint-redis) | Agent orchestration, StateGraph, tool calling |
| `langchain-ollama`, `langchain-openai`, `openai` | LLM providers (Ollama local / OpenAI) |
| `transformers`, `datasets`, `accelerate`, `torch`, `sentence-transformers` | DL models: BERT/DeBERTa intent classifier (50 abilities), MiniLM embeddings (384-d), fine-tune |
| `asyncpg` | PostgreSQL (agent messages, workflows, task executions, events, memories, synapse messages) |
| `redis[hiredis]` | cache, streams, checkpointing |
| `pymilvus` | vector store collections |
| `motor`/`pymongo` | optional MongoDB |
| `sqlalchemy`, stdlib `sqlite3` | task/challenge models, artifact registry, corrections |
| `scikit-learn`, `numpy`, `pandas` | feature/vendor scoring |
| `prometheus-client`, `structlog` | metrics/observability |
| internal: `deepiri-modelkit`, `deepiri-gpu-utils`, `diri-agent-toolbox`, `deepiri-dataset-processor`, `deepiri-training-orchestrator`, `deepiri-prismpipe`, `diri-agent-testing-utils` | shared platform packages |

### Data types
- Core domain: `Message`, `Memory` (`MemoryType`), `AgentRole` (14 roles), `IndustryNiche` (7 niches), `VendorFraudType`, `RiskLevel`, `AgentConfig`.
- Artifact engine: `ArtifactType` (canonical/extraction/reasoning/retrieval/answer/transformation/workflow/learning/system), `Citation`, `Provenance`, JSON schemas (`artifact_bundle`, `duel_state`, `prediction_record`, `pressure_cell`, `pressure_event`, `reflection_result`, `synthesis_result`).
- Embeddings: `sentence-transformers/all-MiniLM-L6-v2`, 384-d, HNSW L2 index in Milvus.

### Database / stores
| Store | What lives there |
|---|---|
| PostgreSQL (`deepiri`) | `cyrex` schema tables: agent playground messages, workflows, task executions, events; `memories` (long-term); `synapse_messages` |
| Redis | cache, LangGraph checkpoint, Synapse streams, `pipeline.helox-training.raw/.structured`, DLQ |
| Milvus | collections: `regulatory_documents`, `contracts`, `leases`, `obligations`, clauses, compliance patterns, version drift, knowledge base, `training_data` |
| SQLite | artifact store (`artifacts`, `artifact_refs`, `citations`), corrections (`learning_artifacts`) |
| MinIO/S3 + InfluxDB + MLflow | artifacts, metrics, model registry |
| Files | `AGENT_FILE_SANDBOX_ROOT`, `data/training/` CSV/JSONL, model cache (`MODEL_CACHE_DIR`) |

### Pipeline flow
`POST /api/v1/...` → `WorkflowOrchestrator.process_request` → guardrails → RAG context → agent executor (LRU) → LLM call → tool dispatch (PDGE parallel, semantic cache) → output safety → inference events → **auto-capture to Helox training streams** → response cache.

Realtime data pipeline: sources (orchestrator/agent/tool/user-feedback) → validate → transform → **Route 1: Helox training** (Redis streams `pipeline.helox-training.*`) → **Route 2: Cyrex runtime** (memory + Synapse pub/sub) → DLQ.

**Tools:** API calls, memory search/store, spreadsheet ops, vendor-fraud analysis (invoice fraud, pricing benchmark, duplicate invoices, vendor risk), pipeline tools, enhanced memory, comprehensive API toolbox (async HTTP, sandboxed file I/O, cache, confidence, batch, DB toolbox).

**MLOps:** `ModelCIPipeline` (test → validate → MLflow register → staging → canary), `model_monitor` (drift/accuracy/latency), `ModelRegistry` (staging/production/archived), `agent_training_service` (corrections → Helox job → training-orchestrator → deploy → reload listener).

---

## 6. deepiri-prismpipe — "capability-routed pipeline / organic pipe"

**Role:** requests become the carrier of computation. Wraps requests in `RequestEnvelope`s routed through capability-registered `Node`s; runs the Deepiri health pipeline `auth → LIS → cyrex → aggregate`. Organic layer: requests become persistent `Organism`s that learn, deduplicate (ComputationGraph), spawn (AncestryTree), parallelize (SwarmCoordinator), hibernate.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `pydantic` | `RequestEnvelope`, state models |
| `httpx` | real HTTP hops (auth/LIS/cyrex health) |
| `structlog`, `orjson`, `pyyaml` | logging, fast JSON, config |
| `redis` | `RedisStorage`, computation cache L2, single-flight locks |
| `asyncpg` | PostgresStorage |
| `fastapi`+`uvicorn`+`gunicorn` | server |

### Database / stores
| Store | What lives there |
|---|---|
| PostgreSQL | single table `prismpipe_kv` (`key` TEXT PK, `value` JSONB, `updated_at`) |
| Redis | prefix `prismpipe:` (KV storage), `prismpipe:cg:` (ComputationGraph cache, per-capability TTL), `prismpipe:cg:sf:` (single-flight locks) |
| SQLite | `DocumentOperationStore` — idempotency/claim-token/dead-letter durability for `document.vectorize` |
| Cyrex Postgres (read-only) | `cyrex.pipeline_stage_inputs/outputs`, `cyrex.artifacts`, `cyrex.pipeline_run_stages` — content-addressed memoization |
| Redis Streams | same 17-topic vocabulary as shared-utils/modelkit + `bedd.dlq` |

**Capabilities/nodes:** `deepiri.session.bootstrap`, `deepiri.health.parallel`, `deepiri.auth.health`, `deepiri.lis.health`, `deepiri.cyrex.health`, `deepiri.aggregate`, `document.vectorize` (+ idempotent processor), plus bench nodes (`bench.compute`, `bench.partition_sum`, `bench.fast/slow`).

---

## 7. deepiri-modelkit — "shared contracts"

**Role:** the contract layer between Helox (training), Cyrex (runtime), and platform services. Pydantic contracts, Redis-stream event schemas, model registry client (MLflow/S3/local), training job queue, dataset manifest validation, Universal RAG module.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `pydantic` | all contracts/schemas |
| `redis` | `TrainingJobQueue` (stream `training-jobs`), `StreamingClient`, `StreamTopics` |
| `mlflow` | tracking + model registry |
| `boto3` | S3/MinIO artifact adapter |
| optional: `torch`, `numpy`, `pandas`, `ollama`, `httpx` | device utils, SemanticAnalyzer |
| jupyter extras: `transformers`, `datasets`, `peft`, `bitsandbytes`, `deepspeed`, `optuna`, `wandb`, `onnx` | ML toolkit |
| `langchain`/`langgraph`, `pymilvus`, `pinecone-client`, `weaviate-client` | Universal RAG |

### Data contracts
- `ModelInput/Output`, `ModelMetadata`, `AIModel` protocol, `ModelContract`.
- Training: `TrainingPriority` (live/batch), `DatasetManifest` (`id, version, path, content_hash, row_count, schema, produced_by`), `TrainingRunRequest`, `AgentTrainingJob`.
- Events (`EventType`): `model-ready`, `model-loaded`, `model-failed`, `inference-complete/failed`, `user-interaction`, `task-created/completed`, `agi-decision/action`, `training-started/complete/failed` + `PressureBusEvent`, `ArtifactInvalidationEvent`, `SpliceBusEvent`.
- RAG: `Document` + `DocumentType` (15 types incl. regulation, contract, work_order, invoice...), `IndustryNiche` (11 niches), `RAGQuery`, `RetrievalResult`, `UniversalRAGEngine`; retrievers (`Hybrid` semantic+BM25+RRF, `Contextual`, `MultiQuery`), `AdvancedCacheManager` (Redis keys `rag:`), `RAGEvaluator`, `AsyncDocumentIndexer`.
- Registry: `ModelRegistryClient` (mlflow | s3 | local), `MLFLOW_TRACKING_URI` default `http://mlflow:5000`.

**Data flow (the documented train→serve contract):** HELOX trains → registers in MLflow + S3/MinIO → publishes `ModelReadyEvent` → Redis Streams → CYREX downloads, loads, serves inference. **No SQL DB of its own** (sqlalchemy/alembic are transitive MLflow deps).

---

## 8. diri-helox — "the factory"

**Role:** training-side ML framework. Owns model training/fine-tuning, dataset versioning, experiment tracking (MLflow/W&B/Optuna), model export. Cyrex is the runtime that consumes Helox's trained models.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `torch`, `peft`, `transformers`, `accelerate`, `datasets` | training backend, LoRA/QLoRA, pretrained models |
| `mlflow`, `optuna`, `wandb` | tracking + sweeps |
| `numpy`, `pandas`, `scikit-learn`, `sentencepiece` | data + tokenization |
| `sentence-transformers` | semantic dedup + RAG embeddings |
| `onnx`/`onnxruntime` | export |
| `redis`/`hiredis` | training streams (`pipeline.helox-training.raw/.structured`, `training-jobs`) |
| `grpcio`/`protobuf` | Synapse sidecar gRPC |
| `sqlalchemy`, `alembic` | `dataset_versions` ORM + migrations |
| `networkx` | pipeline DAG |
| `boto3` | S3/MinIO |
| `presidio` (optional) | PII handling |
| internal: `deepiri-dataset-processor`, `deepiri-training-orchestrator`, `deepiri-modelkit`, `deepiri-gpu-utils`, `deepiri-helox-sdk` | domain packages |

### Training pipeline (DynamicTrainingPipeline)
**Data sources** (`data_sources/factory.py`): `stream` (Redis `pipeline.helox-training.*`, MIN_QUALITY_SCORE 0.4), `postgres` (`cyrex.helox_training_samples`), `milvus` (`training_data`), `cyrex_training_stream`/`cyrex_training_postgres` (contract `cyrex.helox-training.v1`), `synthetic` (31-category), `self_feedback` (high-confidence predictions), `static` (JSONL), `composite`.
**Stages:** source → TextCleaner + ExactDeduplicator (dataset-processor) → 70/15/15 split (DatasetBuilder) → `IntentClassifierTrainer` (BERT/DeBERTa, 31 categories) via `deepiri-training-orchestrator` callbacks → `ModelEvaluator` (evaluate + rouge-score) → MLflow export + model-ready event.

Other pipelines: full LoRA/QLoRA (Mistral-7B nf4), DeepSpeed ZeRO distributed, RAG training, versioned pipeline, bandit/fraud/vendor-risk/industry-LoRA variants.

### Database
- Postgres `dataset_versions` (mirrors dataset-processor table) + mirror table `cyrex.helox_training_samples`.
- SQLite for local versioning tests.
- Redis training streams + job queue; MLflow (default `http://mlflow:5000`); MinIO bucket `mlflow-artifacts`; Milvus `training_data` + `deepiri_challenges`.

---

## 9. deepiri-training-orchestrator — "reproducibility controller"

**Role:** framework-agnostic, callback-based training loop with determinism, config fingerprinting, and MLflow/wandb tracking. Extracted from Helox for reuse.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `torch` | seeding, CUDA determinism |
| `numpy` | seeding |
| `mlflow` | all tracking + model registry |
| `wandb` (optional Poetry extra) | parallel experiment tracking when installed + `use_wandb=True` |
| `pytest`, `ruff` | dev |

Legacy DVC helpers were **removed**; dataset versioning is via deepiri-dataset-processor, not an undeclared DVC soft-import.

### Data types
- **Input:** arbitrary config `Mapping[str, Any]`, any `Iterable` of batches, `train_step(step, batch) -> metrics` callable, optional `eval_fn()`.
- **Output:** `TrainingContext`, JSON checkpoints (`checkpoint_step_{n}.json`), fingerprint files (`training_fingerprint.json`, 16-char SHA256), MLflow runs (params/metrics/`dataset_path`/`dataset_hash` SHA256/artifacts), MLflow registry stages Staging/Production.

### Database
MLflow Tracking Server (default `http://localhost:5000`; file or SQL backend), MLflow Model Registry. No direct Postgres/Redis/Milvus/MinIO.

---

## 10. deepiri-elkedel — Cyrex's "eyes" (perception sidecar)

**Role:** episodic visual memory + sensory cortex for agentic perception. Two taxonomy-free layers: (1) **memory** — persistent object identities with a queryable spatiotemporal index (embeddings + `core/memory_math.py`, no CV), exposed as an **MCP server**; (2) **sensory cortex** — streams a raw **Physics Tensor** (optical flow, inverse depth, surface normals, photometric phase, motion saliency, novelty) so Cyrex's cognitive cycle (Parse → Anticipate → Extract → Duel → Reflect → Persist) grounds in physics.

### Data libraries & tools
| Library | Purpose |
|---|---|
| `numpy` | all memory/physics math (only heavy core dep) |
| `opencv-python-headless` | Farneback flow, capture/decode |
| `fastapi` + `uvicorn` | runtime (port 8765) |
| `mcp` | MCP server (`elkedel-mcp`) |
| `pydantic` | validation |
| extra `vision`: `ultralytics` (YOLO), `torch`/`torchvision` (DINOv2) | detection + embeddings |
| extra `sensory`: `pyzmq` | ZeroMQ PUB of Physics Tensors |
| extra `depth`: `transformers` (Depth Anything V2) | depth |

### Data types / wire contracts
- `Observation`, `MemoryTrace`, `SpatialState` (embedding + spatial + confidence).
- `PhysicsTensor` (flow (H,W,2), depth (H,W), normals (H,W,3), photometric (H,W), saliency (H,W), novelty scalar, covariance (2,2)) — wire form float16 + zlib + base64, JSON envelope.
- Memory math: unit-sphere traces `(mu, R)`, leaky-integrator strength `R <- R·exp(-λ·dt)`, greedy cosine association (default dim 384).

### Database
SQLite `artifacts/memory/elkedel.db` (`traces`, `observations`) and `artifacts/sensory/elkedel_physical.db` (`physical_observations`); artifact JSONL `artifacts/sensory/stream.jsonl`.

### Services & CLIs
Services: `perception` (YoloDetector/MotionDetector → DINOv2 embedder → Observations), `memory` (MemoryStore + MemoryEngine: decay→associate→consolidate→persist), `sensory` (CameraSource → PhysicsTensor → ZeroMQ/File/Null sinks), `mcp` (tools: `remember`, `where`, `what_changed`, `episode`, `forget`, `stats`), `runtime` (FastAPI + WS). CLIs: `elkedel-memory`, `elkedel-perception`, `elkedel-sensory`, `elkedel-mcp`, `elkedel-runtime`.

---

## 11. The entire pipeline, end to end

```
 USER  ──►  web-frontend (:5173)
            │  HTTPS
            ▼
 API Gateway (:5100) ─── JWT auth, rate limit, route ───► auth (:5001)
            │
            ├─► task/challenge/engagement/messaging/notification/analytics services ──► PostgreSQL + Redis + InfluxDB
            │
            ├─► language-intelligence (:5010)
            │      upload → MinIO → extract (pdf-parse/mammoth) → Cyrex abstract
            │      → PostgreSQL (unified_documents/leases/contracts/obligations)
            │      → publish document.vectorize/.structured/.training/.artifacts
            │
            ├─► prismpipe (:5011)  auth→LIS→cyrex→aggregate health, organic pipe, RequestEnvelopes
            │
            └─► diri-cyrex (:8000)  guardrails → RAG(Milvus) → agent loop → tools → LLM
                    → memory(Postgres/Redis) → inference events → auto-capture
                    │
                    ▼  (captured interactions, tool results, corrections)
            Redis Streams: pipeline.helox-training.raw → .structured · training-jobs · training-events
                    │
                    ▼
 dataset-processor    clean → dedup (exact MD5 + semantic) → leakage check → quality(7 dims)
                    │  → version (dataset_versions / JSONL + lineage)     [DatasetType taxonomy]
                    ▼
 training-orchestrator   seeds/CUDA determinism → fingerprint → MLflow run → callbacks (checkpoint/early-stop)
                    │
                    ▼
 helox  DynamicTrainingPipeline / LoRA-QLoRA / DeepSpeed / RAG training
                    │  → ModelEvaluator → MLflow registry (Staging→Production) → S3/MinIO artifacts
                    ▼
 modelkit  ModelReadyEvent → Redis (model-events)  →  manifests, registry client
                    │
                    ▼
 cyrex   downloads model → reload listener → serves inference  ◄── closes the flywheel
                    │
 elkedel (sensory)  PhysicsTensor stream + episodic memory (SQLite/MCP)  →  grounds Cyrex perception
```

---

## 12. Data-type inventory (what kind of data Deepiri holds)

| Category | Formats | Where it lives |
|---|---|---|
| User/auth/tasks/engagement | relational rows (users, tasks, quests, streaks, challenges) | PostgreSQL |
| Documents (leases, contracts, generic) | PDF/DOCX bytes; extracted text; JSON abstractions | MinIO + PostgreSQL (LIS) |
| Structured intelligence | `abstractedTerms`, financial/key dates, clauses, obligations, dependency graph | PostgreSQL (LIS) |
| Chat / messages | chat_sessions/messages; Synapse rooms; platform events | PostgreSQL (LIS/Cyrex), Synapse |
| Agent memories | `memories` rows; LangGraph checkpoints | PostgreSQL + Redis |
| Embeddings / vectors | 384-d MiniLM vectors, HNSW L2 | Milvus |
| Training data (raw → structured) | JSONL records (`text`+`label`, 31 categories); Redis stream records; Postgres rows; Milvus `training_data`; synthetic | Redis streams, files, Postgres, Milvus |
| Datasets (versioned) | JSONL + version/lineage metadata; `dataset_versions` table | Filesystem/SQLAlchemy (Postgres) |
| Model artifacts / experiments | MLflow runs, model files, checkpoints | MLflow + MinIO/S3 |
| Events (inference, model, training, agi-decision) | Redis Streams (17-topic vocabulary) | Redis |
| Time-series metrics | analytics, model latency/accuracy | InfluxDB |
| Artifact engine (Cyrex) | artifacts/artifact_refs/citations; correction learning artifacts | SQLite |
| Perception (Elkedel) | PhysicsTensors (flow/depth/normals/saliency), episodic traces | SQLite + ZeroMQ/JSONL |

---

## 13. Database ↔ component mapping

| Store | Owned/written by | Also read by |
|---|---|---|
| PostgreSQL (per-service schemas, Prisma) | auth, LIS (`deepiri_language_intelligence`), Cyrex (`cyrex.*`), messaging, registry, jobs, truss, speech | API Gateway, PrismPipe (read-only `cyrex.*` memoization), Helox (`cyrex.helox_training_samples`) |
| Redis | shared-utils `StreamingClient`, LIS, Cyrex, PrismPipe, messaging, telemetry | everyone on the stream bus; Helox data sources |
| Milvus | Cyrex (indexer) | Helox (`training_data`), RAG |
| MinIO/S3 | LIS (documents), Helox/MLflow (artifacts) | Cyrex (model download) |
| MLflow | Helox, training-orchestrator | Cyrex, modelkit |
| InfluxDB | platform analytics, Cyrex | dashboards |
| SQLite | Cyrex (artifacts/corrections), PrismPipe (document ops), Elkedel (memory/sensory) | their own services |
| Filesystem | dataset-processor (versioning), Helox, Elkedel (artifacts) | local tooling |

---

## 14. Notable gaps / drift found

1. **pgvector provisioned but unused in LIS** — `Embedding`/`embeddings` table exists; actual vectors live in Cyrex/Milvus. Several schema-only models (`documents`, `document_chunks`, `analysis_jobs`, `analysis_results`, `prompt_templates`) are not referenced by code.
2. **`deepiri-shared-utils` storage_backend `s3` is not implemented** in dataset-processor (`NotImplementedError`); only `local` works.
3. **`platform-services/shared/deepiri-prismpipe/` submodule is populated and pinned** (src, nodes, docs, Dockerfile — 112 files, resolved commit); a fresh clone must run `git submodule update --init` to see it, which can look like an empty dir if skipped (`docs/GO_NO_GO_WIRING.md`).
4. **LIS has two divergent copies** — the top-level standalone is newer (unified-document ingestion, obligation service, chat) than the platform submodule pin.
5. **Three repos share the same Redis stream topic vocabulary** (shared-utils, modelkit, prismpipe) — a drift risk if one changes without the others.
6. **Dataset processor default label range 0–30** ("31 categories") matches Helox's 31-category intent classifier (two verified hardcoded copies; Cyrex's BERT uses 50 abilities) — the contract exists but is implicit, not enforced by modelkit.
