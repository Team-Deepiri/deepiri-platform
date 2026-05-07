# Sugar Glider Mark v4 - Task 32 Breakthrough Tracks

Updated: 2026-05-02 (UTC)

## Objective

Open the next Mark v4 speed tracks without destabilizing the promoted Task 31 profile. The implementation keeps current V4 behavior as the default and adds explicit lab switches for lane-aware profiling, Socket.IO parser experiments, ACK compression measurement, and direct broadcast fast-path testing.

## Baseline Guard

Task 31 remains the promoted profile:

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

The new breakthrough flags default to no-op values:

```bash
STREAM_LANE_RUNTIME_PROFILES_ENABLED=false
STREAM_DIRECT_BROADCAST_FAST_PATH=off
STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES=0
SOCKET_IO_PARSER=default
SOCKET_IO_DISCARD_INITIAL_REQUEST=false
```

## Implemented Tracks

| Track | Implementation | Default Risk | Classification |
|---|---|---:|---|
| Lane-aware runtime profiles | RTG now classifies evaluated events into `small`, `mid`, and `heavy` lanes and reports counters under `/health` -> `streaming.runtime_breakthroughs`. | No behavior change while disabled. | Production-safe observability when enabled. |
| Socket.IO binary / MessagePack | `SOCKET_IO_PARSER=msgpack` attempts to load `socket.io-msgpack-parser`; if unavailable, RTG falls back to the default parser and reports the reason in health. | No behavior change by default. | Lab-only until every client uses the matching parser. |
| ACK compression opportunities | Sugar Glider exposes dispatcher ACK input, deduped, duplicate, contiguous-span, and theoretical saved-entry counters in `/v1/config` and Prometheus. | Measurement only. | Production-safe observability. |
| Direct broadcast fast path | `STREAM_DIRECT_BROADCAST_FAST_PATH=payload` emits raw payloads; `payload-json` parses string payloads before emit. It only activates when `STREAM_EXTRACT_USER_FROM_PAYLOAD=false` and no `user_id` route is present. | Off by default. | Lab-only until client wire contract is approved. |
| Socket memory lever | `SOCKET_IO_DISCARD_INITIAL_REQUEST=true` drops the retained initial HTTP request reference after connection. | Off by default. | Production-safe if RTG does not use request/session middleware data. |

## Scientific Read

The current V4 speed pattern is consistent with avoiding per-event work:

- Task 25 showed `STREAM_EXTRACT_USER_FROM_PAYLOAD=false` wins because heavy broadcast lanes avoid payload scanning/parsing.
- Task 26/31 showed ACK batching works because Redis/sidecar ACK cost is amortized through larger batches and concurrent flushes.
- Socket.IO docs confirm MessagePack/custom parsers are useful mainly when binary payloads or frame count dominate.
- Redis `XACK` accepts multiple IDs, but it is still per-ID work; the new contiguous-span counters quantify whether a deeper ACK strategy is worth researching.

## Benchmark Plan For These Tracks

1. `lane-observe`: enable `STREAM_LANE_RUNTIME_PROFILES_ENABLED=true` with the Task 31 profile and run a short matrix to verify lane counters are clean.
2. `msgpack-lab`: install/add `socket.io-msgpack-parser` and test `SOCKET_IO_PARSER=msgpack` with a client using the same parser.
3. `ack-opportunity`: run the heavy lanes and compare `dispatcher_ack_input_entries`, `dispatcher_ack_deduped_entries`, and `dispatcher_ack_contiguous_saved_entries`.
4. `direct-heavy-raw`: test `STREAM_DIRECT_BROADCAST_FAST_PATH=payload` with a client that accepts raw payloads.
5. `direct-heavy-json`: test `STREAM_DIRECT_BROADCAST_FAST_PATH=payload-json` for benchmark compatibility, then reject it if parse cost cancels the emit savings.

## Acceptance Notes

- Task 31 release defaults are unchanged.
- Every breakthrough track is behind an explicit flag.
- Guardrail lanes are protected by default because direct broadcast remains off.
- Full promotion still requires a new frozen V3 vs candidate full matrix after any lab flag becomes a candidate.

## Validation

- `go test ./...` passed in `platform-services/shared/deepiri-sugar-glider`.
- `npm --workspace platform-services/backend/deepiri-realtime-gateway run build` passed after correcting the local `node_modules/@deepiri/shared-utils` workspace symlink.
- `docker compose config --quiet` passed for `docker-compose.rtg-sugar-glider.local.yml`, `docker-compose.rtg-sidecar.local.yml`, and `docker-compose.dev.yml` (dev compose emitted only expected missing-secret warnings).

## References

- Socket.IO custom parser docs: https://socket.io/docs/v4/custom-parser/
- Socket.IO performance tuning docs: https://socket.io/docs/v4/performance-tuning/
- Redis XACK docs: https://redis.io/docs/latest/commands/xack/
- Redis pipelining docs: https://redis.io/docs/latest/develop/using-commands/pipelining/
