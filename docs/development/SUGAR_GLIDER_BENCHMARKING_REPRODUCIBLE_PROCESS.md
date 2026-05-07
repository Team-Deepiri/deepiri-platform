# Sugar Glider Main Path: Reproducible Benchmarking Process

## Purpose
This document captures the exact benchmarking method used for Sugar Glider transport evaluation so results can be rerun and audited with identical methodology.

Date context for this runbook: April 21, 2026.

## Benchmark Families
We use two benchmark families and do not mix their conclusions.

1. Transport-only benchmark corpus (task-08 style)
- Compares Redis vs Sugar Glider HTTP vs Sugar Glider gRPC at transport layer.
- Implemented in the Sugar Glider repo (`cmd/transport-bench`).

2. Full-path end-to-end RTG benchmark (official gate lineage)
- Measures publish -> Sugar Glider -> RTG socket delivery.
- Implemented via `scripts/dev/sugarglider/e2e_gateway_benchmark.js` in the extract-hard workspace.

## Fixed Matrix
All benchmark runs use a fixed matrix:
- payload bytes: `1024`, `8192`, `32768`
- concurrency: `1`, `10`, `50`
- warmup ops: `500`
- measured ops: `5000`
- repetitions: `3`

Do not override these for gate decisions.

## Environment Control
Before any run:
- restart test stack
- ensure no other local stress workload is running
- capture commit SHA and dirty state
- keep the same host and Node/Go versions for comparison

## A. Transport-Only Benchmark Reproduction
Run in Sugar Glider repo:
```bash
cd /Users/Kyle/Developer/Deepiri/deepiri-sugar-glider

go run ./cmd/transport-bench \
  --transports redis,http,grpc \
  --stream platform-events \
  --output-dir benchmarks/transport/$(date -u +%Y%m%dT%H%M%SZ)
```

Expected artifacts:
- `manifest.json`
- `summary.csv`
- `report.md`
- per-case raw `.json`, `.metrics.json`, `.log`

## B. Full-Path End-To-End Benchmark Reproduction
Run in extract-hard workspace:
```bash
cd /Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard

# bring up stack and validate
make rtg-up
make rtg-preflight
make rtg-gate

# run full matrix benchmark
node scripts/dev/sugarglider/e2e_gateway_benchmark.js \
  --out-dir benchmarks/end-to-end/$(date -u +%Y%m%dT%H%M%SZ)-shadow-rollout-validation
```

Expected artifacts:
- `manifest.json`
- `summary.csv`
- `report.md`
- per scenario `end_to_end_p{payload}_c{concurrency}_r{rep}.json`
- corresponding `.log` files

## C. Baseline Comparison Reproduction
Official full-path baseline used by current gate checks:
- `/Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard/benchmarks/end-to-end/20260412T052514Z/summary.csv`

Generate comparison against a new rerun:
```bash
cd /Users/Kyle/Developer/Deepiri

node planning/plaky/compare-task-14-e2e.js \
  --baseline-summary /Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard/benchmarks/end-to-end/20260412T052514Z/summary.csv \
  --rerun-summary /Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard/benchmarks/end-to-end/<new-run>/summary.csv \
  --out-csv /Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard/benchmarks/end-to-end/<new-run>/comparison_vs_20260412.csv \
  --out-md /Users/Kyle/Developer/Deepiri/deepiri-platform-extract-hard/benchmarks/end-to-end/<new-run>/comparison_vs_20260412.md
```

## D. Gate Criteria
Mandatory reliability gate:
- `error_rate_pct = 0`
- `failed_ops_mean = 0`
- `lost_events_mean = 0`

Current promotion-style checks:
- low concurrency p50: `<= 1.15x baseline` in at least `2/3` payloads
- low concurrency throughput: `>= 0.90x baseline` in at least `2/3` payloads
- tail latency p95: `<= 1.20x baseline` in at least `6/9` matrix cells

## E. Boss-Ready Summary Template
For each final report include:
- benchmark date (UTC)
- comparison corpus used (task-08 transport-only and/or April 12 full-path baseline)
- average throughput ratio
- best and worst matrix cells
- reliability status (lost events / failed ops / error rate)
- next tuning target if any cell is below objective

## F. Reproducibility Checklist
- [ ] Same matrix and repetition counts
- [ ] Same benchmark scripts and command forms
- [ ] Captured git SHA + dirty state from manifest
- [ ] Captured environment metadata from manifest
- [ ] Stored comparison CSV and Markdown in run folder
- [ ] Preserved raw per-scenario artifacts for audit
