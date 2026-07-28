#!/usr/bin/env bash
# PrismPipe full regression: unit + bench + system + latency A/B + throughput.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

PRISM_URL="${PRISM_URL:-http://127.0.0.1:5011}"
AUTH_URL="${AUTH_URL:-http://127.0.0.1:5001}"
export PRISM_URL AUTH_URL
export REQUIRE_USEFUL="${REQUIRE_USEFUL:-0}"
export REQUIRE_GATEWAY="${REQUIRE_GATEWAY:-0}"
export N="${N:-30}"
export WARMUP="${WARMUP:-5}"
export MAX_OVERHEAD_MS="${MAX_OVERHEAD_MS:-15}"
export MAX_OVERHEAD_PCT="${MAX_OVERHEAD_PCT:-25}"
export THROUGHPUT_N="${THROUGHPUT_N:-100}"
export THROUGHPUT_CONCURRENCY="${THROUGHPUT_CONCURRENCY:-8}"
export MIN_WARM_RPS="${MIN_WARM_RPS:-50}"

fail=0
ok() { echo "  PASS $*"; }
bad() { echo "  FAIL $*"; fail=$((fail+1)); }

echo "======== 1) PrismPipe unit tests ========"
(
  cd platform-services/shared/deepiri-prismpipe
  poetry run pytest tests/ -q
) && ok "unit" || bad "unit"

echo "======== 2) Bench gate (dedup/swarm/p95) ========"
(
  cd platform-services/shared/deepiri-prismpipe
  chmod +x scripts/bench/run_bench_gate.sh
  ./scripts/bench/run_bench_gate.sh
) && ok "bench" || bad "bench"

echo "======== 3) System regression ========"
chmod +x scripts/dev/prismpipe/system_regression_gate.sh
./scripts/dev/prismpipe/system_regression_gate.sh && ok "system" || bad "system"

echo "======== 3b) Service impact (auth/LIS help vs hurt) ========"
chmod +x scripts/dev/prismpipe/service_impact_integration.sh
./scripts/dev/prismpipe/service_impact_integration.sh && ok "service-impact" || bad "service-impact"

echo "======== 3c) Usefulness perf (session vs two RTTs) ========"
chmod +x scripts/dev/prismpipe/usefulness_perf.sh
./scripts/dev/prismpipe/usefulness_perf.sh && ok "usefulness-perf" || bad "usefulness-perf"

echo "======== 4) Latency A/B (direct vs PrismPipe warm) ========"
chmod +x scripts/dev/prismpipe/latency_ab_gate.sh
./scripts/dev/prismpipe/latency_ab_gate.sh && ok "latency" || bad "latency"

echo "======== 5) Throughput (warm concurrent pipeline) ========"
chmod +x scripts/dev/prismpipe/throughput_gate.sh
./scripts/dev/prismpipe/throughput_gate.sh && ok "throughput" || bad "throughput"

echo
echo "======== FULL REGRESSION SUMMARY ========"
echo "failed=$fail"
if [[ "$fail" -gt 0 ]]; then
  echo "VERDICT: NO-GO"
  exit 1
fi
echo "VERDICT: GO — unit+bench+system+latency+throughput green"
exit 0
