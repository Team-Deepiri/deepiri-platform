#!/usr/bin/env python3
"""Stage-memoization benchmark against the Cyrex AGI plane.

Answers two questions the plan depends on:

1. What does a memo lookup cost at corpus scale? It sits in front of every
   stage, so if it is slow the memo is a tax rather than a saving.
2. Does idx_pipeline_stage_inputs_memo (migration 031) actually matter? The
   shipped PK is (run_id, stage_name, input_ref), which cannot serve a lookup
   by (stage_name, input_hash).

Usage:
    CYREX_TEST_DSN=postgresql://user:pass@127.0.0.1:5434/cyrex_db \
      python3 scripts/dev/benchmarks/stage_memo_bench.py --rows 20000
"""
from __future__ import annotations

import argparse
import asyncio
import os
import statistics
import time
import uuid

import asyncpg

LOOKUP_SQL = """
SELECT o.artifact_id
FROM cyrex.pipeline_stage_inputs i
JOIN cyrex.pipeline_stage_outputs o
  ON o.run_id = i.run_id AND o.stage_name = i.stage_name
JOIN cyrex.artifacts a
  ON a.artifact_id = o.artifact_id AND a.is_deleted = FALSE
JOIN cyrex.pipeline_run_stages s
  ON s.run_id = i.run_id AND s.stage_name = i.stage_name
WHERE i.stage_name = $1 AND i.input_hash = $2 AND s.status = 'completed'
ORDER BY s.completed_at DESC NULLS LAST
LIMIT 64
"""


def pct(vals, q):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, int(round(q * (len(vals) - 1))))]


async def seed(conn, rows: int, tag: str):
    """One document, many runs/stages — mimics a corpus of memoized stages."""
    doc = await conn.fetchval(
        "INSERT INTO cyrex.documents (content_hash, status) VALUES ($1,'uploaded') "
        "RETURNING document_id",
        f"bench-{tag}",
    )
    artifact = await conn.fetchval(
        "INSERT INTO cyrex.artifacts (document_id, version, artifact_type, payload_json) "
        "VALUES ($1, 1, 'extraction', '{}'::jsonb) RETURNING artifact_id",
        doc,
    )
    run = await conn.fetchval(
        "INSERT INTO cyrex.pipeline_runs (document_id, status) VALUES ($1,'running') "
        "RETURNING run_id",
        doc,
    )

    stage = f"bench.extract.{tag}"
    await conn.execute(
        "INSERT INTO cyrex.pipeline_run_stages "
        "(run_id, stage_name, status, producer, completed_at) "
        "VALUES ($1,$2,'completed','bench',NOW())",
        run,
        stage,
    )
    await conn.execute(
        "INSERT INTO cyrex.pipeline_stage_outputs (run_id, stage_name, artifact_id, output_type) "
        "VALUES ($1,$2,$3,'extraction')",
        run,
        stage,
        artifact,
    )

    hashes = [uuid.uuid4().hex + uuid.uuid4().hex for _ in range(rows)]
    await conn.executemany(
        "INSERT INTO cyrex.pipeline_stage_inputs (run_id, stage_name, input_hash, input_ref) "
        "VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING",
        [(run, stage, h, f"ref-{i}") for i, h in enumerate(hashes)],
    )
    return stage, hashes


async def bench_lookups(conn, stage, hashes, n):
    samples = []
    for i in range(n):
        h = hashes[i % len(hashes)]
        t0 = time.perf_counter()
        await conn.fetch(LOOKUP_SQL, stage, h)
        samples.append((time.perf_counter() - t0) * 1000.0)
    return samples


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=20000)
    ap.add_argument("--lookups", type=int, default=300)
    args = ap.parse_args()

    dsn = os.environ["CYREX_TEST_DSN"]
    conn = await asyncpg.connect(dsn)
    tag = uuid.uuid4().hex[:8]

    try:
        print(f"seeding {args.rows} stage-input rows...")
        t0 = time.perf_counter()
        stage, hashes = await seed(conn, args.rows, tag)
        print(f"  seeded in {time.perf_counter()-t0:.1f}s")

        total = await conn.fetchval("SELECT count(*) FROM cyrex.pipeline_stage_inputs")
        print(f"  pipeline_stage_inputs total rows: {total}")
        await conn.execute("ANALYZE cyrex.pipeline_stage_inputs")

        print("\n--- WITH idx_pipeline_stage_inputs_memo (migration 031) ---")
        warm = await bench_lookups(conn, stage, hashes, 30)
        with_idx = await bench_lookups(conn, stage, hashes, args.lookups)
        plan = await conn.fetchval(
            f"EXPLAIN (FORMAT TEXT) {LOOKUP_SQL}", stage, hashes[0]
        )
        print(f"  p50={pct(with_idx,0.5):.3f}ms  p95={pct(with_idx,0.95):.3f}ms  "
              f"mean={statistics.mean(with_idx):.3f}ms")
        print(f"  plan: {plan.strip().splitlines()[0][:100]}")

        print("\n--- WITHOUT the index (dropped, then restored) ---")
        await conn.execute("DROP INDEX IF EXISTS cyrex.idx_pipeline_stage_inputs_memo")
        await conn.execute("ANALYZE cyrex.pipeline_stage_inputs")
        await bench_lookups(conn, stage, hashes, 10)
        without = await bench_lookups(conn, stage, hashes, max(40, args.lookups // 5))
        plan_no = await conn.fetchval(
            f"EXPLAIN (FORMAT TEXT) {LOOKUP_SQL}", stage, hashes[0]
        )
        print(f"  p50={pct(without,0.5):.3f}ms  p95={pct(without,0.95):.3f}ms  "
              f"mean={statistics.mean(without):.3f}ms")
        print(f"  plan: {plan_no.strip().splitlines()[0][:100]}")

        await conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_pipeline_stage_inputs_memo "
            "ON cyrex.pipeline_stage_inputs (stage_name, input_hash)"
        )
        print("\n  index restored.")

        speedup = statistics.mean(without) / max(statistics.mean(with_idx), 1e-9)
        print(f"\n  index speedup at {total} rows: {speedup:.1f}x")

    finally:
        # Bench rows are disposable; drop them so repeat runs stay comparable.
        await conn.execute(
            "DELETE FROM cyrex.documents WHERE content_hash LIKE 'bench-%'"
        )
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
