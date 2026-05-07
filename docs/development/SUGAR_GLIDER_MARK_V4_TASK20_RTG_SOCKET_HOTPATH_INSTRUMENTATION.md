# Sugar Glider Mark v4 - Task 20 RTG Socket Hot-Path Instrumentation

Updated: 2026-04-27 (UTC)

## Objective

Implement lightweight RTG instrumentation to quantify parse/dispatch/emit CPU-time signatures per benchmark bucket, with default focus on heavy-path buckets `32768:10` and `32768:50`.

## Implementation

Updated files:

- `platform-services/backend/deepiri-realtime-gateway/src/streaming/eventConsumer.ts`
- `platform-services/backend/deepiri-realtime-gateway/src/server.ts`
- `platform-services/backend/deepiri-realtime-gateway/README.md`

### What was added

1. In-memory hot-path profiler in RTG stream consumer:
   - parse stage timing around `normalizeGrpcEvent(...)`
   - dispatch/emit stage timing around Socket.IO routing + `emit(...)`
   - per-bucket aggregation keyed by `payload:concurrency`

2. Benchmark bucket detection:
   - parses `bench_scenario_id` from benchmark payloads
   - extracts bucket from scenario ids like `twebsocket-p32768-c50-r1`

3. Lightweight sampling:
   - per-stage reservoir sampling for p95 estimation
   - counters track total/avg/max/p95 and event counts per bucket

4. Visibility endpoints:
   - `GET /health` now includes compact hot-path profile summary
   - `GET /v1/streaming/profile` returns full snapshot

## Runtime Controls

- `STREAM_SOCKET_HOTPATH_PROFILE_ENABLED`  
  default: `false`
- `STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS`  
  default: `32768:10,32768:50`  
  format: `payload:concurrency` CSV, or `*` for all detected benchmark buckets
- `STREAM_SOCKET_HOTPATH_PROFILE_SAMPLE_LIMIT`  
  default: `2048`

## Example

```bash
STREAM_SOCKET_HOTPATH_PROFILE_ENABLED=true \
STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS=32768:10,32768:50 \
docker compose up -d realtime-gateway

curl -s http://localhost:5008/v1/streaming/profile | jq .
```

## Outcome

Task 20 completed. RTG now exposes direct evidence for where time is spent in the socket-delivery hot path so Task 5/6 tuning can target measured bottlenecks rather than inferred ones.
