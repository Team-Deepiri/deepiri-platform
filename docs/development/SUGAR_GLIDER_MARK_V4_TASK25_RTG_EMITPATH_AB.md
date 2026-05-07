# Sugar Glider Mark v4 - Task 25 RTG Emit-Path A/B

Updated: 2026-04-28 (UTC)

## Objective

Run a targeted RTG emit-path micro A/B on heavy websocket lanes to test whether payload user-extraction overhead is contributing to downstream latency pressure.

## Variants

- Variant A (control):
  - `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`
- Variant B:
  - `STREAM_EXTRACT_USER_FROM_PAYLOAD=true`

Shared controls:

- `SOCKET_IO_TRANSPORTS=websocket`
- `STREAM_SOCKET_HOTPATH_PROFILE_ENABLED=true`
- payload/concurrency matrix: `32768` at `c10,c50`
- warmup `200`, measure `3000`, repetitions `3`

## Runs

- A:
  - `benchmarks/end-to-end/20260429T010205Z-task25-rtg-emit-ab-a-extract-false`
- B:
  - `benchmarks/end-to-end/20260429T012025Z-task25-rtg-emit-ab-b-extract-true`

## Results

### Aggregated Throughput (ops/s)

- `32768 c10`:
  - A: `824.5159`
  - B: `445.3501`
  - A/B ratio: `1.8514x` in favor of A
- `32768 c50`:
  - A: `792.1837`
  - B: `493.9397`
  - A/B ratio: `1.6038x` in favor of A
- mean heavy-lane throughput ratio (A/B): `1.7212x`

### Aggregated p95 (ms)

- `32768 c10`:
  - A: `21.0582`
  - B: `41.8040`
  - B/A ratio: `1.9852x` (B worse)
- `32768 c50`:
  - A: `105.3770`
  - B: `159.0238`
  - B/A ratio: `1.5091x` (B worse)

Reliability stayed clean in both runs (`lost=0`, `failed=0`, `error=0`).

## Interpretation

- Enabling payload user-extraction (`true`) significantly regressed heavy-lane throughput and p95.
- For this benchmark traffic shape, RTG should remain on `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`.

## Outcome

Task 25 completed. Variant A (`false`) is the clear winner and is selected as the RTG emit-path setting for further rollout steps.
