# Sugar Glider Mark v4 - Task 23 Publish-to-Delivery Overlap

Updated: 2026-04-28 (UTC)

## Objective

Quantify how heavy-path latency splits between publish-side cost and downstream delivery cost using recent heavy websocket probe artifacts.

## Implementation

Added analyzer script:

- `scripts/dev/sugarglider/analyze_publish_delivery_overlap.js`

What it computes per payload/concurrency cell:

- throughput mean
- total p95 mean
- publish p95 mean
- downstream p95 mean (`total_p95 - publish_p95`)
- publish/downstream share percentages
- reliability means (`error`, `lost`, `failed`)

## Input Runs

- `benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1`
- `benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2`

## Command

```bash
node scripts/dev/sugarglider/analyze_publish_delivery_overlap.js
```

## Output Package

- `benchmarks/end-to-end/20260429T004207Z-task23-publish-delivery-overlap/publish_delivery_overlap_raw.csv`
- `benchmarks/end-to-end/20260429T004207Z-task23-publish-delivery-overlap/publish_delivery_overlap_by_run_and_cell.csv`
- `benchmarks/end-to-end/20260429T004207Z-task23-publish-delivery-overlap/publish_delivery_overlap_combined_cells.csv`
- `benchmarks/end-to-end/20260429T004207Z-task23-publish-delivery-overlap/publish_delivery_overlap_summary.md`

## Key Findings

Combined heavy-path cell view:

- `32768 c10`:
  - throughput mean: `396.3687 ops/s`
  - total p95 mean: `44.7097 ms`
  - publish p95 share: `40.16%`
  - downstream p95 share: `59.84%`
- `32768 c50`:
  - throughput mean: `400.2245 ops/s`
  - total p95 mean: `203.5858 ms`
  - publish p95 share: `10.19%`
  - downstream p95 share: `89.81%`

Reliability remained clean (`error=0`, `lost=0`, `failed=0`).

## Interpretation

- Under higher heavy-path concurrency (`c50`), latency is overwhelmingly downstream rather than publish-side.
- This reinforces Task 21 + Task 22 signals that the strongest next wins are in emit/dispatch/ack-delivery stages, not in basic publish correctness.

## Outcome

Task 23 completed with reproducible overlap artifacts and clear prioritization evidence for next micro A/B tuning.
