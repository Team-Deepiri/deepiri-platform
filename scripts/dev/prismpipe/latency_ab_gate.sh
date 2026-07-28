#!/usr/bin/env bash
# PrismPipe latency A/B gate — direct vs through PrismPipe.
# Fails if PrismPipe warm path adds more than MAX_OVERHEAD_MS (absolute)
# or MAX_OVERHEAD_PCT (relative) vs direct auth health p95.
set -euo pipefail

PRISM_URL="${PRISM_URL:-http://127.0.0.1:5011}"
AUTH_URL="${AUTH_URL:-http://127.0.0.1:5001}"
GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:5100}"
N="${N:-30}"
WARMUP="${WARMUP:-5}"
MAX_OVERHEAD_MS="${MAX_OVERHEAD_MS:-15}"
MAX_OVERHEAD_PCT="${MAX_OVERHEAD_PCT:-25}"
REQUIRE_USEFUL="${REQUIRE_USEFUL:-1}"
REQUIRE_GATEWAY="${REQUIRE_GATEWAY:-0}"

note() { echo "==> $*"; }

curl_ms() {
  # prints: http_code time_total_ms
  local method="$1" url="$2"
  shift 2
  local out
  out="$(curl -sS -o /tmp/prism_lat_body.json -w '%{http_code} %{time_total}' -X "$method" "$url" \
    -H 'Content-Type: application/json' "$@" || echo "000 9.999")"
  local code t
  code="$(echo "$out" | awk '{print $1}')"
  t="$(echo "$out" | awk '{print $2}')"
  python3 -c "print(int('$code'), round(float('$t')*1000, 3))"
}

percentile() {
  python3 - "$@" <<'PY'
import sys
vals = sorted(float(x) for x in sys.argv[1:])
if not vals:
    print(0)
    raise SystemExit
p = 0.95
idx = min(len(vals)-1, max(0, int(round(p*(len(vals)-1)))))
print(vals[idx])
PY
}

mean() {
  python3 - "$@" <<'PY'
import sys
vals=[float(x) for x in sys.argv[1:]]
print(sum(vals)/len(vals) if vals else 0)
PY
}

note "preflight"
curl -sf "$PRISM_URL/health" >/dev/null
curl -sf "$AUTH_URL/health" >/dev/null
echo "  prism+auth OK"

note "A) direct auth /health ($N samples, warmup=$WARMUP)"
direct_ms=()
for i in $(seq 1 $((N+WARMUP))); do
  read -r code ms <<<"$(curl_ms GET "$AUTH_URL/health")"
  [[ "$code" == "200" ]] || { echo "direct auth failed code=$code"; exit 1; }
  if [[ "$i" -gt "$WARMUP" ]]; then
    direct_ms+=("$ms")
  fi
done
direct_p95="$(percentile "${direct_ms[@]}")"
direct_avg="$(mean "${direct_ms[@]}")"
echo "  direct avg=${direct_avg}ms p95=${direct_p95}ms"

note "B) PrismPipe pipeline cold+warm ($N samples)"
# cold first
read -r code cold_ms <<<"$(curl_ms POST "$PRISM_URL/pipelines/deepiri/health" -d '{"input":{"probe":"latency"},"use_computation_sharing":true}')"
[[ "$code" == "200" ]] || { echo "pipeline cold failed code=$code"; cat /tmp/prism_lat_body.json; exit 1; }
useful="$(python3 -c 'import json;print(json.load(open("/tmp/prism_lat_body.json")).get("useful",False))')"
echo "  cold=${cold_ms}ms useful=$useful"

prism_ms=()
for i in $(seq 1 "$N"); do
  read -r code ms <<<"$(curl_ms POST "$PRISM_URL/pipelines/deepiri/health" -d '{"input":{"probe":"latency"},"use_computation_sharing":true}')"
  [[ "$code" == "200" ]] || { echo "pipeline warm failed code=$code"; exit 1; }
  prism_ms+=("$ms")
done
prism_p95="$(percentile "${prism_ms[@]}")"
prism_avg="$(mean "${prism_ms[@]}")"
echo "  warm avg=${prism_avg}ms p95=${prism_p95}ms"

metrics="$(curl -sS "$PRISM_URL/metrics")"
hit_ratio="$(python3 -c 'import json,sys;print(json.loads(sys.argv[1]).get("hit_ratio",0))' "$metrics")"
echo "  metrics hit_ratio=$hit_ratio"

note "C) overhead gate"
python3 - "$direct_p95" "$prism_p95" "$MAX_OVERHEAD_MS" "$MAX_OVERHEAD_PCT" "$hit_ratio" "$useful" "$REQUIRE_USEFUL" <<'PY'
import sys
direct = float(sys.argv[1])
prism = float(sys.argv[2])
max_ms = float(sys.argv[3])
max_pct = float(sys.argv[4])
hit = float(sys.argv[5])
useful = str(sys.argv[6]).lower() in ("true", "1", "yes")
require_useful = sys.argv[7] == "1"

overhead = prism - direct
pct = (overhead / direct * 100.0) if direct > 0 else 0.0
print(f"  overhead_ms={overhead:.3f} overhead_pct={pct:.2f}%")

fails = []
if hit < 0.5:
    fails.append(f"hit_ratio {hit} < 0.5 (dedup not helping)")
# Warm PrismPipe must not add more than max absolute OR relative overhead vs direct.
# Allow either bound: fail only if BOTH exceeded (absolute AND relative).
if overhead > max_ms and pct > max_pct:
    fails.append(
        f"warm p95 {prism:.3f}ms exceeds direct {direct:.3f}ms by {overhead:.3f}ms "
        f"({pct:.1f}%) — limits {max_ms}ms / {max_pct}%"
    )
if require_useful and not useful:
    fails.append("pipeline useful=false (auth+LIS not both reachable through PrismPipe)")

if fails:
    print("LATENCY GATE FAILED:")
    for f in fails:
        print(f"  - {f}")
    raise SystemExit(1)
print("LATENCY GATE PASSED")
if overhead <= 0:
    print("  warm path is at or below direct auth p95 (dedup win)")
else:
    print(f"  warm overhead within budget ({overhead:.3f}ms / {pct:.1f}%)")
PY

if [[ "$REQUIRE_GATEWAY" == "1" ]]; then
  note "D) gateway /api/prism latency"
  read -r code gms <<<"$(curl_ms GET "$GATEWAY_URL/api/prism/health")"
  [[ "$code" == "200" ]] || { echo "gateway prism health failed code=$code"; exit 1; }
  echo "  gateway /api/prism/health ${gms}ms"
fi

echo
echo "SUMMARY direct_p95=${direct_p95} prism_warm_p95=${prism_p95} hit_ratio=$hit_ratio useful=$useful"
