#!/usr/bin/env python3
"""Login-path benchmark: what does a JWT cost to mint?

auth-service used to await prewarmPrismSession() on register/login/refresh, so
every minted token paid a synchronous PrismPipe round trip. This measured that
tax end-to-end so removing it could be proven rather than asserted, and stays
as the regression guard on token-mint cost.

Note when comparing runs: register's INSERT slows as the users table grows, so
a long benchmark session inflates its own baseline. refresh does no DB write
and is the cleanest signal.

Run before and after the change with identical flags:
    python3 scripts/dev/benchmarks/login_path_bench.py --n 40 --label before
"""
from __future__ import annotations

import argparse
import json
import statistics
import time
import urllib.error
import urllib.request

AUTH = "http://127.0.0.1:5001"
PASSWORD = "BenchUser123!x9z"


def req(method: str, url: str, body=None, headers=None):
    h = dict(headers or {})
    data = json.dumps(body).encode() if body is not None else None
    if data:
        h.setdefault("Content-Type", "application/json")
    r = urllib.request.Request(url, data=data, headers=h, method=method)
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            raw = resp.read()
            code = resp.status
    except urllib.error.HTTPError as e:
        raw, code = e.read(), e.code
    ms = (time.perf_counter() - t0) * 1000.0
    try:
        parsed = json.loads(raw or b"{}")
    except Exception:
        parsed = {}
    return ms, code, parsed


def pct(vals, q):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, int(round(q * (len(vals) - 1))))]


def summarize(name, samples, codes):
    bad = {c for c in codes if c >= 400}
    return {
        "op": name,
        "n": len(samples),
        "p50": pct(samples, 0.50),
        "p95": pct(samples, 0.95),
        "mean": statistics.mean(samples),
        "errors": sorted(bad),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=40)
    ap.add_argument("--warmup", type=int, default=5)
    ap.add_argument("--label", default="run")
    args = ap.parse_args()

    reg_ms, log_ms, ref_ms = [], [], []
    reg_codes, log_codes, ref_codes = [], [], []

    for i in range(args.warmup + args.n):
        keep = i >= args.warmup
        email = f"bench-{args.label}-{int(time.time()*1000000)}-{i}@deepiri.local"

        ms, code, _ = req("POST", f"{AUTH}/auth/register",
                          {"email": email, "password": PASSWORD, "username": "bench"})
        if keep:
            reg_ms.append(ms)
            reg_codes.append(code)

        ms, code, body = req("POST", f"{AUTH}/auth/login",
                             {"email": email, "password": PASSWORD})
        if keep:
            log_ms.append(ms)
            log_codes.append(code)

        token = body.get("token")
        if token:
            ms, code, _ = req("POST", f"{AUTH}/auth/refresh", {},
                              {"Authorization": f"Bearer {token}"})
            if keep:
                ref_ms.append(ms)
                ref_codes.append(code)

        time.sleep(0.05)

    rows = [summarize("register", reg_ms, reg_codes),
            summarize("login", log_ms, log_codes)]
    if ref_ms:
        rows.append(summarize("refresh", ref_ms, ref_codes))

    print(f"\nlogin path — label={args.label} n={args.n} warmup={args.warmup}")
    print(f"{'op':<10} {'p50':>9} {'p95':>9} {'mean':>9}   errors")
    print("-" * 52)
    for r in rows:
        print(f"{r['op']:<10} {r['p50']:8.2f}ms {r['p95']:8.2f}ms {r['mean']:8.2f}ms   "
              f"{r['errors'] or 'none'}")
    print()
    print(json.dumps({"label": args.label, "rows": rows}))


if __name__ == "__main__":
    main()
