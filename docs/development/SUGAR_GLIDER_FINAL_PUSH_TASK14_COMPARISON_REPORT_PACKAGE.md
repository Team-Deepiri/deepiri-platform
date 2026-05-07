# Sugar Glider Final Push - Task 14 Comparison Report Package

Updated: 2026-04-24 (UTC)

## Objective

Package final-push benchmark comparisons for decision review.

## Included Runs

- Run 1:
  - `20260424T033729Z-heavy-path-boost-v3-pipeline-enabled-run1`
- Run 2:
  - `20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2`

## Comparison Artifacts

Generated for each run against baseline `20260412T052514Z`:

- `comparison_vs_20260412.csv`
- `comparison_vs_20260412.md`

## Consolidated Metrics

| Metric | Run 1 | Run 2 | Pair Mean |
|---|---:|---:|---:|
| Average throughput ratio vs 2026-04-12 | `2.6072x` | `2.8015x` | `2.7044x` |
| p95 pass rate (`<=1.20x` baseline) | `9/9` | `9/9` | n/a |
| `32768B @ c=1` throughput ratio | `1.1890x` | `1.1909x` | n/a |
| `32768B @ c=10` throughput ratio | `1.8587x` | `1.8558x` | n/a |
| `32768B @ c=50` throughput ratio | `2.1838x` | `2.4871x` | n/a |

## Contract Check vs Task 02 Gates

- Run average `>=2.71` on both runs:
  - FAIL (`run1=2.6072x`)
- Pair mean `>=2.73`:
  - FAIL (`2.7044x`)
- Heavy-path min checks on both runs:
  - `32768B @ c=1 >=1.2229`: FAIL (both runs)
  - `32768B @ c=10 >=1.9372`: FAIL (both runs)
  - `32768B @ c=50 >=2.0511`: PASS (both runs)
- p95 `9/9`:
  - PASS (both runs)
- Reliability:
  - PASS (`lost_events=0`, `failed_ops=0`, `error_rate_pct=0`)

## Outcome

Task 14 completed (comparison package assembled, gates evaluated).

