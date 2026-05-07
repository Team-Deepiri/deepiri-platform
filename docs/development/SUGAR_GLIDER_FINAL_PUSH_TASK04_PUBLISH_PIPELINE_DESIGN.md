# Sugar Glider Final Push - Task 04 Publish Pipeline Design

Updated: 2026-04-23 (UTC)

## Objective

Design an optional publish coalescer for Sugar Glider that reduces Redis `XADD` overhead under concurrent load while preserving existing HTTP/gRPC behavior and reliability guarantees.

## Constraints Carried From Task 03

- Heavy tail bottleneck is downstream-dominant, but publish still contributes meaningful p95 cost.
- Publish path currently issues one Redis `XADD` per event.
- We must not regress:
  - `lost_events=0`
  - `failed_ops=0`
  - `error_rate_pct=0`
- No API wire contract changes.

## External Behavior Contract

- HTTP `POST /v1/publish` response semantics remain unchanged.
- gRPC `Publish` response semantics remain unchanged.
- gRPC `PublishBatch` response semantics remain unchanged.
- Existing WAL fallback behavior remains authoritative when Redis publish fails.

## Configuration Contract

Add optional env/config fields:

- `SIDECAR_PUBLISH_PIPELINE_ENABLED` (bool, default `false`)
- `SIDECAR_PUBLISH_PIPELINE_MAX_BATCH` (int, default `64`)
- `SIDECAR_PUBLISH_PIPELINE_FLUSH_MS` (int, default `0`)
- `SIDECAR_PUBLISH_PIPELINE_QUEUE_SIZE` (int, default `8192`)
- `SIDECAR_PUBLISH_PIPELINE_MAX_BYTES` (int, default `1048576`)

Validation rules:

- `MAX_BATCH > 0`
- `FLUSH_MS >= 0`
- `QUEUE_SIZE > 0`
- `MAX_BYTES > 0`

## Implementation Design

### 1) Internal Components

- `publishPipeline` (new internal service component):
  - owns an in-memory request queue
  - has one flush loop goroutine
  - flushes buffered publish jobs via Redis pipeline
- `publishJob` structure:
  - `ctx context.Context`
  - `req redisstreams.PublishRequest`
  - `resultCh chan publishResult`
- `publishResult`:
  - `entryID string`
  - `err error`

### 2) Publish Flow Integration

- Replace direct publish call in `publishInternal` with a single method:
  - `publishToRedis(ctx, req) (entryID string, err error)`
- Behavior:
  - if publish pipeline disabled: call existing direct publisher path
  - if enabled: enqueue job and wait for `resultCh`
  - if queue is full or enqueue fails: immediate direct publish fallback
- WAL fallback in `publishInternal` stays unchanged and wraps any Redis publish failure.

### 3) Flush Algorithm

Flush triggers (first to hit):

- buffered count reaches `MAX_BATCH`
- buffered bytes reaches `MAX_BYTES`
- timer reaches `FLUSH_MS` (when `FLUSH_MS > 0`)
- context cancellation/shutdown flush

Flush execution:

- build Redis `XAddArgs` per job with current publisher field logic
- execute batched Redis pipeline
- map per-job command results back to each `resultCh`
- on per-job failure:
  - return error to caller so existing WAL fallback path handles durability

### 4) Shutdown Behavior

- during sidecar close:
  - stop accepting new queued jobs
  - flush pending jobs once
  - fail any unresolved jobs with a deterministic error
- direct publish path remains available until shutdown completes.

## Data/Ordering Semantics

- Ordering guarantee is best-effort FIFO at queue intake; no strict global ordering guarantee added beyond current Redis stream ordering behavior.
- Response mapping is one-to-one:
  - each request still receives its own Redis entry ID or error.

## Risk Controls

- Feature is off by default.
- Queue-full path does not fail request by itself; it falls back to direct publish.
- Redis errors still route to WAL append logic from existing `publishInternal`.

## Test Design (For Task 05/09)

Required coverage:

- pipeline disabled -> direct publish path unchanged
- queue enqueue/dequeue success and per-request entry ID mapping
- queue full -> direct fallback path
- context cancellation before result -> clean error path
- pipeline partial failure handling (some commands fail)
- WAL fallback on publish failure while pipeline enabled
- `PublishBatch` behavior unchanged with pipeline enabled
- graceful shutdown with pending queued jobs

## Acceptance Checks For Task 05 Implementation

- `go test ./...` in Sugar Glider passes.
- No protocol/endpoint behavior changes visible to RTG.
- New env knobs surface via `/v1/config`.
- Publish pipeline off by default and runtime-safe when enabled.

## Task 04 Outcome

Task 04 design is decision-complete and implementation-ready.
