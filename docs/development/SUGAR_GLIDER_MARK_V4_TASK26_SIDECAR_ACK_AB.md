# Sugar Glider Mark v4 - Task 26 Sidecar ACK A/B

Updated: 2026-04-28 (UTC)

## Objective

Run a targeted sidecar ACK pipeline micro A/B after Task 25 winner settings to test whether a more aggressive ACK profile improves heavy websocket throughput without reliability regressions.

## Variants

Control profile (from Task 25 winner run):

- `SIDECAR_DISPATCHER_ACK_BATCH_SIZE=256`
- `SIDECAR_DISPATCHER_ACK_FLUSH_CONCURRENCY=8`
- `SIDECAR_DISPATCHER_ACK_FLUSH_MS=6`
- `SIDECAR_DISPATCHER_ACK_QUEUE_SIZE=16384`

Tuned profile:

- `SIDECAR_DISPATCHER_ACK_BATCH_SIZE=512`
- `SIDECAR_DISPATCHER_ACK_FLUSH_CONCURRENCY=12`
- `SIDECAR_DISPATCHER_ACK_FLUSH_MS=4`
- `SIDECAR_DISPATCHER_ACK_QUEUE_SIZE=32768`

Shared RTG controls:

- `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`
- `SOCKET_IO_TRANSPORTS=websocket`

## Runs

- Control reference:
  - `benchmarks/end-to-end/20260429T010205Z-task25-rtg-emit-ab-a-extract-false`
- Tuned:
  - `benchmarks/end-to-end/20260429T012348Z-task26-sidecar-ack-ab-b-tuned`

## Results

### Throughput (ops/s)

- `32768 c10`:
  - control: `824.5159`
  - tuned: `723.6892`
  - tuned/control: `0.8777x` (worse)
- `32768 c50`:
  - control: `792.1837`
  - tuned: `799.1381`
  - tuned/control: `1.0088x` (slightly better)
- mean heavy-lane throughput ratio (tuned/control): `0.9419x`

### p95 (ms)

- `32768 c10`:
  - control: `21.0582`
  - tuned: `23.8840`
  - tuned/control: `1.1342x` (worse)
- `32768 c50`:
  - control: `105.3770`
  - tuned: `89.8515`
  - tuned/control: `0.8527x` (better)

Reliability stayed clean in both runs (`lost=0`, `failed=0`, `error=0`).

## Interpretation

- The tuned ACK profile improves one heavy lane (`c50`) but regresses `c10` enough to lose overall heavy mean throughput.
- Control profile remains the better general heavy-lane setting.

## Outcome

Task 26 completed. Sidecar ACK tuned variant is not promoted; keep control ACK profile for next gate step.
