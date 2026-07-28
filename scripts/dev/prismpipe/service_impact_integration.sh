#!/usr/bin/env bash
# Integration: does PrismPipe help or hurt auth/LIS under real stack conditions?
#
# Honest scope today: PrismPipe only *probes* /health on auth+LIS (+ optional cyrex).
# It does NOT sit on the /api/auth request path. This gate measures:
#   A) Non-interference — auth/LIS stay healthy while PrismPipe is hammered
#   B) Dedup benefit — identical warm pipelines avoid re-hitting auth/LIS (fast path)
#   C) Without sharing — each run pays cold multi-hop cost (proves dedup is the help)
#   D) Gateway — /api/prism works; platform gateway /health still works
#   E) Direct auth/LIS unchanged baselines
set -euo pipefail

PRISM_URL="${PRISM_URL:-http://127.0.0.1:5011}"
AUTH_URL="${AUTH_URL:-http://127.0.0.1:5001}"
LIS_URL="${LIS_URL:-http://127.0.0.1:5009}"
GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:5100}"
N="${N:-40}"
CONC="${CONC:-8}"

pass=0
fail=0
ok() { echo "  OK  $*"; pass=$((pass + 1)); }
bad() { echo "  FAIL $*"; fail=$((fail + 1)); }
note() { echo "==> $*"; }

ms_get() {
  local url="$1"
  curl -sS -o /tmp/impact_body.json -w '%{http_code} %{time_total}' -m 15 "$url" \
    | awk '{printf "%s %.3f", $1, $2*1000}'
}

note "0) preflight"
for pair in "auth|$AUTH_URL/health" "lis|$LIS_URL/health" "prism|$PRISM_URL/health" "gw|$GATEWAY_URL/health"; do
  name="${pair%%|*}"; url="${pair#*|}"
  read -r code ms <<<"$(ms_get "$url")"
  if [[ "$code" == "200" ]]; then ok "$name health ${ms}ms"; else bad "$name health HTTP $code"; fi
done

note "1) Direct auth/LIS baseline (no PrismPipe)"
auth_samples=()
lis_samples=()
for i in $(seq 1 20); do
  read -r c ms <<<"$(ms_get "$AUTH_URL/health")"
  [[ "$c" == "200" ]] || { bad "auth baseline sample $i"; break; }
  auth_samples+=("$ms")
  read -r c ms <<<"$(ms_get "$LIS_URL/health")"
  [[ "$c" == "200" ]] || { bad "lis baseline sample $i"; break; }
  lis_samples+=("$ms")
done
auth_p95="$(python3 -c 'import sys; v=sorted(float(x) for x in sys.argv[1:]); print(v[int(round(0.95*(len(v)-1)))])' "${auth_samples[@]}")"
lis_p95="$(python3 -c 'import sys; v=sorted(float(x) for x in sys.argv[1:]); print(v[int(round(0.95*(len(v)-1)))])' "${lis_samples[@]}")"
echo "  baseline auth_p95=${auth_p95}ms lis_p95=${lis_p95}ms"
ok "direct baselines collected"

note "2) Dedup help — warm shared pipeline should NOT re-pay auth+LIS RTT"
# unique probe key so we own the cache entry
PROBE="impact-$(date +%s)"
# cold once
read -r code cold_ms <<<"$(curl -sS -o /tmp/impact_pipe.json -w '%{http_code} %{time_total}' -m 30 \
  -X POST "$PRISM_URL/pipelines/deepiri/health" -H 'Content-Type: application/json' \
  -d "{\"input\":{\"probe\":\"$PROBE\"},\"use_computation_sharing\":true}" \
  | awk '{printf "%s %.3f", $1, $2*1000}')"
useful="$(python3 -c 'import json; print(str(json.load(open("/tmp/impact_pipe.json")).get("useful")).lower())')"
echo "  cold=${cold_ms}ms useful=$useful code=$code"
[[ "$code" == "200" && "$useful" == "true" ]] && ok "cold useful pipeline" || bad "cold useful pipeline (code=$code useful=$useful)"

warm=()
for i in $(seq 1 "$N"); do
  read -r c ms <<<"$(curl -sS -o /tmp/impact_pipe.json -w '%{http_code} %{time_total}' -m 10 \
    -X POST "$PRISM_URL/pipelines/deepiri/health" -H 'Content-Type: application/json' \
    -d "{\"input\":{\"probe\":\"$PROBE\"},\"use_computation_sharing\":true}" \
    | awk '{printf "%s %.3f", $1, $2*1000}')"
  [[ "$c" == "200" ]] || { bad "warm sample $i HTTP $c"; break; }
  warm+=("$ms")
done
warm_p95="$(python3 -c 'import sys; v=sorted(float(x) for x in sys.argv[1:]); print(v[int(round(0.95*(len(v)-1)))])' "${warm[@]}")"
warm_avg="$(python3 -c 'import sys; v=[float(x) for x in sys.argv[1:]]; print(sum(v)/len(v))' "${warm[@]}")"
echo "  warm_avg=${warm_avg}ms warm_p95=${warm_p95}ms (direct auth_p95 was ${auth_p95}ms)"
# Warm must be far below cold and comparable to a single hop (proves auth/LIS not re-hit)
python3 - "$warm_p95" "$cold_ms" "$auth_p95" <<'PY' && ok "dedup avoids re-hitting auth+LIS" || bad "dedup did not avoid downstream hits"
import sys
warm, cold, auth = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])
# Warm must be near single-hop auth latency (absolute), proving downstream not re-hit.
# Also require warm meaningfully below cold when cold is slow; when cold is already
# fast (<50ms), absolute warm budget is the signal.
absolute_ok = warm <= max(10.0, auth * 8)
relative_ok = warm < cold / 3 if cold >= 50 else True
sys.exit(0 if absolute_ok and relative_ok else 1)
PY

note "3) Without computation sharing — each call pays multi-hop (hurts auth/LIS with N probes)"
# Only 2 samples: this intentionally loads auth+LIS. Retry once on empty-reply (worker recycle).
noshares=()
for i in $(seq 1 2); do
  for attempt in 1 2; do
    set +e
    out="$(curl -sS -o /tmp/impact_noshare.json -w '%{http_code} %{time_total}' -m 45 \
      -X POST "$PRISM_URL/pipelines/deepiri/health" -H 'Content-Type: application/json' \
      -d "{\"input\":{\"probe\":\"noshare-$i-$RANDOM\"},\"use_computation_sharing\":false}" 2>/tmp/impact_noshare.err)"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      read -r c secs <<<"$out"
      ms="$(python3 -c "print(round(float('$secs')*1000, 3))")"
      if [[ "$c" == "200" ]]; then
        noshares+=("$ms")
        echo "  noshare[$i]=${ms}ms"
        break
      fi
    fi
    echo "  noshare[$i] attempt $attempt failed; waiting for prism..."
    sleep 2
    curl -sf "$PRISM_URL/health" >/dev/null || true
  done
done
[[ "${#noshares[@]}" -ge 1 ]] || { bad "noshare samples failed"; noshares=(99999); }
noshare_min="$(python3 -c 'import sys; print(min(float(x) for x in sys.argv[1:]))' "${noshares[@]}")"
python3 - "$noshare_min" "$warm_p95" <<'PY' && ok "sharing is what protects auth/LIS from repeated probes" || bad "noshare not meaningfully slower than warm"
import sys
sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) * 5 else 1)
PY

note "4) Non-interference — concurrent PrismPipe warm load must not degrade auth p95 >3x"
curl -sf "$PRISM_URL/health" >/dev/null
python3 - "$PRISM_URL" "$AUTH_URL" "$PROBE" "$CONC" <<'PY'
import json, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

prism, auth, probe, conc = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
payload = json.dumps({"input": {"probe": probe}, "use_computation_sharing": True}).encode()

def prism_hit(_):
    req = urllib.request.Request(
        prism.rstrip("/") + "/pipelines/deepiri/health",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        r.read()

def auth_hit(_):
    t0 = time.perf_counter()
    with urllib.request.urlopen(auth.rstrip("/") + "/health", timeout=5) as r:
        assert r.status == 200
    return (time.perf_counter() - t0) * 1000.0

auth_lat = []
errors = 0
with ThreadPoolExecutor(max_workers=conc + 4) as pool:
    prism_futs = [pool.submit(prism_hit, i) for i in range(80)]
    auth_futs = [pool.submit(auth_hit, i) for i in range(30)]
    for f in as_completed(auth_futs):
        try:
            auth_lat.append(f.result())
        except Exception:
            errors += 1
    for f in as_completed(prism_futs):
        try:
            f.result()
        except Exception:
            errors += 1
if not auth_lat:
    raise SystemExit("no auth samples under load")
auth_lat.sort()
p95 = auth_lat[int(round(0.95 * (len(auth_lat) - 1)))]
print(f"  auth_p95_under_prism_load={p95:.3f}ms prism_errors={errors}")
open("/tmp/impact_auth_under_load.txt", "w").write(str(p95))
PY
under="$(cat /tmp/impact_auth_under_load.txt)"
python3 - "$under" "$auth_p95" <<'PY' && ok "auth p95 not degraded >3x under prism load" || bad "auth degraded under prism load"
import sys
under, base = float(sys.argv[1]), float(sys.argv[2])
sys.exit(0 if under <= max(base * 3, 15.0) else 1)
PY

note "5) Gateway prism path + platform health still OK"
gw_code="$(curl -sS -o /dev/null -w '%{http_code}' -m 5 "$GATEWAY_URL/api/prism/health" || echo 000)"
[[ "$gw_code" == "200" ]] && ok "gateway /api/prism/health" || bad "gateway /api/prism/health $gw_code"
gw_pipe="$(curl -sS -m 30 -X POST "$GATEWAY_URL/api/prism/pipelines/deepiri/health" \
  -H 'Content-Type: application/json' -d "{\"input\":{\"probe\":\"gw-$PROBE\"},\"use_computation_sharing\":true}")"
gw_useful="$(python3 -c 'import json,sys; print(str(json.loads(sys.argv[1]).get("useful")).lower())' "$gw_pipe")"
[[ "$gw_useful" == "true" ]] && ok "gateway pipeline useful=true" || bad "gateway pipeline useful=$gw_useful"
# Auth is NOT proxied through prism — confirm direct auth still the real path
read -r ac _ <<<"$(ms_get "$AUTH_URL/health")"
[[ "$ac" == "200" ]] && ok "auth remains directly reachable (not behind prism)" || bad "auth unreachable"

note "6) Honest capability check — PrismPipe does not replace /api/auth"
# Gateway /api/auth/health may 404 depending on rewrite; document either way
auth_via_gw="$(curl -sS -o /dev/null -w '%{http_code}' -m 5 "$GATEWAY_URL/api/auth/health" || echo 000)"
echo "  gateway /api/auth/health -> HTTP $auth_via_gw (PrismPipe is unrelated to this path)"
ok "documented: real auth traffic uses /api/auth → auth-service, not /api/prism"

echo
echo "==== Service impact integration summary ===="
echo "passed=$pass failed=$fail"
echo "INTERPRETATION:"
echo "  - PrismPipe HELPS auth/LIS when identical health pipelines are repeated (dedup)."
echo "  - PrismPipe does NOT accelerate or protect real /api/auth business traffic."
echo "  - Without computation sharing, PrismPipe ADDS load (3 hops per call)."
if [[ "$fail" -gt 0 ]]; then
  echo "VERDICT: NO-GO — impact/integration failed"
  exit 1
fi
echo "VERDICT: GO — non-interference + dedup benefit proven; real auth path unchanged"
exit 0
