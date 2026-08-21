"""Shared helpers for dev benchmarks."""
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any


def http_req(method: str, url: str, body=None, headers=None) -> tuple[float, int, Any]:
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
    except Exception as exc:
        text = (raw or b"").decode("utf-8", errors="replace")
        print(
            f"warning: JSON parse failed for {method} {url}: {exc}; body={text[:200]!r}",
            file=sys.stderr,
        )
        return ms, code, text
    return ms, code, parsed
