# Sugar Glider Mark v3 - Task 03 Pipeline Candidate Probe

Updated: 2026-04-24 (UTC)

## Objective

Run the current publish-pipeline candidate against the same targeted heavy-path probe used for the Task 02 Mark v3 control.

## Run

- Run ID:
  - `20260425T035753Z-pipeline-enabled-heavy-probe`
- Probe command:
  - `node scripts/dev/sugarglider/e2e_gateway_probe.js --out-dir benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe`
- Config:
  - `SIDECAR_PUBLISH_PIPELINE_ENABLED=true`
- Matrix:
  - payload: `32768`
  - concurrency: `1,10`
  - repetitions: `5`
  - warmup ops: `500`
  - measure ops: `5000`

## Results vs Task 02 Control

| Cell | Control Throughput | Candidate Throughput | Candidate/Control | Control p95 | Candidate p95 | Candidate/Control p95 | Reliability |
|---|---:|---:|---:|---:|---:|---:|---|
| `32768B @ c=1` | `295.4990 ops/s` | `277.9572 ops/s` | `0.9406x` | `5.4277 ms` | `5.9344 ms` | `1.0933x` | clean |
| `32768B @ c=10` | `710.5128 ops/s` | `694.6417 ops/s` | `0.9777x` | `22.8464 ms` | `22.9928 ms` | `1.0064x` | clean |

Reliability:

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Results vs 2026-04-12 Baseline

- `32768B @ c=1`: `1.3532x`, p95 `0.9007x`
- `32768B @ c=10`: `2.0730x`, p95 `0.5635x`

## Decision

Do not promote this current pipeline-enabled candidate. It is reliable, but it loses to the same-machine Mark v3 control in both targeted cells.

## Artifacts

- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe/report.md`
- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe/summary.csv`
- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe/comparison_subset_vs_control.csv`
- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe/comparison_subset_vs_control.md`
- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe/comparison_subset_vs_20260412.csv`
- `benchmarks/end-to-end/20260425T035753Z-pipeline-enabled-heavy-probe/comparison_subset_vs_20260412.md`

## Outcome

Task 03 completed. Proceed to Task 04: implement adaptive publish behavior that keeps direct publish for low-pressure cells and only uses pipeline coalescing when it can prove benefit.

