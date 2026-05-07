# Sugar Glider Mark v4 - Task 18 Runtime Pinning

Updated: 2026-04-27 (UTC)

## Objective

Pin benchmark/probe execution to a reproducible Node runtime so websocket throughput runs stop drifting by host shell/default Node version.

## Changes Implemented

### 1) Probe Runtime Pinning

Updated:

- `scripts/dev/sugarglider/e2e_gateway_probe.js`

Behavior:

- Resolves benchmark Node runtime with priority:
  1. `BENCHMARK_NODE_BIN`
  2. pinned candidates for `BENCHMARK_NODE_VERSION` (default `23.11.0`)
     - `/opt/homebrew/Cellar/node/<version>/bin/node`
     - `$HOME/.nvm/versions/node/v<version>/bin/node`
  3. `process.execPath`
  4. `node` on `PATH`
- Websocket probes require runtime support for global `WebSocket`.
- Emits selected runtime details before execution.
- Exports resolved runtime into benchmark process environment:
  - `BENCHMARK_NODE_VERSION`
  - `BENCHMARK_NODE_BIN`

### 2) Benchmark Wrapper Runtime Pinning

Updated:

- `scripts/dev/sugarglider/run_e2e_gateway_benchmark.sh`

Behavior:

- Uses the same pinned runtime strategy (`BENCHMARK_NODE_BIN` / `BENCHMARK_NODE_VERSION` / pin fallback).
- Validates websocket capability when `--socket-transport websocket` is requested.
- Prints selected runtime before executing benchmark.

### 3) Runtime Metadata in Benchmark Manifest

Updated:

- `scripts/dev/sugarglider/e2e_gateway_benchmark.js`

Added runtime fields in `manifest.environment`:

- `node_exec_path`
- `benchmark_node_version_target`
- `benchmark_node_bin_env`

## Env Controls

- `BENCHMARK_NODE_BIN`: explicit Node binary path
- `BENCHMARK_NODE_VERSION`: preferred pinned version (default `23.11.0`)
- `BENCHMARK_NODE_PIN`: pin toggle (`true|false`, default `true`)

## Verification

Dry-run runtime selection:

- command:
  - `node scripts/dev/sugarglider/e2e_gateway_probe.js --socket-transport websocket --payload-bytes 1024 --concurrency-levels 1 --warmup-ops 10 --measure-ops 20 --repetitions 1 --dry-run`
- result:
  - resolved `node_bin=/opt/homebrew/Cellar/node/23.11.0/bin/node`
  - `node_version=v23.11.0`

Smoke benchmark:

- run:
  - `benchmarks/end-to-end/20260427T030232Z-task2-node-pin-smoke`
- manifest confirms:
  - `environment.node_version = v23.11.0`
  - `environment.node_exec_path = /opt/homebrew/Cellar/node/23.11.0/bin/node`

## Outcome

Task 18 completed: runtime pinning is now enforced for probe/wrapper-driven benchmark execution, with manifest evidence for reproducibility audits.
