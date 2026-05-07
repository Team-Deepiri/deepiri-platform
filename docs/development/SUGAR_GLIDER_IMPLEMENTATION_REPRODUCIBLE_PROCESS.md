# Sugar Glider Main Path: Reproducible Implementation Process

## Purpose
This document captures the exact implementation workflow used to productionize the Sugar Glider transport path for Realtime Gateway (RTG), in a way another engineer can reproduce exactly.

Date context for this runbook: April 21, 2026.

## Scope
This process covers:
- RTG stream transport changes (gRPC primary path, HTTP fallback, shadow mode)
- Sugar Glider dispatcher mode and ACK batching behavior
- Platform configuration updates (compose and K8s configmap)
- Validation gates required before benchmark runs

This process does not change LIS/Cyrex/Helox write-path schemas.

## Repositories And Paths
- Platform repo: `/Users/Kyle/Developer/Deepiri/deepiri-platform`
- Alternate implementation workspace used in recent runs: `/Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard`
- Sugar Glider repo (standalone): `/Users/Kyle/Developer/Deepiri/deepiri-sugar-glider`

## Prerequisites
- Docker + Docker Compose plugin
- Node.js 18+ and npm 9+
- Go 1.24+
- Clean local ports for Redis/RTG/Sugar Glider (6379, 5008, 8081, 50051)

## Reproducible Workflow

### 1. Start from known git state
```bash
cd /Users/Kyle/Developer/Deepiri/deepiri-platform
git status

git submodule update --init --recursive
```

If using the extract-hard workspace for implementation/bench:
```bash
cd /Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard
git status
git submodule update --init --recursive
```

### 2. Implement RTG transport behavior
Primary file:
- `platform-services/backend/deepiri-realtime-gateway/src/streaming/eventConsumer.ts`

Required behaviors:
- Add explicit transport parsing:
  - `STREAM_TRANSPORT=sugar-glider-grpc` (primary)
  - `STREAM_TRANSPORT=sugar-glider-http` (fallback)
- Keep `STREAM_SHADOW_MODE` support:
  - when true, consume + ACK, but no Socket.IO emits
- Keep startup logging for:
  - selected transport
  - whether transport was explicitly configured
  - ACK tuning values
  - lazy payload parse status
- Keep gRPC ACK batching and adaptive low-traffic flush knobs.

### 3. Implement RTG config surface
Update RTG config defaults in:
- `docker-compose.dev.yml`
- `docker-compose.rtg-sugar-glider.local.yml`
- `docker-compose.rtg-sidecar.local.yml`
- `ops/k8s/configmaps/realtime-gateway-configmap.yaml`

Required envs:
- `SYNAPSE_SUGAR_GLIDER_URL`
- `SYNAPSE_SIDECAR_URL` (legacy alias kept)
- `SYNAPSE_GRPC_ADDR`
- `STREAM_TRANSPORT`
- `STREAM_SHADOW_MODE`
- `STREAM_CONSUMER_GROUP`
- `STREAM_CONSUMER_NAME`
- `STREAM_ACK_BATCH_SIZE`
- `STREAM_ACK_FLUSH_MS`
- `STREAM_ACK_LOW_TRAFFIC_FLUSH_MS`
- `STREAM_ACK_LOW_TRAFFIC_GAP_MS`
- `STREAM_ACK_LOW_TRAFFIC_MAX_PENDING`
- `STREAM_LAZY_PAYLOAD_PARSE`

### 4. Implement Sugar Glider dispatcher behavior
In Sugar Glider codebase (`platform-services/shared/deepiri-sugar-glider` submodule in platform repo, or standalone repo):
- `internal/config/config.go`
- `internal/service/consume.go`
- `internal/service/grpc.go`
- `internal/service/service.go`
- `internal/service/dispatcher.go`

Required behaviors:
- `SIDECAR_CONSUME_MODE` supports `stateless` and `dispatcher`
- Dispatcher keeps long-lived stream readers per `stream+consumer_group`
- ACK queue and periodic ACK flush batching
- Metrics include ack request counters and dispatcher dropped subscriber counters
- Consumer group ensure cache and retry on `NOGROUP` races

### 5. Keep docs in sync with implementation
Update RTG docs:
- `platform-services/backend/deepiri-realtime-gateway/README.md`

Document:
- transport selection (`grpc`/`http`)
- shadow mode semantics
- canary group guidance
- rollback env settings

### 6. Build and gate validation
From platform repo:
```bash
cd /Users/Kyle/Developer/Deepiri/deepiri-platform

# RTG TypeScript build
cd platform-services/backend/deepiri-realtime-gateway
npm run build
cd ../../../..

# Full transport gate
make rtg-gate-full
```

From Sugar Glider repo:
```bash
cd /Users/Kyle/Developer/Deepiri/deepiri-sugar-glider
go test ./...
```

### 7. Record reproducibility metadata
For every implementation validation run, capture:
- git commit SHA
- git branch
- dirty/clean state
- command executed
- UTC timestamp
- workspace path

Store this in PR body and benchmark manifest references.

## Rollback Procedure
Rollback is env-only for RTG path:
```bash
STREAM_TRANSPORT=sugar-glider-http
STREAM_SHADOW_MODE=false
```
Restart RTG deployment after env update.

If rollback is canary-only, scale canary workload to zero and keep primary untouched.

## Completion Checklist
- [ ] RTG gRPC path selectable and logged at startup
- [ ] HTTP fallback remains functional
- [ ] Shadow mode consumes and ACKs without emitting sockets
- [ ] Dispatcher mode active and stable
- [ ] `make rtg-gate-full` passes
- [ ] `go test ./...` in Sugar Glider passes
- [ ] Docs updated in platform and Sugar Glider repos
