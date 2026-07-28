#!/usr/bin/env bash
# Warm PrismPipe throughput gate — concurrent identical pipeline requests.
# Expects dedup to keep p95 low and sustain MIN_WARM_RPS.
set -euo pipefail

PRISM_URL="${PRISM_URL:-http://127.0.0.1:5011}"
THROUGHPUT_N="${THROUGHPUT_N:-100}"
THROUGHPUT_CONCURRENCY="${THROUGHPUT_CONCURRENCY:-8}"
MIN_WARM_RPS="${MIN_WARM_RPS:-50}"
MAX_WARM_P95_MS="${MAX_WARM_P95_MS:-50}"

echo "==> preflight"
curl -sf "$PRISM_URL/health" >/dev/null
# warm the cache once
curl -sf -X POST "$PRISM_URL/pipelines/deepiri/health" \
  -H 'Content-Type: application/json' \
  -d '{"input":{"probe":"throughput"},"use_computation_sharing":true}' >/dev/null

echo "==> throughput N=$THROUGHPUT_N concurrency=$THROUGHPUT_CONCURRENCY"
python3 - "$PRISM_URL" "$THROUGHPUT_N" "$THROUGHPUT_CONCURRENCY" "$MIN_WARM_RPS" "$MAX_WARM_P95_MS" <<'PY'
import json, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

url = sys.argv[1].rstrip("/") + "/pipelines/deepiri/health"
n = int(sys.argv[2])
conc = int(sys.argv[3])
min_rps = float(sys.argv[4])
max_p95 = float(sys.argv[5])
payload = json.dumps({"input": {"probe": "throughput"}, "use_computation_sharing": True}).encode()

def one(_i: int) -> float:
    req = urllib.request.Request(
        url, data=payload, headers={"Content-Type": "application/json"}, method="POST"
    )
    t0 = time.perf_counter()
    # Cold path can be ~10s when auth+LIS are probed; warm hits should be <50ms.
    with urllib.request.urlopen(req, timeout=30) as resp:
        if resp.status != 200:
            raise RuntimeError(f"status {resp.status}")
        resp.read()
    return (time.perf_counter() - t0) * 1000.0

# Extra sequential warms so the in-process ComputationGraph is populated
# before the concurrent burst (important with multi-worker deploys).
for _ in range(3):
    one(-1)

latencies = []
t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=conc) as pool:
    futs = [pool.submit(one, i) for i in range(n)]
    for f in as_completed(futs):
        latencies.append(f.result())
wall = time.perf_counter() - t0
rps = n / wall if wall > 0 else 0.0
latencies.sort()
p95 = latencies[min(len(latencies) - 1, int(round(0.95 * (len(latencies) - 1))))]
avg = sum(latencies) / len(latencies)

metrics = json.loads(urllib.request.urlopen(sys.argv[1].rstrip("/") + "/metrics", timeout=5).read())
hit = float(metrics.get("hit_ratio", 0))

print(f"  wall={wall:.3f}s rps={rps:.1f} avg_ms={avg:.3f} p95_ms={p95:.3f} hit_ratio={hit}")

fails = []
if rps < min_rps:
    fails.append(f"rps {rps:.1f} < {min_rps}")
if p95 > max_p95:
    fails.append(f"p95 {p95:.3f}ms > {max_p95}ms")
if hit < 0.5:
    fails.append(f"hit_ratio {hit} < 0.5")

if fails:
    print("THROUGHPUT GATE FAILED:")
    for f in fails:
        print(f"  - {f}")
    raise SystemExit(1)
print("THROUGHPUT GATE PASSED")
PY
