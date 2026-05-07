# Sugar Glider Mark v4 - Task 15 Fast-Path Decision Note

Updated: 2026-04-27 (UTC)

## Decision

**No-go for promotion of the restored fast-path profile as the new Mark v4 baseline.**

## Why

The fast-path iteration improves over autoplay Tasks 08/09, but still does not meet the throughput target.

- target: exceed `2.7x` throughput baseline
- achieved:
  - run 1: `2.1314x`
  - run 2: `2.2073x`
  - pair mean: `2.1694x`

It is also still behind reference checkpoints:

- vs Mark v3 fixed repeat2:
  - pair mean throughput ratio: `0.8885x`
- vs prior v4 websocket-native full:
  - pair mean throughput ratio: `0.6073x`

## Reliability Status

Both full runs remained clean:

- `lost_events=0`
- `failed_ops=0`
- `error_rate_pct=0`

## Operational Recommendation

- Keep the stronger historical websocket-native reference as performance anchor:
  - `benchmarks/end-to-end/20260426T225038Z-v4-websocket-native-full`
- Keep this restored fast-path profile as a better fallback than autoplay Task 08/09 when rerunning local experiments.

## Next Iteration Focus

1. Investigate non-knob bottlenecks: publisher path and socket delivery hot sections under load.
2. Capture CPU/memory and event-loop profiles during `1024/8192 c50` and `32768 c10/c50` scenarios.
3. Only re-run full matrix after targeted probes show lift over `20260426T225038Z-v4-websocket-native-full`.

## Outcome

Task 15 completed (decision recorded).

