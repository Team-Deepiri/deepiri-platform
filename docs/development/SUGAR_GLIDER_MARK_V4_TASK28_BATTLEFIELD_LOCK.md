# Sugar Glider Mark v4 - Task 28 Battlefield Lock

Updated: 2026-04-29 (UTC)

## Objective

Freeze the direct promotion battlefield by comparing the current Mark v4 candidate against the locked Mark v3 control pair, not just against prior Mark v4 reference runs.

## Locked Inputs

Mark v3 control runs:

- `benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed`
- `benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`

Current Mark v4 candidate runs:

- Heavy lanes: `benchmarks/end-to-end/20260429T010205Z-task25-rtg-emit-ab-a-extract-false`
- Guardrail lanes: `benchmarks/end-to-end/20260429T012900Z-task27-guardrail-c50-baselinecfg`

Candidate profile:

- RTG: `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`
- Sidecar ACK profile: control (`256/8/6`, queue `16384`)

## Generated Artifacts

Command:

```bash
node scripts/dev/sugarglider/analyze_v3_v4_speed_signature.js \
  --control-runs benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed,benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2 \
  --candidate-runs benchmarks/end-to-end/20260429T010205Z-task25-rtg-emit-ab-a-extract-false,benchmarks/end-to-end/20260429T012900Z-task27-guardrail-c50-baselinecfg \
  --out-dir benchmarks/end-to-end/20260429T015420Z-task28-v3-v4-battlefield-lock
```

Output package:

- `benchmarks/end-to-end/20260429T015420Z-task28-v3-v4-battlefield-lock/v3_v4_speed_signature.md`
- `benchmarks/end-to-end/20260429T015420Z-task28-v3-v4-battlefield-lock/v3_v4_speed_signature.csv`

## Battlefield Results

Matched cells: `4`

High-level ratios:

- Mean throughput ratio (candidate/control): `1.0775x`
- Mean p95 ratio (candidate/control): `0.9734x`
- Heavy-path throughput ratio (`32768B` cells): `1.1828x`
- Heavy-path p95 ratio (`32768B` cells): `0.8858x`

Cell gate:

| Cell | Lane | Throughput Ratio | p95 Ratio | Reliability | Status |
|---|---|---:|---:|---|---|
| `1024B @ c=50` | guardrail | `0.8627x` | `1.3253x` | clean | FAIL |
| `8192B @ c=50` | guardrail | `1.0815x` | `0.7966x` | clean | PASS |
| `32768B @ c=10` | heavy | `1.3282x` | `0.7766x` | clean | PASS |
| `32768B @ c=50` | heavy | `1.0375x` | `0.9950x` | clean | PASS |

Reliability stayed clean for the matched candidate cells (`lost=0`, `failed=0`, `error_rate_pct=0` in the candidate summaries; `reliability_regressed=false` in the generated comparison CSV).

## Untested Full-Matrix Cells

The current battlefield package is not a full-matrix promotion package. These frozen V3 cells still need current Mark v4 candidate coverage:

- `1024B @ c=1`
- `1024B @ c=10`
- `8192B @ c=1`
- `8192B @ c=10`
- `32768B @ c=1`

These cells are marked **UNTESTED**, not pass.

## Decision

Final battlefield status: **NO-GO**.

Reason:

- The candidate beats Mark v3 on `3/4` tested cells.
- The `1024B @ c=50` guardrail fails direct Mark v3 comparison at `0.8627x` throughput and `1.3253x` p95.
- The full matrix is incomplete, with `5/9` cells still untested for the current candidate.

Next recommended task:

- Start Task 29 with guardrail recovery, focused first on `1024B @ c=50`.
- Do not launch a full promotion rerun until the `1024B @ c=50` guardrail has a passing profile.
