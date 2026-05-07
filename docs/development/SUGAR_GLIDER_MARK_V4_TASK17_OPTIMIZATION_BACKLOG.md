# Sugar Glider Mark v4 - Task 17 Optimization Backlog (Prioritized)

Updated: 2026-04-27 (UTC)

## Objective

Define the next executable optimization backlog using measured evidence from Tasks 12-16.

## Evidence Used

- Full runs:
  - `20260427T020235Z-v4-iteration3-fastpath-run1`
  - `20260427T020718Z-v4-iteration3-fastpath-run2`
- Heavy-path profile:
  - `20260427T021623Z-task16-heavypath-profile`

## Priority Backlog

1. **RTG socket-delivery hot path instrumentation**
   - Add lightweight timing counters around emit path per payload/concurrency bucket.
   - Goal: quantify CPU time in parse/dispatch/emit sections for `32768 c10/c50`.

2. **Sugar Glider dispatcher/ack micro-timing**
   - Add counters/timers for read->dispatch->ack chunk lifecycle.
   - Goal: isolate where dispatcher CPU is spent when CPU exceeds one core.

3. **Publish-to-delivery overlap inspection**
   - Measure time split between publish HTTP handling and downstream socket delivery under load.
   - Goal: validate whether the publish side is reintroducing queue pressure.

4. **Queue-depth and backpressure telemetry surfacing**
   - Surface per-stage depth snapshots during heavy-path runs.
   - Goal: identify sustained pressure zones rather than single-point peaks.

5. **Controlled micro-A/B on targeted code paths**
   - Run short probes after each instrumentation-guided code change.
   - Promotion rule: only escalate to full matrix when targeted probes beat
     `20260426T225038Z-v4-websocket-native-full` on relevant cells.

## Exit Criteria For Next Full-Matrix Rerun

- Reliable targeted probe gains on heavy cells:
  - `32768 c10` and `32768 c50` throughput above current fast-path baseline
- No regression on `1024 c50` and `8192 c50`
- Reliability unchanged (`lost=0`, `failed=0`, `error=0`)

## Outcome

Task 17 completed (prioritized, evidence-based backlog documented).

