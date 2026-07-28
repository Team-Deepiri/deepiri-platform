# PrismPipe Repurposing Plan — from session cache to Cyrex AGI execution engine

**Status:** Phase 0 in progress
**Owner:** josep
**Date:** 2026-07-28

---

## 1. Why this plan exists

PrismPipe was wired into the platform as a session/auth accelerator. Measurements
on the live dev stack say that role does not justify a service, and the Cyrex AGI
plane (platform PRs #291/#292) has a much better job for the same machinery.

### What the measurements showed

| Path | conc=1 | conc=8 | conc=32 |
|---|---|---|---|
| `auth/verify` direct | 1.6ms p50 · 589 rps | 7.6ms · 957 rps | 26.7ms · 1150 rps |
| PrismPipe session, sharing **on** | 0.75ms · 1215 rps | 2.7ms · 2334 rps | 8.1ms · 2964 rps |
| PrismPipe session, sharing **off** | 3.2ms · 293 rps | 8.3ms · 874 rps | 37ms · 557 rps |

With computation sharing off, PrismPipe is **worse than auth alone at every
concurrency level**. 100% of the measured win is a 15-second TTL cache in front
of a 1.6ms JWT check. None of it comes from organisms, ancestry, DNA, or swarms.
A cache that cheap belongs in the gateway, not in a separate service with its own
availability and failure domain.

### What is actually wired today

- No frontend consumer. The web app calls `/agent/sessions` (Cyrex), never PrismPipe.
- Registered engine capabilities are five health probes, a session bootstrap, two
  benchmark nodes, and demo stubs.
- `DocumentVectorizeNode` (710 lines) — the only substantive capability — is **never
  registered with the engine**. Referenced solely by its own tests.
- Total platform integration: `prismSession.ts` (164 lines, gateway) +
  `sessionPrewarm.ts` (75 lines, auth-service) + compose wiring.

### Defects found and their status

| Defect | Evidence | Status |
|---|---|---|
| Hydrated L1 cache entry never expired — capability TTL unenforced on multi-worker deploys, so a revoked/expired JWT stayed authenticated for the life of the worker | 4/8 single probes after a full TTL gap served `path=cache` with `redis_dbsize=0` | **Fixed** (Phase 0) |
| `FakeRedis` test double ignored `ex` entirely, so no test could model expiry | The bug above shipped undetected | **Fixed** (Phase 0) |
| Organism executor has no max-hop guard | Self-routing capability ran 3,652 hops in 5s without terminating | **Phase 0** |
| `_nodes`/`_outputs`/`_hash_to_node` unbounded; swept only on lookup | 400 unique tokens → ~+2.4 MiB retained past TTL | **Phase 0** |
| `/auth/logout` returns 200 but the token still verifies — no revocation exists | Confirmed against live auth-service | **Out of scope — separate ticket, higher value than any of the above** |

---

## 2. The real job: drive the Cyrex AGI plane

The Week-2 migrations (`scripts/database/cyrex/`, commit `6e465e3`) define a
content-addressed, provenance-tracked, pressure-driven document engine **in SQL
with no engine behind it**. `grep -rn "input_hash" --include=*.py` across
`diri-cyrex` returns nothing; no Python file references `stage_name` or
`pipeline_stage`.

The schema slots map almost one-to-one onto machinery PrismPipe already has:

| Cyrex AGI schema | PrismPipe machinery |
|---|---|
| `producer_registry` (producer_id → `allowed_sinks`) | `CapabilityRouter` (capability → node) |
| `pipeline_stage_inputs.input_hash` → `pipeline_stage_outputs.artifact_id` | `ComputationGraph` content-addressed cache |
| `pipeline_runs` / `pipeline_run_stages` / `pipeline_checkpoints` | organism hibernate / wake / replay / fork |
| `artifact_refs`, `document_versions.supersedes_version` | ancestry / lineage graph |
| `citations.extraction_pass` | repeated passes over one region |
| `pressure_cells.is_fault_zone`, `low_confidence_count`, `duel_disagreements` | termination condition for the cyclic executor |

`producer_registry` is a **better** router than PrismPipe's: it constrains which
tables each producer may write. PrismPipe's router has no such concept and should
adopt it rather than the reverse.

### The core loop

```
ingest → parse → extract → project pressure → find fault zones
   ↑                                                │
   └──── re-route fault zones to a heavier producer ┘
         (new extraction_pass)

terminate when: max(pressure) < threshold  OR  budget exhausted  OR  max passes
```

This is the "capability circular routing" idea, and `pressure_cell_metrics` is what
gives it a convergence condition. It is also why the missing cycle guard is now a
**blocker rather than a nice-to-have** — this design is a cycle by construction.

### Why content-addressing replaces TTL

The 15s TTL model is wrong for this workload. The same `input_hash` always yields
the same artifact, so entries do not expire — they are superseded by producer
version or `schema_version`. Cache invalidation largely disappears. This is a
correctness simplification, not only a performance one.

The payoff: when a correction lands and a document is re-run, every stage whose
inputs did not change is skipped. On a multi-pass LLM-heavy pipeline that is the
difference between re-paying for a full run and paying for one fault zone.
`documents.content_hash` already carries a UNIQUE index, so identical inputs across
documents collapse too.

---

## 3. Topology decision: library, not service

**PrismPipe stops being an HTTP service and becomes a library Cyrex imports.**

A loop that runs many passes per document would pay a network hop per stage and put
a second service in the failure path of a long durable pipeline. The engine must run
where `cyrex_db` and the producers live.

This is cheap: PrismPipe is already a Poetry package
(`packages = [{include = "prismpipe", from = "src"}]`, Python ^3.11, optional
asyncpg). Cyrex is Python and does not currently import it.

It also deletes the entire auth/session/gateway integration as a side effect.

### Keep / cut

**Keep** — `ComputationGraph` (repointed at `pipeline_stage_inputs`, Postgres-durable),
`CapabilityRouter` (backed by `producer_registry`, enforcing `allowed_sinks`),
cross-process single-flight coalescing, the cyclic executor once guarded,
`core/` (envelope, node, pipeline — the pipeline loop already has `max_iterations`).

**Cut** — organisms-as-living-entities, `swarm.py`, `dna.py`, `memory_graph.py`,
`intent/`, the session pipeline, the five health-probe nodes, the demo routes,
`bench_nodes.py`, the FastAPI `server.py`, the compose service, the gateway route,
the auth-service prewarm.

---

## 4. Phases

Each phase ends with something observable. No phase depends on a later one.

### Phase 0 — stop the bleeding, decouple *(this session)*

1. ~~Hydrated-cache TTL fix + regression test~~ **done**
2. Cycle guard on the organism executor (bounded hops, terminate with a reason)
3. LRU bound on `ComputationGraph` so payload size stops being unbounded
4. Remove `sessionPrewarm` from auth-service (awaited on register/login/refresh)
5. Remove `prismSession.ts` route from the gateway
6. Remove the session pipeline + health nodes from PrismPipe
7. Drop the compose service and its env wiring

**Verification:** login-path benchmark before/after; full PrismPipe test suite green.

### Phase 1 — `prismpipe-core` as a Cyrex dependency

1. Trim the package to the keep-list above; `server.py` and FastAPI extra removed
2. Add `deepiri-prismpipe` to Cyrex's Poetry dependencies (path or git ref)
3. Import smoke test in Cyrex CI (`from prismpipe.engine import ComputationGraph`)

**Verification:** Cyrex boots with the import; `poetry.lock` regenerated; CI green.

### Phase 2 — Postgres-backed ComputationGraph on the real schema

1. New store implementing lookup/record against `pipeline_stage_inputs.input_hash`
   and `pipeline_stage_outputs.artifact_id` instead of Redis blobs
2. Content-addressed keys — no TTL; invalidation by producer/schema version
3. Keep Redis single-flight for concurrent identical stage execution

**Verification:** re-running an unchanged document skips every stage; a document
with one changed section re-runs only the affected stages. Assert against
`pipeline_run_stages.status` counts.

### Phase 3 — producer-registry-backed router

1. `CapabilityRouter` loads producers from `cyrex.producer_registry`
2. Enforce `allowed_sinks` on write — a producer writing outside its sinks raises
3. Record `pipeline_run_stages.producer` from the resolved registration

**Verification:** a producer attempting an unauthorized sink fails a test.

### Phase 4 — the pressure loop

1. Executor reads `pressure_cells` / `pressure_cell_metrics` after each pass
2. Fault zones re-routed to a heavier producer, incrementing `citations.extraction_pass`
3. Terminate on pressure threshold, pass ceiling, or budget
4. Checkpoint to `pipeline_checkpoints` so a killed run resumes without re-paying

**Verification:** a seeded low-confidence region triggers exactly one re-extraction
pass and then converges; killing the process mid-run and restarting resumes.

---

## 5. Risks

- **Phase 2 is the load-bearing one.** If real documents rarely share stage inputs,
  memoization pays little. Measure hit rate on `pipeline_stage_inputs` before
  building Phases 3–4 on the assumption.
- **LangGraph overlap.** Cyrex already has LangGraph for cyclic execution. The
  differentiator is cross-run, cross-document content-addressed memoization —
  LangGraph checkpoints are per-thread and will never dedupe across documents. If
  Phase 2's hit rate is poor, prefer LangGraph and retire PrismPipe entirely.
- **Scope.** Phases 2–4 are real projects, not an afternoon. Phase 0 and 1 stand
  on their own: the platform gets simpler and nothing depends on finishing.

---

## 6. Benchmarks to keep running

- `scripts/dev/benchmarks/login_path_bench.py` — register/login/refresh cost;
  proves the decoupling did not regress auth.
- Phase 2 onward: stage-skip rate and wall time for re-running an unchanged
  document versus a one-section change.
