# Sugar Glider Mark v4 - Task 19 V3 Speed Signature

Updated: 2026-04-27 (UTC)

## Objective

Run a reproducible signature comparison between locked Mark v3 and latest Mark v4 fast-path runs to quantify where throughput was lost and where p95 latency moved.

## Inputs

Control (Mark v3 locked pair):

- `benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed`
- `benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`

Candidate (Mark v4 fast-path pair):

- `benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1`
- `benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2`

## Implementation

Added analyzer:

- `scripts/dev/sugarglider/analyze_v3_v4_speed_signature.js`

What it computes:

- cell-level throughput and p95 deltas (`payload x concurrency`)
- publish-vs-downstream p95 share shift
- throughput variance (`cv%`) shift
- run-level mean throughput ratio vs `2026-04-12` baseline (when comparison files exist)

## Run

Command:

```bash
node scripts/dev/sugarglider/analyze_v3_v4_speed_signature.js
```

Output package:

- `benchmarks/end-to-end/20260427T031455Z-task3-v3-v4-speed-signature/v3_v4_speed_signature.csv`
- `benchmarks/end-to-end/20260427T031455Z-task3-v3-v4-speed-signature/v3_v4_speed_signature.md`

## Key Metrics

From the generated report:

- Mean throughput ratio (candidate/control): `0.8914x`
- Mean p95 ratio (candidate/control): `1.2488x`
- Heavy-path throughput ratio (`32768B` cells): `0.7102x`
- Heavy-path p95 ratio (`32768B` cells): `1.4029x`
- Heavy-path publish share shift: `-2.94 pp`
- Heavy-path downstream share shift: `+2.94 pp`

Heavy-path cells:

- `32768B @ c=1`: throughput `0.8930x`, p95 `1.0249x`, publish-share `+11.18 pp`
- `32768B @ c=10`: throughput `0.6716x`, p95 `1.5078x`, publish-share `-5.97 pp`
- `32768B @ c=50`: throughput `0.5660x`, p95 `1.6759x`, publish-share `-14.02 pp`

## Pattern Readout

- Mark v4 fast-path is currently slower than locked Mark v3 on most cells, with the biggest losses in heavy/high-load cells.
- In heavy cells, publish share drops while downstream share rises, which points to delivery/dispatch/ack path pressure as the dominant bottleneck.
- Throughput variance does not explain the main regression; tail growth and lower downstream efficiency do.

## Outcome

Task 19 completed. We now have an executable signature tool and a concrete, artifact-backed explanation for why locked Mark v3 remains faster than current Mark v4 fast-path runs.
