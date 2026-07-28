#!/usr/bin/env bash
# PrismPipe system regression + usefulness gate (Deepiri wiring).
#
# Proves:
#   1) PrismPipe is reachable (direct and optionally via API Gateway)
#   2) Deepiri health pipeline probes real services
#   3) Identical pipeline runs share computation (hit_ratio rises)
#   4) Direct auth/LIS health still works (platform not broken)
#
# Usage:
#   ./scripts/dev/prismpipe/system_regression_gate.sh
#   PRISM_URL=http://localhost:5011 GATEWAY_URL=http://localhost:5100 ./scripts/dev/prismpipe/system_regression_gate.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

PRISM_URL="${PRISM_URL:-http://localhost:5011}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:5100}"
AUTH_URL="${AUTH_URL:-http://localhost:5001}"
LIS_URL="${LIS_URL:-http://localhost:5003}"
N="${N:-8}"
MIN_HIT_RATIO="${MIN_HIT_RATIO:-0.5}"
REQUIRE_GATEWAY="${REQUIRE_GATEWAY:-0}"
REQUIRE_USEFUL="${REQUIRE_USEFUL:-1}"

pass=0
fail=0
note() { echo "==> $*"; }
ok() { echo "  OK  $*"; pass=$((pass + 1)); }
bad() { echo "  FAIL $*"; fail=$((fail + 1)); }

curl_json() {
  local method="$1" url="$2"
  shift 2
  curl -sS -X "$method" "$url" -H 'Content-Type: application/json' "$@"
}

note "1) PrismPipe health"
if curl -sf "$PRISM_URL/health" >/dev/null; then
  ok "prismpipe /health"
else
  bad "prismpipe /health unreachable at $PRISM_URL"
fi

note "2) Direct platform health (baseline — no PrismPipe)"
auth_ok=0
lis_ok=0
if curl -sf "$AUTH_URL/health" >/dev/null 2>&1; then
  ok "auth /health direct"
  auth_ok=1
else
  bad "auth /health direct ($AUTH_URL) — set AUTH_URL or start auth-service"
fi
if curl -sf "$LIS_URL/health" >/dev/null 2>&1; then
  ok "lis /health direct"
  lis_ok=1
else
  # LIS port mapping varies; try compose-published fallbacks (5009:5003 in docker-compose.dev.yml)
  if curl -sf "http://localhost:5009/health" >/dev/null 2>&1; then
    LIS_URL="http://localhost:5009"
    ok "lis /health direct ($LIS_URL)"
    lis_ok=1
  elif curl -sf "http://localhost:5010/health" >/dev/null 2>&1; then
    LIS_URL="http://localhost:5010"
    ok "lis /health direct ($LIS_URL)"
    lis_ok=1
  elif [[ "${REQUIRE_LIS:-0}" == "1" ]]; then
    bad "lis /health direct — set LIS_URL or start language-intelligence-service"
  else
    echo "  SKIP lis /health direct (not up; set REQUIRE_LIS=1 to fail)"
  fi
fi

note "3) Deepiri pipeline via PrismPipe (N=$N identical runs)"
metrics_before="$(curl_json GET "$PRISM_URL/metrics" || echo '{}')"
last_useful="false"
for i in $(seq 1 "$N"); do
  resp="$(curl_json POST "$PRISM_URL/pipelines/deepiri/health" -d '{"input":{"probe":"health"},"use_computation_sharing":true}')"
  last_useful="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(str(d.get("useful", False)).lower())' "$resp" 2>/dev/null || echo false)"
done
metrics_after="$(curl_json GET "$PRISM_URL/metrics")"

hit_ratio="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("hit_ratio", 0))' "$metrics_after")"
hits="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("hits", 0))' "$metrics_after")"
echo "  metrics: hit_ratio=$hit_ratio hits=$hits useful=$last_useful"

python3 - "$hit_ratio" "$MIN_HIT_RATIO" "$hits" <<'PY' && ok "dedup hit_ratio gate" || bad "dedup hit_ratio gate"
import sys
hit = float(sys.argv[1])
need = float(sys.argv[2])
hits = int(float(sys.argv[3]))
sys.exit(0 if hit >= need and hits >= 1 else 1)
PY

if [[ "$REQUIRE_USEFUL" == "1" ]]; then
  if [[ "$last_useful" == "true" ]]; then
    ok "pipeline useful=true (auth+lis reachable through PrismPipe)"
  elif [[ "$auth_ok" == "1" && "$lis_ok" == "1" ]]; then
    bad "pipeline useful=false but direct auth+lis are up — check AUTH_SERVICE_URL/LIS URL inside prismpipe container"
  else
    echo "  SKIP usefulness (downstream services not up on host); still measured dedup"
  fi
fi

note "4) Gateway proxy /api/prism (optional)"
gw_code="$(curl -sS -o /dev/null -w '%{http_code}' "$GATEWAY_URL/api/prism/health" || echo 000)"
if [[ "$gw_code" == "200" ]]; then
  ok "gateway /api/prism/health"
  gw_pipe="$(curl_json POST "$GATEWAY_URL/api/prism/pipelines/deepiri/health" -d '{"input":{"probe":"health"}}')"
  gw_useful="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(str(d.get("useful", False)).lower())' "$gw_pipe" 2>/dev/null || echo false)"
  echo "  gateway pipeline useful=$gw_useful"
else
  msg="gateway /api/prism/health -> HTTP $gw_code (rebuild api-gateway with PRISMPIPE_ENABLED=true)"
  if [[ "$REQUIRE_GATEWAY" == "1" ]]; then
    bad "$msg"
  else
    echo "  SKIP $msg"
  fi
fi

note "5) Correctness: direct vs prism metrics shape"
python3 - "$metrics_after" <<'PY' && ok "metrics schema" || bad "metrics schema"
import json, sys
d = json.loads(sys.argv[1])
required = ["hit_ratio", "execute_p95", "swarm_error_rate", "deduplication_ratio"]
missing = [k for k in required if k not in d]
sys.exit(0 if not missing else 1)
PY

echo
echo "==== PrismPipe system regression summary ===="
echo "passed=$pass failed=$fail"
echo "before=$metrics_before"
echo "after=$metrics_after"

if [[ "$fail" -gt 0 ]]; then
  echo "VERDICT: NO-GO — PrismPipe wiring/regression failed"
  exit 1
fi

if [[ "$last_useful" == "true" ]]; then
  echo "VERDICT: USEFUL — multi-hop Deepiri pipeline works + computation sharing observed"
else
  echo "VERDICT: PARTIAL — PrismPipe healthy + dedup works; usefulness pending auth+LIS in-network"
fi
exit 0
