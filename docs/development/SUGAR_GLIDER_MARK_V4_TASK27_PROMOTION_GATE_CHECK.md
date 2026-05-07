# Sugar Glider Mark v4 - Task 27 Promotion Gate Check

Updated: 2026-04-28 (UTC)

## Objective

Apply the continuation gate after Tasks 24-26:

1. Heavy lanes (`32768 c10/c50`) must beat reference.
2. Guardrail lanes (`1024 c50`, `8192 c50`) must avoid regression.
3. Reliability must remain clean.

## Reference Run

- `benchmarks/end-to-end/20260426T225038Z-v4-websocket-native-full`

Reference aggregates:

- `32768 c10`: throughput `692.0681`, p95 `24.8782`
- `32768 c50`: throughput `749.3477`, p95 `105.7132`
- `1024 c50`: throughput `4586.5783`, p95 `20.7250`
- `8192 c50`: throughput `2401.9035`, p95 `31.1088`

## Candidate (Selected from Task 25/26)

Chosen candidate profile:

- RTG: `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`
- sidecar ACK profile: control (`256/8/6`, queue `16384`)

Heavy-lane candidate run:

- `benchmarks/end-to-end/20260429T010205Z-task25-rtg-emit-ab-a-extract-false`

Guardrail validation run (candidate config):

- `benchmarks/end-to-end/20260429T012900Z-task27-guardrail-c50-baselinecfg`

## Gate Results

### Heavy lanes (PASS)

- `32768 c10`:
  - candidate throughput `824.5159` vs ref `692.0681` (`+19.14%`)
  - candidate p95 `21.0582` vs ref `24.8782` (better)
- `32768 c50`:
  - candidate throughput `792.1837` vs ref `749.3477` (`+5.72%`)
  - candidate p95 `105.3770` vs ref `105.7132` (slightly better)

### Guardrail lanes (FAIL)

- `1024 c50`:
  - candidate throughput `3750.7776` vs ref `4586.5783` (`-18.22%`)
- `8192 c50`:
  - candidate throughput `2264.2134` vs ref `2401.9035` (`-5.73%`)

### Reliability (PASS)

- heavy and guardrail probes: `lost=0`, `failed=0`, `error=0`

## Decision

- Gate outcome: **NO-GO** for full-matrix promotion.
- Reason: heavy lanes improved, but guardrail throughput regressed beyond acceptable levels.

## Next Action

- Keep the RTG emit-path winner (`STREAM_EXTRACT_USER_FROM_PAYLOAD=false`).
- Revisit sidecar/RTG low-payload behavior before launching the next full-matrix rerun.
