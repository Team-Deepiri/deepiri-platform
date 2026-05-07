# Sugar Glider Mark v4 - Task 29 Guardrail Recovery

Updated: 2026-05-02 (UTC)

## Objective

Recover the Mark v4 guardrail lanes from Task 28 by keeping `STREAM_EXTRACT_USER_FROM_PAYLOAD=false` locked and sweeping the current RTG/sidecar flow-control knobs on `1024B @ c=50` and `8192B @ c=50`.

## Locked Baseline

Frozen Mark v3 guardrail thresholds from Task 28:

| Cell | Throughput Threshold | p95 Reference |
|---|---:|---:|
| `1024B @ c=50` | `4347.5529` | `17.0113` |
| `8192B @ c=50` | `2093.6253` | `38.8823` |

Candidate settings kept constant:

- `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`
- `STREAM_EVENT_MAX_IN_FLIGHT=1024`
- `STREAM_EVENT_RESUME_IN_FLIGHT=768`
- `SIDECAR_DISPATCHER_READ_COUNT=512`
- `SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER=1024`
- sidecar ACK control profile: `256/8/6`, queue `16384`
- publish pipeline disabled
- websocket transport only

## Sweep

Run group:

- `benchmarks/end-to-end/20260502T024312Z-task29-guardrail-recovery`

Probe shape:

- payloads: `1024,8192`
- concurrency: `50`
- transport: `websocket`
- warmup: `200`
- measure: `3000`
- repetitions: `3`

Swept knobs:

- `STREAM_SUBSCRIBE_BATCH_SIZE`: `64`, `128`, `256`, `512`
- `STREAM_EVENT_MAX_IN_FLIGHT` / `STREAM_EVENT_RESUME_IN_FLIGHT`: `512/384`, `1024/768`, `2048/1536`, `4096/3072`
- `SIDECAR_DISPATCHER_READ_COUNT`: `128`, `256`, `512`, `1024`
- `SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER`: `512`, `1024`, `2048`, `4096`

Summary artifacts:

- `benchmarks/end-to-end/20260502T024312Z-task29-guardrail-recovery/guardrail_sweep_summary.md`
- `benchmarks/end-to-end/20260502T024312Z-task29-guardrail-recovery/guardrail_sweep_summary.csv`
- `benchmarks/end-to-end/20260502T024312Z-task29-guardrail-recovery/guardrail_combined_config_summary.csv`

## Results

The original Task 28 `1024B @ c=50` failure did not reproduce after a clean Docker/service restart. The baseline profile now passed both guardrail lanes:

| Profile | Cell | Throughput | Ratio vs V3 | p95 | Reliability |
|---|---|---:|---:|---:|---|
| baseline | `1024B @ c=50` | `6625.7637` | `1.5240x` | `12.1308` | clean |
| baseline | `8192B @ c=50` | `2973.3515` | `1.4202x` | `26.4673` | clean |

Fastest single guardrail-safe sweep profile:

| Profile | SUB | MAX/RESUME | READ | BUFFER | `1024 c50` Ratio | `8192 c50` Ratio | Mean Ratio |
|---|---:|---|---:|---:|---:|---:|---:|
| `sub256` | `256` | `1024/768` | `512` | `1024` | `1.5293x` | `1.6642x` | `1.5967x` |

Confirmation:

| Profile | `1024 c50` Ratio | `8192 c50` Ratio | Mean Ratio | Reliability |
|---|---:|---:|---:|---|
| `sub256-confirm` | `1.3335x` | `1.2750x` | `1.3042x` | clean |
| `baseline-confirm` | `1.1951x` | `1.1840x` | `1.1895x` | clean |

Repeated-config readout:

| Config | Runs | `1024 c50` Ratio | `8192 c50` Ratio | Mean Ratio | Reliability |
|---|---:|---:|---:|---:|---|
| `sub256-combined` | `2` | `1.4314x` | `1.4696x` | `1.4505x` | clean |
| `baseline-combined` | `2` | `1.3596x` | `1.3021x` | `1.3308x` | clean |

## Decision

Guardrail recovery status: **PASS**.

Selected guardrail-safe candidate for the next heavy-preservation task:

```bash
STREAM_SUBSCRIBE_BATCH_SIZE=256
STREAM_EVENT_MAX_IN_FLIGHT=1024
STREAM_EVENT_RESUME_IN_FLIGHT=768
SIDECAR_DISPATCHER_READ_COUNT=512
SIDECAR_DISPATCHER_SUBSCRIBER_BUFFER=1024
STREAM_EXTRACT_USER_FROM_PAYLOAD=false
```

Reason:

- `sub256` was the fastest single guardrail-safe profile.
- `sub256` remained guardrail-safe on confirmation.
- The repeated-config readout favored `sub256` over baseline.
- Reliability stayed clean across the selected profile (`error_rate_pct=0`, `failed_ops=0`, `lost_events=0`).

Next step:

- Run Task 30 heavy preservation on `32768B @ c=10/c50` using the selected `sub256` profile.
- Do not promote Mark v4 until heavy preservation and later full-matrix gates pass.
