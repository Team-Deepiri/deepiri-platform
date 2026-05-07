# Sugar Glider Mark v4 - Task 11 Decision Note

Updated: 2026-04-27 (UTC)

## Decision

**No-go for promotion of the current Task 06/07 tuned profile as the new Mark v4 baseline.**

## Why

The full-matrix websocket validation in Tasks 08/09 is reliable but does not meet the throughput target.

- target: exceed `2.7x` throughput baseline
- achieved:
  - run 1: `2.0636x`
  - run 2: `2.1747x`
  - pair mean: `2.1192x`

The same candidate is also slower than both reference checkpoints:

- vs Mark v3 fixed repeat2:
  - pair mean throughput ratio: `0.8640x`
- vs prior v4 websocket native full:
  - pair mean throughput ratio: `0.5862x`

## Reliability Status

Reliability remained clean in both full runs:

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Operational Recommendation

Keep the previously stronger websocket benchmark reference as the active Mark v4 performance anchor:

- `benchmarks/end-to-end/20260426T225038Z-v4-websocket-native-full`

Keep the tuning work from Task 06/07 as exploratory notes, not production-default performance claims.

## Next Iteration Focus

1. Revisit end-to-end bottlenecks outside dispatcher/RTG ACK tuning (publisher path and socket delivery overlap).
2. Add targeted profiling around `32768B c10/c50` delivery path under websocket.
3. Only re-run full matrix after a targeted probe shows clear lift over `20260426T225038Z-v4-websocket-native-full`.

## Outcome

Task 11 completed (decision recorded).

