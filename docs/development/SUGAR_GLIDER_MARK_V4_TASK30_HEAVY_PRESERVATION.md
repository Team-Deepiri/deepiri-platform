# Sugar Glider Mark v4 - Task 30 Heavy Preservation

Updated: 2026-05-02 (UTC)

## Objective

Protect the Mark v4 heavy-path win after Task 29 guardrail recovery by testing `32768B @ c=10` and `32768B @ c=50` on the selected guardrail profile, then comparing against both frozen Mark v3 and the current Mark v4 heavy winner.

## Inputs

Frozen Mark v3 controls:

- `benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed`
- `benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`

Current Mark v4 heavy winner:

- `benchmarks/end-to-end/20260429T010205Z-task25-rtg-emit-ab-a-extract-false`

Task 30 run group:

- `benchmarks/end-to-end/20260502T025459Z-task30-heavy-preservation`

Profiles tested:

- `sub256-heavy`: Task 29 guardrail candidate with `STREAM_SUBSCRIBE_BATCH_SIZE=256`
- `baseline-heavy-confirm`: fallback baseline with `STREAM_SUBSCRIBE_BATCH_SIZE=128`

Both profiles kept:

- `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`
- `STREAM_EVENT_MAX_IN_FLIGHT=1024`
- `STREAM_EVENT_RESUME_IN_FLIGHT=768`
- `SIDECAR_DISPATCHER_READ_COUNT=512`
- `SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER=1024`
- sidecar ACK control profile: `256/8/6`, queue `16384`
- publish pipeline disabled
- websocket transport only

## Heavy Results

| Profile | Cell | Throughput | p95 | vs Frozen V3 | vs V4 Heavy Winner | Reliability | Winner Gate |
|---|---|---:|---:|---:|---:|---|---|
| `sub256` | `32768:10` | `703.8823` | `23.5942` | `1.1338x` | `0.8537x` | clean | FAIL |
| `sub256` | `32768:50` | `836.0339` | `96.4903` | `1.0949x` | `1.0554x` | clean | PASS |
| `baseline-confirm` | `32768:10` | `712.5619` | `24.0757` | `1.1478x` | `0.8642x` | clean | FAIL |
| `baseline-confirm` | `32768:50` | `779.3035` | `99.0763` | `1.0206x` | `0.9837x` | clean | FAIL |
| `current-v4-heavy-winner` | `32768:10` | `824.5159` | `21.0582` | `1.3282x` | `1.0000x` | clean | PASS |
| `current-v4-heavy-winner` | `32768:50` | `792.1837` | `105.3770` | `1.0375x` | `1.0000x` | clean | PASS |

Task 29 guardrail evidence:

| Profile | `1024 c50` vs V3 | `8192 c50` vs V3 | Mean Guardrail Ratio | Reliability |
|---|---:|---:|---:|---|
| `sub256-combined` | `1.4314x` | `1.4696x` | `1.4505x` | clean |
| `baseline-combined` | `1.3596x` | `1.3021x` | `1.3308x` | clean |

## Decision

Heavy-preservation status: **guardrail-tuned profile rejected**.

Rejected:

- `STREAM_SUBSCRIBE_BATCH_SIZE=256`
- Reason: it saved guardrails but lost `32768B @ c=10` versus the current Mark v4 heavy winner (`0.8537x`).

Locked profile for the next validation gate:

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

Rationale:

- The baseline profile is the profile behind the current Mark v4 heavy winner.
- Task 29 showed the baseline profile is guardrail-safe after a clean Docker/service restart.
- No newly tested guardrail-tuned profile displaced the current heavy winner without losing heavy-path gains.

Next step:

- Run the full matrix on the locked baseline heavy-winner profile.
- Promotion remains blocked until the full matrix confirms all required lanes beat frozen Mark v3 with clean reliability.
