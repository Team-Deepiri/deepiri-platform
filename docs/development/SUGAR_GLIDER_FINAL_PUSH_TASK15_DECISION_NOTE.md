# Sugar Glider Final Push - Task 15 Decision Note

Updated: 2026-04-24 (UTC)

## Decision

**No-go for this pipeline-enabled candidate as the new Mark v3 replacement baseline.**

Reason:

- The final-push pass/fail contract from Task 02 was not met.

## Evidence Summary

Candidate runs:

- `20260424T033729Z-heavy-path-boost-v3-pipeline-enabled-run1`
- `20260424T034156Z-heavy-path-boost-v3-pipeline-enabled-run2`

Results:

- Reliability remained clean on both runs:
  - `lost_events=0`
  - `failed_ops=0`
  - `error_rate_pct=0`
- Throughput gate failure:
  - run averages: `2.6072x`, `2.8015x` (required both `>=2.71`)
  - pair mean: `2.7044x` (required `>=2.73`)
- Heavy-path floor failure on both runs:
  - `32768B @ c=1`: `1.1890x`, `1.1909x` (required `>=1.2229`)
  - `32768B @ c=10`: `1.8587x`, `1.8558x` (required `>=1.9372`)
- Tail-latency guardrail remained strong:
  - p95 pass at `<=1.20x` baseline was `9/9` on both runs.

## Operational Recommendation

Keep the previously locked Mark v3 baseline as the active reference:

- `20260423T221540Z-heavy-path-boost-v3-fixed`
- `20260423T222329Z-heavy-path-boost-v3-fixed-repeat2`

## Next Iteration Focus

For a new candidate:

1. Keep reliability/p95 profile unchanged.
2. Improve low-concurrency heavy path (`32768B @ c=1` and `c=10`) before rerun.
3. Re-run two full matrices and re-check `>=2.71`/`>=2.73` gates.

## Outcome

Task 15 completed (decision recorded).

