# Sugar Glider Final Push - Task 13 Full Benchmark Run 2

Updated: 2026-04-24 (UTC)

## Run Metadata

- Run ID:
  - `20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2`
- Candidate mode:
  - publish pipeline enabled (`SIDECAR_PUBLISH_PIPELINE_ENABLED=true`)
- Matrix:
  - payload: `1024/8192/32768`
  - concurrency: `1/10/50`
  - warmup: `500`
  - measure: `5000`
  - repetitions: `3`

## Reliability

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Throughput Against 2026-04-12 Baseline

From `comparison_vs_20260412.csv`:

- run average throughput ratio: `2.8015x`
- p95 pass rate at `<=1.20x` baseline: `9/9`
- heavy path throughput ratio:
  - `32768B @ c=1`: `1.1909x`
  - `32768B @ c=10`: `1.8558x`
  - `32768B @ c=50`: `2.4871x`

## Gate Snapshot (Task 02 Contract)

- Reliability gate: PASS
- Run average gate `>=2.71`: PASS
- Heavy-path min gate:
  - `32768B @ c=1 >=1.2229`: FAIL
  - `32768B @ c=10 >=1.9372`: FAIL
  - `32768B @ c=50 >=2.0511`: PASS
- p95 `9/9` gate: PASS

## Artifacts

- `benchmarks/end-to-end/20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2/report.md`
- `benchmarks/end-to-end/20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2/summary.csv`
- `benchmarks/end-to-end/20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2/comparison_vs_20260412.csv`
- `benchmarks/end-to-end/20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2/comparison_vs_20260412.md`

## Outcome

Task 13 completed (run executed and packaged).

