# Sugar Glider Mark v4 - Task 33 Release Readiness

Updated: 2026-05-02 (UTC)

## Decision

Mark v4 is **GO** as the replacement for Mark v3 using the locked Task 31 profile.

## Locked Shipping Profile

```bash
STREAM_SUBSCRIBE_BATCH_SIZE=128
STREAM_EVENT_MAX_IN_FLIGHT=1024
STREAM_EVENT_RESUME_IN_FLIGHT=768
SIDECAR_DISPATCHER_READ_COUNT=512
SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER=1024
STREAM_EXTRACT_USER_FROM_PAYLOAD=false
SIDECAR_DISPATCHER_ACK_BATCH_SIZE=256
SIDECAR_DISPATCHER_ACK_FLUSH_CONCURRENCY=8
SIDECAR_DISPATCHER_ACK_FLUSH_MS=6
SIDECAR_DISPATCHER_ACK_QUEUE_SIZE=16384
```

Task 32 breakthrough switches remain off for release:

```bash
STREAM_LANE_RUNTIME_PROFILES_ENABLED=false
STREAM_DIRECT_BROADCAST_FAST_PATH=off
STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES=0
SOCKET_IO_PARSER=default
SOCKET_IO_DISCARD_INITIAL_REQUEST=false
```

## Throughput Position

- Versus frozen Mark v3 controls: mean `2.1101x` (worst required lane `1.5472x`), full-matrix `9/9` pass, reliability clean.
- Versus original April baseline (`20260412T052514Z`): average per-cell `5.4744x` (+447.4%), aggregate `6.4261x` (+542.6%).

## Release Validation

Executed and passing:

- `npm --workspace platform-services/backend/deepiri-realtime-gateway run build`
- `go test ./...` (from `platform-services/shared/deepiri-sugar-glider`)
- `make rtg-sugar-gate`

Runtime confirmation from `GET /health`:

- `socket_io.parser.requested=default`, `active=default`
- `streaming.runtime_breakthroughs.lane_runtime_profiles_enabled=false`
- `streaming.runtime_breakthroughs.direct_broadcast_fast_path.mode=off`

## Gate Reliability Fix

The fast gate previously flaked because smoke groups could begin from backlog origin on `platform-events`.  
`rtg-gate` now pre-creates dedicated smoke groups at stream tail (`$`) before running:

- HTTP smoke
- gRPC smoke

This makes `make rtg-sugar-gate` deterministic under high stream history volume.

## Branch / PR Workflow Guard

Per team branch workflow:

- Do not merge directly to `main`, `dev`, or team-dev branches.
- Submit PRs from personal/feature branch to the appropriate dev branch.
- QA validates on `dev`; only after QA approval should `dev -> main` be merged by release authority.

## Release Recommendation

Proceed with Mark v4 release PR package now:

1. Include Task 31 promotion artifacts and this Task 33 readiness note.
2. Keep Task 32 breakthrough flags disabled in production.
3. Keep Mark v3 freeze profile available as rollback until QA and release signoff complete.
