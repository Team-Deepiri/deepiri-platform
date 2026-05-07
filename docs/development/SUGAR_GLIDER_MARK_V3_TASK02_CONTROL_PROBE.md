# Sugar Glider Mark v3 - Task 02 Control Probe

Updated: 2026-04-24 (UTC)

## Objective

Run the targeted heavy-path probe with publish pipeline disabled to establish this machine's current Mark v3 control behavior.

## Run

- Run ID:
  - `20260425T034824Z-mark-v3-control-heavy-probe`
- Probe command:
  - `node scripts/dev/sugarglider/e2e_gateway_probe.js --out-dir benchmarks/end-to-end/20260425T034824Z-mark-v3-control-heavy-probe`
- Config:
  - `SIDECAR_PUBLISH_PIPELINE_ENABLED=false`
- Matrix:
  - payload: `32768`
  - concurrency: `1,10`
  - repetitions: `5`
  - warmup ops: `500`
  - measure ops: `5000`

## Results vs 2026-04-12 Baseline

| Cell | Throughput | Throughput Ratio | p95 | p95 Ratio | Reliability |
|---|---:|---:|---:|---:|---|
| `32768B @ c=1` | `295.4990 ops/s` | `1.4386x` | `5.4277 ms` | `0.8238x` | clean |
| `32768B @ c=10` | `710.5128 ops/s` | `2.1204x` | `22.8464 ms` | `0.5600x` | clean |

Reliability:

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Notes

- The full-matrix comparison script rejected this run because the probe has `2` matrix cells while the baseline has `9`.
- A subset comparison artifact was written instead:
  - `benchmarks/end-to-end/20260425T034824Z-mark-v3-control-heavy-probe/comparison_subset_vs_20260412.csv`
  - `benchmarks/end-to-end/20260425T034824Z-mark-v3-control-heavy-probe/comparison_subset_vs_20260412.md`

## Outcome

Task 02 completed. This machine's Mark v3 control clears the targeted heavy-path floors and is ready for apples-to-apples candidate probes.

