# Sugar Glider Mark v4 - Task 31 Full Matrix Promotion

Updated: 2026-05-02 (UTC)

## Objective

Run the full benchmark matrix twice with the locked Mark v4 profile, verify clean reliability, compare every lane against the frozen Mark v3 controls, and promote only if every required cell beats Mark v3.

## Locked Inputs

Frozen Mark v3 controls:

- `benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed`
- `benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`

Locked Mark v4 profile:

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

Run group:

- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion`

Full matrix repeats:

- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion/run1`
- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion/run2`

Matrix:

- payloads: `1024`, `8192`, `32768`
- concurrency: `1`, `10`, `50`
- transport: `websocket`
- warmup: `500`
- measure: `5000`
- repetitions per run: `3`
- full matrix repeats: `2`

## Promotion Gate

Artifacts:

- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion/v3_v4_promotion_table.md`
- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion/v3_v4_promotion_table.csv`
- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion/v3_v4_promotion_signature/v3_v4_speed_signature.md`

Gate summary:

- Final promotion status: **GO**
- Matched cells: `9`
- Candidate samples: `54` raw rows across two full matrices
- Reliability: **clean** (`lost=0`, `failed=0`, `error_rate_pct=0`)
- Mean throughput ratio (V4/V3): `2.1101x`
- Minimum throughput ratio (V4/V3): `1.5472x`
- Maximum throughput ratio (V4/V3): `3.0408x`
- Heavy-path mean throughput ratio: `1.7528x`
- Guardrail `c50` mean throughput ratio: `1.6912x`

Promotion table:

| Cell | V3 Throughput | V4 Throughput | V4/V3 | V3 p95 | V4 p95 | p95 Ratio | Gate |
|---|---:|---:|---:|---:|---:|---:|---|
| `1024B @ c=1` | `465.1736` | `1390.4227` | `2.9890x` | `3.7815` | `1.0466` | `0.2768x` | PASS |
| `1024B @ c=10` | `1786.1615` | `5431.3649` | `3.0408x` | `9.7458` | `3.2166` | `0.3300x` | PASS |
| `1024B @ c=50` | `4347.5529` | `7472.0742` | `1.7187x` | `17.0113` | `9.9377` | `0.5842x` | PASS |
| `8192B @ c=1` | `417.1171` | `925.8074` | `2.2195x` | `3.9351` | `1.6419` | `0.4173x` | PASS |
| `8192B @ c=10` | `1258.9842` | `2644.4176` | `2.1004x` | `12.5117` | `6.4089` | `0.5122x` | PASS |
| `8192B @ c=50` | `2093.6253` | `3483.1105` | `1.6637x` | `38.8823` | `20.8060` | `0.5351x` | PASS |
| `32768B @ c=1` | `259.7662` | `477.2509` | `1.8372x` | `6.3331` | `2.9367` | `0.4637x` | PASS |
| `32768B @ c=10` | `620.7950` | `1163.4491` | `1.8741x` | `27.1153` | `13.1502` | `0.4850x` | PASS |
| `32768B @ c=50` | `763.5534` | `1181.3579` | `1.5472x` | `105.9039` | `64.7464` | `0.6114x` | PASS |

## Decision

Promotion decision: **Mark v4 passes the full-matrix promotion gate**.

Reason:

- Every required lane beats frozen Mark v3 on throughput.
- Every required lane has clean reliability.
- Every required lane also improves p95 versus frozen Mark v3.
- The worst throughput lane is still `1.5472x` above frozen Mark v3.

Next step:

- Prepare the release/PR package for Mark v4 using the locked profile.
- Keep Mark v3 frozen as the rollback baseline until review, QA, and branch workflow approval are complete.
