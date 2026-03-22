# Streamed Data & Routing: Implementation Guide

This guide implements the founder’s workflow: **make streamed data**, observe Redis, understand payloads, create subscriptions, and route data to **Cyrex/Milvus** and **Helox** pipelines. It also ties in the GitHub feedback on data quality thresholds.

---

## A) Prerequisites

### 1. Concepts You Should Know

| Topic | Why It Matters |
|-------|----------------|
| **Redis** | The platform uses Redis for streaming. You need to connect, run commands, and understand streams vs cache. |
| **Redis Streams (not Pub/Sub)** | Data lives in **streams** (`XADD`/`XREAD`), not pub/sub channels. Stream names are fixed (see below). |
| **Payload structure** | Events are key-value maps: `event`, `timestamp`, `source`, `data`, etc. You’ll parse and route by these fields. |
| **Docker / Docker Compose** | Redis and other services run in containers. You start them with `docker compose` before viewing or subscribing. |
| **Cyrex** | AI/ML runtime; consumes inference/model events and uses **Milvus** for vectors. |
| **Helox (diri-helox)** | Data/ML pipelines (e.g. `pipelines/data_preprocessing/example_pipeline.py`). Today they often rely on **manual input**; the goal is to feed them from Redis streams. |
| **Data quality thresholds** | In Helox, `completeness_threshold` and `consistency_threshold` (e.g. 0.9, 0.85) should be justified with research and math (per founder feedback). |

### 2. Tools You’ll Use

- **Terminal** (PowerShell on Windows): to run Docker and `redis-cli`.
- **redis-cli**: to inspect streams and payloads (or use a Redis GUI).
- **Codebase locations** (see Section 5): TypeScript streaming client, publishers, consumers, and (when cloned) `diri-helox` pipelines.

### 3. Repos and Submodules

- **This repo**: `deepiri-platform` — Redis config, `StreamingClient`, publishers, consumers.
- **diri-helox**: `deepiri-platform/deeri-helox` (or `diri-helox`) — pipelines, including `pipelines/data_preprocessing/example_pipeline.py` and its quality thresholds.
- **diri-cyrex**: AI runtime; receives streamed events and uses Milvus.

---

## B) Full Task Explanation

### High-level goal

**“We want to make this streamed data.”**

That means:

1. **View** what’s already in Redis (streams and payloads).
2. **Understand** the payload structure.
3. **Create** (or reuse) Redis stream subscriptions.
4. **Extract** the right fields from each event.
5. **Route** that data to:
   - **Destination 1:** Cyrex runtime / Milvus (used in pipelines and RAG).
   - **Destination 2:** Helox data processing pipelines (today often manual input; goal is to feed them from streams).

So the task is: **observe → subscribe → extract → route to Cyrex and Helox.** For a plain-language breakdown of the four goals (streams, payloads, designing events, publishing), see [STREAMED_DATA_FOUR_GOALS_PLAIN_LANGUAGE.md](STREAMED_DATA_FOUR_GOALS_PLAIN_LANGUAGE.md).

### Step-by-step (founder’s flow)

1. **View Redis streams**  
   See which streams exist and that data is flowing.

2. **Identify data “channels”**  
   In this codebase the “channels” are **stream names**:  
   `platform-events`, `model-events`, `inference-events`, `training-events`, `agi-decisions`.

3. **Observe payloads**  
   Run `XREAD`/`XRANGE` (or use existing consumers) and inspect `event`, `source`, `data`, etc.

4. **Understand payload structure**  
   Document fields needed for Cyrex (e.g. model name, embeddings, IDs) and for Helox (e.g. `text`, `label`, or pipeline-specific fields).

5. **Create a Redis subscription**  
   Use the existing `StreamingClient` (or a small script) to subscribe to the right stream(s) and process events.

6. **Extract fields**  
   From each event, pull the fields required by Cyrex and by Helox (e.g. for `example_pipeline.py`: `required_fields`, quality metrics).

7. **Stream and route**  
   - **To Cyrex/Milvus:** send via Cyrex API or by publishing to streams that Cyrex already consumes.  
   - **To Helox:** push into the pipeline input (e.g. the interface that today is “manual insertion”) so Helox runs on streamed data.

### Relation to the GitHub comment (thresholds)

The founder’s comment on `example_pipeline.py` — *“Are these numbers accurate? I believe they can be improved with better research and math”* — refers to:

- `completeness_threshold`: 0.9  
- `consistency_threshold`: 0.85  

Your advanced implementation can include:

- **Research:** how these metrics are defined in the pipeline and in literature.  
- **Math:** how to set or tune thresholds (e.g. from validation data or ROC-style analysis).  
- **Implementation:** configurable or adaptive thresholds, or a small script to evaluate different values.

That work lives in **Helox** (e.g. `pipelines/data_preprocessing/example_pipeline.py`); the streaming work ensures Helox receives the same data you’re observing in Redis.

---

## C) In-Depth Implementation Guide

### Step 0: Start Redis (Docker first)

You need Redis running before viewing or subscribing.

**Option A – Redis only (fastest for learning):**

```powershell
cd c:\Users\jarti\Deepiri\deepiri-platform
docker compose -f docker-compose.dev.yml up -d redis
```

**Option B – Full dev stack (Redis + Postgres + Milvus + backend services):**

```powershell
cd c:\Users\jarti\Deepiri\deepiri-platform
docker compose -f docker-compose.dev.yml up -d
```

**Connection details (dev):**

- **Host:** `localhost`  
- **Port:** `6380` (mapped from container 6379)  
- **Password:** `redispassword` (default from `REDIS_PASSWORD`)

So: **yes, start the Docker container first**, then use the paths and commands below.

---

### Step 0b: See which containers exist & start only what you need

**List all services defined in the compose file (before starting anything):**

```powershell
cd c:\Users\jarti\Deepiri\deepiri-platform
docker compose -f docker-compose.dev.yml config --services
```

You'll see every service name (e.g. `postgres`, `redis`, `ollama`, `cyrex`, `task-orchestrator`, `api-gateway`, `synapse`, `mlflow`, `frontend-dev`, etc.). **Ollama** is one of them and is not required for Redis streaming — it's used by Cyrex for local LLMs and can use a lot of disk space.

**Minimal set for “real data” streaming (no Ollama, no Cyrex, no MLflow, no frontend):**

Start only the services needed for the **task-orchestrator** to publish `platform-events` to Redis:

- **postgres** – task-orchestrator stores task versions here  
- **redis** – streams live here  
- **synapse** – config/routing; task-orchestrator depends on it  
- **task-orchestrator** – publishes `task-created` / `task-completed` / `task-failed` to `platform-events`

Optional: **api-gateway** (and its dependencies) if you want to call the API through the gateway instead of the task-orchestrator directly.

**Start only these (no Ollama):**

```powershell
cd c:\Users\jarti\Deepiri\deepiri-platform
docker compose -f docker-compose.dev.yml up -d postgres redis synapse task-orchestrator
```

To also use the API via the gateway (e.g. `http://localhost:5100/api/tasks`), add **auth-service** and **api-gateway** (gateway depends on auth and task-orchestrator):

```powershell
docker compose -f docker-compose.dev.yml up -d postgres redis influxdb synapse auth-service task-orchestrator api-gateway
```

**Triggering events that publish to Redis**

After the minimal stack is up, create a task so the task-orchestrator publishes a `task-created` event to the `platform-events` stream.

**Option 1 – Call task-orchestrator directly (simplest):**

```powershell
# Create a task (task-orchestrator on port 5002)
# taskId and userId can be omitted — the service will create a test user and generate a task UUID.
# Use status "todo" (not "open"); the DB allows: todo, in_progress, blocked, review, done, cancelled.
Invoke-RestMethod -Method POST -Uri "http://localhost:5002/tasks" -ContentType "application/json" -Body '{"taskData":{"title":"Test task","description":"Streaming test","status":"todo","priority":"medium"}}'
```

If you use `curl.exe` (e.g. from Git Bash or WSL), use:

```bash
curl -X POST http://localhost:5002/tasks -H "Content-Type: application/json" -d "{\"taskData\":{\"title\":\"Test task\",\"description\":\"Streaming test\",\"status\":\"todo\",\"priority\":\"medium\"}}"
```

**Option 2 – Via API Gateway (if you started api-gateway on port 5100):**

```powershell
Invoke-RestMethod -Method POST -Uri "http://localhost:5100/api/tasks" -ContentType "application/json" -Body '{"taskData":{"title":"Test task","description":"Streaming test","status":"todo","priority":"medium"}}'
```

Then in Redis (e.g. `docker exec -it deepiri-redis-dev redis-cli -a redispassword`):

```bash
KEYS *
XRANGE platform-events - + COUNT 5
```

You should see the `platform-events` stream and the new event. To trigger more events: **task-completed** — `PUT http://localhost:5002/tasks/<taskId>` with `{"userId":"user-123","changes":{"status":"completed"},"changeReason":"Done"}`; **task-failed** — same with `"status":"failed"`.

---

### Step 1: View Redis streams (no file path needed for viewing)

From your machine, use `redis-cli` against the dev instance.

**Install redis-cli (if needed):**

- Windows: install Redis from https://github.com/microsoftarchive/redis/releases or use WSL and `sudo apt install redis-tools`.  
- Or run `redis-cli` inside the Redis container (see below).

**Connect:**

```bash
redis-cli -h localhost -p 6380 -a redispassword
```

**Or from inside the container:**

```powershell
docker exec -it deepiri-redis-dev redis-cli -a redispassword
```

**Commands to “view channels” (streams):**

```bash
# List stream keys (stream names)
KEYS *

# Inspect a stream (e.g. platform-events)
XINFO STREAM platform-events

# Read last 5 messages from a stream
XRANGE platform-events - + COUNT 5

# Or read in reverse (newest first)
XREVRANGE platform-events + - COUNT 5

# Blocking read of new messages (useful to “watch” live)
XREAD COUNT 10 BLOCK 5000 STREAMS platform-events 0
```

**When Redis is empty:** If `KEYS *` returns `(empty array)` and `XINFO STREAM platform-events` says "no such key", the streams don't exist yet — Redis creates a stream on **first publish**. Use **Step 1b** (start services) or **Step 1c** (manual test event) below.

**Step 1b – Get real data: start the services that publish.** From the repo root:
```powershell
cd c:\Users\jarti\Deepiri\deepiri-platform
docker compose -f docker-compose.dev.yml up -d
```
Then trigger actions that publish events (e.g. create a task via the API, process a document). Streams like `platform-events` will appear once the first event is published.

**Step 1c – Create a test stream (no other services needed).** While in `redis-cli`, run:
```bash
XADD platform-events * event task-created timestamp "2025-03-07T12:00:00Z" source "test" data "{\"taskId\":\"test-1\",\"userId\":\"you\"}"
```
Then run `KEYS *` and `XRANGE platform-events - +` — you'll see the new stream and the message.

Repeat for: `model-events`, `inference-events`, `training-events`, `agi-decisions`. If a stream doesn’t exist yet, `KEYS *` won’t show it; it’s created when the first event is published.

**Relevant file paths (for reference, not for “viewing”):**

- Stream names and client:  
  `platform-services/shared/deepiri-shared-utils/src/streaming/StreamingClient.ts`  
- Who publishes what:  
  `platform-services/backend/deepiri-language-intelligence-service/src/streaming/eventPublisher.ts`  
  (and other `*/streaming/eventPublisher.ts` under `platform-services/backend/`)

---

### Step 2: Identify streams and observe payload structure

**Streams in this platform:**

| Stream | Purpose | Typical publishers |
|--------|---------|--------------------|
| `platform-events` | Tasks, leases, contracts, messages | Language Intelligence, Messaging, Task Orchestrator |
| `model-events` | Model lifecycle | Helox / Cyrex |
| `inference-events` | Inference results, latency, tokens | Cyrex |
| `training-events` | Training runs | Helox |
| `agi-decisions` | AGI decision events | (future use) |

**Common payload shape (from `StreamEvent` and publishers):**

- `event`: string (e.g. `lease-created`, `contract-processed`, `task-created`).  
- `timestamp`: ISO string.  
- `source`: service name (e.g. `language-intelligence-service`).  
- `correlation_id`: optional.  
- `data`: object (event-specific: `leaseId`, `contractId`, `processingTimeMs`, `confidence`, etc.).  
- Other keys (e.g. `user_id`, `request_id`) where applicable.

You “observe payloads” by running `XRANGE`/`XREVRANGE` and writing down the keys and shapes you need for Cyrex and for Helox.

---

### Step 3: Create a Redis subscription and extract fields

**Option A – Use the existing TypeScript `StreamingClient`**

- **File:**  
  `platform-services/shared/deepiri-shared-utils/src/streaming/StreamingClient.ts`  
- **Usage:**  
  `subscribe(streamName, callback, options)`.  
  Callback receives an `StreamEvent`; you extract fields and then route (see Step 4).

**Option B – Minimal Node script (standalone)**

Create e.g. `scripts/stream-subscriber.js` (or `.ts` in a small Node project):

- Connect to Redis (`localhost`, port `6380`, password `redispassword`).
- Use `XREAD` in a loop (or ioredis `xread`) on the stream(s) you care about.
- Parse the key-value array into an object and log or forward it.

**Option C – Follow existing consumers**

- **Realtime Gateway** (subscribes to all four event streams and forwards to Socket.IO):  
  `platform-services/backend/deepiri-realtime-gateway/src/streaming/eventConsumer.ts`  
- **Analytics / Notifications:**  
  `platform-services/backend/deepiri-platform-analytics-service/src/streaming/eventConsumer.ts`  
  `platform-services/backend/deepiri-notification-service/src/streaming/eventConsumer.ts`  

Use these as templates for your own consumer that extracts fields and routes to Cyrex and Helox.

**Extraction checklist:**

- For **Cyrex/Milvus:** e.g. `event`, `data.model_name`, `data.embedding` or document IDs, `user_id`, `request_id`.  
- For **Helox:** e.g. `data.text`, `data.label`, or whatever `example_pipeline.py`’s `required_fields` and input schema expect.

---

### Step 4: Route to Cyrex and Helox

**Destination 1 – Cyrex runtime / Milvus**

- Cyrex already consumes inference/model-related streams and uses Milvus.  
- Ensure your subscriber either:  
  - Publishes events in the format Cyrex expects (same stream names and payload shape), or  
  - Calls Cyrex APIs (e.g. document/vector APIs) with the extracted fields.  
- Config: `CYREX_BASE_URL`, `CYREX_API_KEY`; Milvus is used by Cyrex (see `ops/k8s/configmaps/cyrex-configmap.yaml` and backend env).

**Destination 2 – Helox pipelines**

- Today Helox often expects “manual insertion” of input data.  
- **Advanced implementation:**  
  - Add an input adapter (e.g. a small service or script) that:  
    - Subscribes to the chosen Redis stream(s).  
    - Maps stream events to the input format of the Helox pipeline (e.g. the format expected by `example_pipeline.py`).  
    - Writes to the pipeline’s input (file, queue, or API).  
  - So “manual insertion” is replaced by this stream-driven insertion.

**Routing diagram (target state):**

```
Redis Streams (platform-events, inference-events, …)
        │
        ├──► [Your subscription / consumer]
        │            │
        │            ├──► Cyrex API / Milvus (vector store, pipelines)
        │            │
        │            └──► Helox pipeline input (e.g. example_pipeline.py)
```

---

### Step 5: Data quality thresholds (Helox, from GitHub)

The founder’s comment applies to **diri-helox**:

- **File:** `pipelines/data_preprocessing/example_pipeline.py`  
- **Parameters:** `required_fields`, `enable_quality_check`, `completeness_threshold`, `consistency_threshold`.

**Advanced implementation:**

1. **Define metrics**  
   Document how “completeness” and “consistency” are computed in the pipeline (e.g. % non-null, schema consistency).

2. **Research**  
   Find literature or internal benchmarks for similar data and thresholds.

3. **Math**  
   Propose a method (e.g. validation set, precision/recall, or domain rules) to choose or tune 0.9 and 0.85.

4. **Code**  
   - Make thresholds configurable (config file or env).  
   - Optionally: script to run the pipeline with different thresholds and compare outcomes.  
   - Optionally: adaptive thresholds based on data statistics.

This can live in a short “Data quality thresholds” section in the Helox repo and in `example_pipeline.py` (and related config).

---

### Step 6: Checklist for “advanced” implementation

- [ ] Redis running via Docker; can connect with `redis-cli` on port 6380.  
- [ ] Listed streams with `KEYS *` / `XINFO STREAM` and read payloads with `XRANGE`/`XREVRANGE`.  
- [ ] Documented payload structure for the streams you care about.  
- [ ] Implemented a subscription (new or existing consumer) that reads from the right stream(s).  
- [ ] Extracted fields needed for Cyrex and for Helox.  
- [ ] Routed to Cyrex (stream or API) and to Helox pipeline input (replacing manual insertion).  
- [ ] (Optional) In Helox: researched and justified `completeness_threshold` and `consistency_threshold`; made them configurable and documented.

---

## Quick reference: file paths

| Purpose | Path |
|--------|------|
| Stream names & client | `platform-services/shared/deepiri-shared-utils/src/streaming/StreamingClient.ts` |
| Platform event publishers | `platform-services/backend/*/src/streaming/eventPublisher.ts` |
| Example consumer (all streams) | `platform-services/backend/deepiri-realtime-gateway/src/streaming/eventConsumer.ts` |
| Docker dev stack (Redis port 6380) | `docker-compose.dev.yml` (service: `redis`) |
| Streaming docs | `docs/development/STREAMING_IMPLEMENTATION_COMPLETE.md` |
| Helox pipelines (when cloned) | `diri-helox` / `deeri-helox` → `pipelines/data_preprocessing/example_pipeline.py` |

---

## Summary

- **A) Prerequisites:** Redis (streams), Docker, payload structure, Cyrex, Helox, and data quality concepts.  
- **B) Task:** Observe Redis streams → understand payloads → subscribe → extract fields → route to Cyrex/Milvus and to Helox pipelines; optionally improve Helox thresholds with research and math.  
- **C) Implementation:** Start Docker (Redis on 6380) → use `redis-cli` to view streams and payloads → use `StreamingClient` or a small script to subscribe and route; add a Helox input adapter and threshold tuning in diri-helox.

You do **not** need to “go to a certain file path” to *view* channels — you run Docker, then `redis-cli`. The file paths above are for *implementing* subscribers and routing logic. The **deepiri-platform/deeri-helox** (or diri-helox) repo is where the Helox pipelines and `example_pipeline.py` live; clone it if you’re working on pipeline input or threshold improvements.
