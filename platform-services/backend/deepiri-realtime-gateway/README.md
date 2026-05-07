# Realtime Gateway

Handles real-time communication and WebSocket connections.

## Responsibilities
- WebSocket server
- Real-time challenge updates
- Multiplayer sessions
- Presence tracking

## Events
- `connection` - Client connects
- `join_user_room` - Join user-specific room
- `join_adventure_room` - Join adventure room
- `challenge-update` - Challenge progress update
- `notification` - New notification

## Current Implementation
See `deepiri-core-api/server.js` for Socket.IO setup.

## Migration
Extract WebSocket functionality to this independent service.

## Streaming Flags
- `STREAM_TRANSPORT` selects stream consumption transport: `sugar-glider-grpc` or `sugar-glider-http` (rollback fallback). Set this explicitly in deploy configs.
- `STREAM_SHADOW_MODE` consumes and ACKs events without emitting Socket.IO events when `true` (default: `false`).
- `SYNAPSE_SUGAR_GLIDER_URL` sets the Sugar Glider base URL (preferred).
- `SYNAPSE_SIDECAR_URL` remains supported as a legacy fallback (default fallback target: `http://synapse-sugar-glider:8081`).
- `SYNAPSE_GRPC_ADDR` sets the Sugar Glider gRPC address (default fallback target: `synapse-sugar-glider:50051`).
- `STREAM_GRPC_KEEPALIVE_MS` sets the client keepalive interval for Sugar Glider gRPC (default: `300000` ms). Keep this conservative during benchmarks to avoid server-side excess-ping rejection.
- `STREAM_GRPC_KEEPALIVE_TIMEOUT_MS` sets the gRPC keepalive timeout (default: `20000` ms).
- `STREAM_GRPC_KEEPALIVE_PERMIT_WITHOUT_CALLS` allows keepalive pings when no RPC is active (default: `false`).
- `STREAM_CONSUMER_GROUP` sets the transport consumer group (default: `realtime-gateway`; when `STREAM_SHADOW_MODE=true` and unset, defaults to `realtime-gateway-sg-canary`).
- `STREAM_CONSUMER_NAME` sets the transport consumer name (default: `realtime-1`).
- `STREAM_SUBSCRIBE_BATCH_SIZE` sets gRPC subscribe batch size (default: `128`).
- `STREAM_EVENT_MAX_IN_FLIGHT` caps concurrent event-processing tasks per stream before pausing the gRPC stream (default: `1024`).
- `STREAM_EVENT_RESUME_IN_FLIGHT` resumes paused stream processing once in-flight tasks drop below this threshold (default: `768`).
- `STREAM_ACK_BATCH_SIZE` sets gRPC ack batch size for transport-side ack flush (default: `256`).
- `STREAM_ACK_FLUSH_MS` sets max flush window in milliseconds for pending ack entries (default: `6`).
- `STREAM_ACK_FLUSH_CONCURRENCY` sets max parallel ack chunk flushes per stream/group bucket (default: `8`).
- `STREAM_ACK_RETRY_MAX_ATTEMPTS` sets retry attempts for failed ack chunks (default: `3`).
- `STREAM_ACK_RETRY_BASE_MS` sets base retry backoff for failed ack chunks (default: `25` ms).
- `STREAM_ACK_LOW_TRAFFIC_FLUSH_MS` sets a shorter ack flush window used when traffic is sparse (default: `1`).
- `STREAM_ACK_LOW_TRAFFIC_GAP_MS` defines the minimum inter-event gap to consider traffic sparse (default: `16`).
- `STREAM_ACK_LOW_TRAFFIC_MAX_PENDING` caps pending ack entries for sparse-traffic mode (default: `32`).
- `STREAM_LAZY_PAYLOAD_PARSE` keeps payload as a raw string unless routing keys are detected (default: `true`).
- `STREAM_EXTRACT_USER_FROM_PAYLOAD` enables user id extraction from payload JSON for room routing (default: `true`; set `false` for pure broadcast-heavy lanes to reduce payload-scan overhead).
- `STREAM_LANE_RUNTIME_PROFILES_ENABLED` enables lane classification counters for small (`<=1024`), mid (`<=8192`), and heavy (`>8192`) benchmark payloads (default: `false`).
- `STREAM_DIRECT_BROADCAST_FAST_PATH` is a lab-only broadcast experiment. `off` preserves the envelope, `payload` emits the raw payload, and `payload-json` parses string payloads before emitting (default: `off`; only active when `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`).
- `STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES` limits direct broadcast fast path to payloads at or above the configured byte size (default: `0`).
- `STREAM_SOCKET_HOTPATH_PROFILE_ENABLED` enables lightweight per-bucket parse/dispatch/emit timing counters (default: `false`).
- `STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS` selects tracked benchmark buckets in `payload:concurrency` format (default: `32768:10,32768:50`; use `*` for all benchmark buckets).
- `STREAM_SOCKET_HOTPATH_PROFILE_SAMPLE_LIMIT` sets the per-stage sample reservoir limit used for p95 estimation (default: `2048`).
- `SOCKET_IO_PARSER` selects the Socket.IO parser. `default` is production-safe; `msgpack` is lab-only unless all clients use the same MessagePack parser bundle/package (default: `default`).
- `SOCKET_IO_DISCARD_INITIAL_REQUEST` discards Socket.IO's retained initial HTTP request reference after connection to reduce per-socket memory, only enable when the gateway does not need request/session middleware data (default: `false`).

Realtime Gateway now consumes streams via Sugar Glider (formerly sidecar). Redis remains part of the design, but only behind the transport service.
Local compose preserves `synapse-sidecar` as a network alias for backward compatibility.

## Observability Endpoints
- `GET /health` includes Socket.IO parser/addon status, `streaming.runtime_breakthroughs`, and a compact `streaming.socket_hotpath_profile` summary.
- `GET /v1/streaming/profile` returns the full hot-path timing snapshot for benchmark buckets.

## Canary And Rollback
- Stage 0 shadow canary:
  set `STREAM_TRANSPORT=sugar-glider-grpc`, `STREAM_SHADOW_MODE=true`, `STREAM_CONSUMER_GROUP=realtime-gateway-sg-canary`.
- Stage 1 limited live canary:
  set `STREAM_TRANSPORT=sugar-glider-grpc`, `STREAM_SHADOW_MODE=false`, and keep an isolated canary group.
- Rollback:
  set `STREAM_TRANSPORT=sugar-glider-http`, `STREAM_SHADOW_MODE=false`, then restart the RTG workload.

