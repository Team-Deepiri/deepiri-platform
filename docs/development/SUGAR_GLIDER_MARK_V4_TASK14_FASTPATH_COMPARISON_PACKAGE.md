# Sugar Glider Mark v4 - Task 14 Fast-Path Comparison Package

Updated: 2026-04-27 (UTC)

## Objective

Package and evaluate the two restored fast-path full websocket runs from Tasks 12 and 13.

## Included Runs

- Task 12 run:
  - `20260427T020235Z-v4-iteration3-fastpath-run1`
- Task 13 run:
  - `20260427T020718Z-v4-iteration3-fastpath-run2`

## Consolidated Metrics

| Metric | Run 1 | Run 2 | Pair Mean |
|---|---:|---:|---:|
| Average throughput (ops/s) | `1011.4769` | `1040.9241` | `1026.2005` |
| Average p95 (ms) | `40.0598` | `36.3369` | `38.1983` |
| Throughput ratio vs 20260412 | `2.1314x` | `2.2073x` | `2.1694x` |
| Throughput ratio vs v3 fixed repeat2 | `0.8698x` | `0.9073x` | `0.8885x` |
| Throughput ratio vs v4 websocket native | `0.5930x` | `0.6216x` | `0.6073x` |
| Throughput ratio vs autoplay Task 8/9 | `1.0316x` | `1.0476x` | `1.0396x` |
| p95 pass rate vs 20260412 (`<=1.20x`) | `9/9` | `9/9` | n/a |
| Reliability (`lost/failed/error`) | `0/0/0` | `0/0/0` | pass |

## Heavy Path Snapshot (`32768B`)

### Run 1

- `c=1`: `227.9721 ops/s`
- `c=10`: `415.9424 ops/s`
- `c=50`: `423.3824 ops/s`

### Run 2

- `c=1`: `235.9827 ops/s`
- `c=10`: `417.8794 ops/s`
- `c=50`: `440.9222 ops/s`

## Contract Check (Target: exceed `2.7x` baseline)

- Run 1 `>=2.7x`: FAIL (`2.1314x`)
- Run 2 `>=2.7x`: FAIL (`2.2073x`)
- Pair mean `>=2.7x`: FAIL (`2.1694x`)
- Reliability gate: PASS

## Interpretation

- This restored fast-path profile improves over the immediate autoplay baseline from Tasks 08/09 (~`+3.96%` pair mean throughput ratio).
- It still remains materially below both:
  - Mark v3 fixed repeat2 (`0.8885x` pair mean ratio)
  - Prior v4 websocket-native full (`0.6073x` pair mean ratio)

## Outcome

Task 14 completed (comparison package assembled and evaluated).

