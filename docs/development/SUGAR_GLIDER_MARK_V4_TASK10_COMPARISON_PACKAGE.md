# Sugar Glider Mark v4 - Task 10 Comparison Report Package

Updated: 2026-04-27 (UTC)

## Objective

Package and summarize the two full websocket matrix runs from Tasks 08 and 09.

## Included Runs

- Task 08 run:
  - `20260427T014408Z-task8-full-websocket-run1`
- Task 09 run:
  - `20260427T014905Z-task9-full-websocket-run2`

## Consolidated Metrics

| Metric | Run 1 | Run 2 | Pair Mean |
|---|---:|---:|---:|
| Average throughput (ops/s) | `978.2768` | `1048.6177` | `1013.4472` |
| Average p95 (ms) | `40.1081` | `39.5533` | `39.8307` |
| Throughput ratio vs 20260412 | `2.0636x` | `2.1747x` | `2.1192x` |
| Throughput ratio vs v3 fixed repeat2 | `0.8503x` | `0.8777x` | `0.8640x` |
| Throughput ratio vs v4 websocket native | `0.5781x` | `0.5943x` | `0.5862x` |
| p95 pass rate vs 20260412 (`<=1.20x`) | `9/9` | `9/9` | n/a |
| Reliability (`lost/failed/error`) | `0/0/0` | `0/0/0` | pass |

## Heavy Path Snapshot (`32768B`)

### Run 1

- `c=1`: throughput ratio `1.0641x` vs 20260412
- `c=10`: throughput ratio `1.2051x` vs 20260412
- `c=50`: throughput ratio `1.2007x` vs 20260412

### Run 2

- `c=1`: throughput ratio `1.0464x` vs 20260412
- `c=10`: throughput ratio `1.2063x` vs 20260412
- `c=50`: throughput ratio `1.1672x` vs 20260412

## Contract Check (Target: exceed `2.7x` baseline)

- Run 1 `>=2.7x`: FAIL (`2.0636x`)
- Run 2 `>=2.7x`: FAIL (`2.1747x`)
- Pair mean `>=2.7x`: FAIL (`2.1192x`)
- Reliability gate: PASS

## Outcome

Task 10 completed (comparison package assembled and evaluated).

