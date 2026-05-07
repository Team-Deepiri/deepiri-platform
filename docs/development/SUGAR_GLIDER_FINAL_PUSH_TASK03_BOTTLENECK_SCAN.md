# Sugar Glider Final Push - Task 03 Bottleneck Scan

Updated: 2026-04-23 (UTC)

## Scope

Bottleneck scan for the fixed Mark v3 reference runs:

- `benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed`
- `benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`

Analyzed data sources:

- 54 raw end-to-end artifacts (`end_to_end_p*_c*_r*.json`)
- fixed-run comparison files vs April 12 baseline
- RTG gRPC consumer ack path config/code
- Sugar Glider dispatcher read/ack config/code

## Method

- For each cell (`payload x concurrency`), compute mean p95 total latency and mean p95 publish latency across 3 repetitions.
- Derive inferred downstream p95 share:
  - `downstream_p95 = total_p95 - publish_p95`
  - `downstream_share = downstream_p95 / total_p95`
- Identify top non-publish p95 hotspot scenarios.
- Estimate Redis command pressure from event volume (`148500` events per full run) and current batch sizes.

## Findings

### 1) Publish Is Not The Main Tail Bottleneck In Heavy Cells

Across both fixed runs:

- mean p95 publish share: `43.2% - 43.9%`
- mean p95 downstream share: `56.1% - 56.8%`

Heavy path (`32768B`) highlights:

- `c=50` publish share: `21.8% - 24.6%` of p95
- `c=50` downstream share: `75.4% - 78.2%` of p95

Interpretation:

- in high-load heavy payload traffic, most p95 latency lives after publish (dispatcher/read/ack/emit path), not in the publish call itself.

### 2) Highest Non-Publish Tail Hotspots

Top non-publish p95 scenarios:

- fixed run 1:
  - `p32768_c50_r1`: non-publish p95 `74.16 ms`
  - `p32768_c50_r2`: non-publish p95 `73.56 ms`
- fixed run 2:
  - `p32768_c50_r1`: non-publish p95 `114.30 ms`
  - `p32768_c50_r3`: non-publish p95 `93.87 ms`

Interpretation:

- heavy payload + high concurrency tail variance is the primary throughput and stability pressure zone.

### 3) Ack Path Architecture (Current)

Current pipeline has two ack aggregation layers:

- RTG gRPC consumer:
  - `STREAM_ACK_BATCH_SIZE=256`
  - `STREAM_ACK_FLUSH_MS=6`
  - `STREAM_ACK_FLUSH_CONCURRENCY=8`
  - low-traffic fast flush mode enabled
- Sugar Glider dispatcher:
  - `SIDECAR_DISPATCHER_ACK_BATCH_SIZE=256`
  - `SIDECAR_DISPATCHER_ACK_FLUSH_MS=6`
  - `SIDECAR_DISPATCHER_ACK_FLUSH_CONCURRENCY=8`
  - `SIDECAR_DISPATCHER_ACK_QUEUE_SIZE=16384`
  - XACK chunk batches are pipelined in Redis

Risk surfaces:

- ack queue backlog (`errDispatcherAckBacklog`) under bursty delivery
- extra timing/coordination variance from two-layer ack flushing

### 4) Redis Command Pressure (Estimated Envelope)

For one full run (`148500` events):

- XADD lower bound: `148500` calls (currently 1 publish request -> 1 Redis XADD)
- RTG->sidecar Ack RPC envelope:
  - minimum if always full 256 batches: `581` calls
  - worst case (no batching): `148500` calls
- Sidecar XACK envelope:
  - minimum if always full 256 chunks: `581` calls
  - worst case (single-entry acks): `148500` calls
- XREADGROUP theoretical minimum at read count 512: `291` calls (real count can be higher)

Interpretation:

- publish command volume is guaranteed high and unbatched today
- ack and read command pressure depends heavily on batching efficiency during each run

### 5) Measurement Gap To Close

Current end-to-end artifacts capture total and publish latencies but do not directly separate:

- dispatcher read wait
- RTG emit queue delay
- sidecar ack queue depth/flush efficiency
- Redis per-command runtime and call counts during the run

This limits certainty when attributing non-publish tail spikes inside the downstream path.

## Task 03 Outcome

Task 03 is complete. The primary optimization hotspot is downstream heavy-path tail (`32768B @ c=50`), with publish still relevant but not dominant in p95 under load.

This finding should be carried into Task 04 design choices.
