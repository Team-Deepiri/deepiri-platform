# Audit: Is Bedd load-bearing, or should it be scrapped?

**Date:** 2026-08-21
**Scope:** `deepiri-bedd` (Zig runtime, currently pinned `ghcr.io/team-deepiri/bedd:0.8`) and its footprint across the Deepiri platform.
**Question on the table:** does Bedd earn its place in the ecosystem, or is it dead weight that should be removed.

## TL;DR — UPDATED after checking actual invocations (see "Correction" below)

**Do not scrap the redaction capability — but the "13-service platform runtime" story is mostly aspirational.** A follow-up pass that actually greps entrypoints/Dockerfiles/app source (not just docs and env vars) found that of the 13+ images that `COPY --from=bedd`, **exactly one** — `deepiri-external-bridge-service` — actually spawns the binary at runtime (`bedd filter redact` from `src/beddRedactor.ts`, gating webhook payloads before delivery). Everything else sets `BEDD_SKILLS_DIR`/`BEDD_BUS_URL`/`BEDD_DLQ_STREAM` and copies the binary in, but nothing calls it. The document-bus `tinder.document-bus.json` route (redact/fingerprint on `document.artifacts`/`document.vectorize`) that the original audit treated as evidence of LIS integration turns out to be **dead config** — LIS's own Dockerfile never even copies the bedd binary; the compose `bedd-build-args` it receives are unconsumed.

This reframes the question. It's not "is Bedd load-bearing across the platform" — today it's load-bearing in exactly one service. See options below.

## What Bedd actually is

- A Bun-style CLI/runtime (Zig, `bedd serve` / `bedd eval` / `bedd filter` / `bedd bench`), **not** a platform microservice.
- Consumed via `COPY --from=ghcr.io/team-deepiri/bedd:0.8` into a host image — same pattern as `oven/bun`.
- Owns: bus client shape, route table (`tinder.json`), skill ABI (native + wasm3), serve loop, admin `:9108 /healthz /metrics`, DLQ stream name (`docs/adr/ADR-001`).
- Explicitly does **not** own: stream names, domain skills, or message storage — those stay host-side by design.
- Builtin skills: `echo`, `passthrough`, `redact`, `fingerprint`, `schema_gate`, `drop_fields`.

## Evidence of real use (not just aspirational docs)

1. **Actively maintained.** 20 commits visible in history, latest `fix(redact,filter): case-insensitive key match + unwrapClean false-positive` on 2026-08-10 — 11 days before this audit. Has CI, CodeQL, a PR template, CONTRIBUTING/SECURITY/CODEOWNERS — treated like a real component, not an abandoned experiment.
2. **Embedded in a wide set of worker images** (per `deepiri-platform/docs/BEDD_INTEGRATION_PERF.md`): deepiri-suite (alpine+slim), diri-cyrex, deepiri-modelkit, LIS, RTG, messaging, decision-intelligence, external-bridge, adaptive-experience, communications-hub, api-gateway, workflow-orchestrator, prismpipe, synapse — 13+ images carry the binary.
3. **Concretely wired, not just installed**, in at least the document pipeline: `deepiri-platform/deploy/bedd/tinder.document-bus.json` routes `document.artifacts` → `redact` skill and `document.vectorize` → `fingerprint` skill, both publishing to `inference-events`. `docker-compose.dev.yml` sets `BEDD_BUS_URL`, `BEDD_SKILLS_DIR`, `BEDD_DLQ_STREAM` for the language-intelligence-service.
4. **It is the PII redaction layer** for document artifacts before they reach `inference-events` / training capture. This is the actual product value: a single Zig binary doing redaction/fingerprinting at native speed instead of every worker reimplementing it, per `docs/ADR-001-bedd-runtime.md`'s stated goal (no host-specific topic catalogs forked into every service).
5. **Deliberately constrained scope, which is a good sign, not a bad one.** `docs/VALUE.md` explicitly lists what Bedd does *not* help with (replacing the bus, trivial in-process transforms, embedding without invoking) — this is a team that has already pushed back on scope creep once (the README literally says "Do not run Bedd as a separate compose service next to Sugar Glider").

## The actual finding: unmonitored dead-letter queue

`deepiri-platform/docs/architecture/DEEPIRI_DATA_PIPELINE_DEEP_REFERENCE_AND_GAPS.md` (G2, rated **High**):

> `pipeline.dead-letter` and `bedd.dlq` have producers (Cyrex pipeline, PrismPipe ops store) but **no drainer/alerting consumer** anywhere. Poison records accumulate invisibly.

Concretely: when `bedd`'s redact/fingerprint skill fails on a document, the failed record goes to `bedd.dlq` and nothing reads it. That means (a) redaction failures on document artifacts are silent — the opposite of what a PII-safety component should do — and (b) nobody can tell today whether Bedd is quietly failing on a subset of traffic.

This is not a reason to scrap Bedd; it's a reason to finish wiring it. The runtime side (skills, routing, chains, recovery_skill) is done and benchmarked (`scripts/perf-matrix.sh`, ~1700-2500 msg/s on mock Redis). The operational side (someone reads the DLQ) is not.

## Correction: install breadth vs. invocation depth (verified, not inferred)

A repo-wide grep of Dockerfiles, entrypoint scripts, compose configs, and app source across the platform + submodules found:

| Service | COPYs bedd binary | Actually invokes it at runtime |
|---|---|---|
| **deepiri-external-bridge-service** | Yes | **Yes** — `src/beddRedactor.ts:29` spawns `bedd filter redact`, called from `webhookService.ts:318` to redact outbound webhook payloads. Gated by `BEDD_REDACT_ENABLED` (default true). This is real, load-bearing, PII-safety code. |
| deepiri-suite, synapse, RTG, messaging, truss, jobs, telemetry, registry | Yes | No — binary copied, env vars set, nothing spawns it |
| diri-cyrex, deepiri-modelkit, LIS, decision-intelligence, adaptive-experience, communications-hub, api-gateway, workflow-orchestrator | **No** — don't even copy the binary in the current tree | N/A — earlier "bedd" doc references for these are stale or aspirational |
| prismpipe | No Dockerfile in this checkout | N/A — only trace is a stale vendored `.venv` copy inside diri-cyrex showing a build-time `bedd help` smoke check, not runtime use |

So: **one real caller** (external-bridge, webhook redaction), one dead route config (`tinder.document-bus.json`, unreferenced because LIS never links the binary), and eight services carrying an unused binary + unused env vars for no current benefit.

## What this means for "should Bedd stay its own repo"

The maintenance question the team is actually asking — *we like having a Zig repo, it's useful if it's actually load-bearing, but we can't staff a dedicated Zig maintainer, could this just live inside something else* — now has a concrete anchor: **the only proven consumer is external-bridge's redaction path.**

### Option A — Status quo: standalone repo, embed everywhere (as currently documented)
Keep Bedd as an independent Zig repo, `COPY --from=ghcr.io/team-deepiri/bedd:0.8` into any host that wants a skill. Matches ADR-001 ("hosts own stream names/skills, Bedd owns runtime/ABI"), keeps native perf and one shared redact/fingerprint implementation for whenever more services adopt it.
- **For:** future-proofs the document-bus / LIS integration once it's actually built; no rewrite needed; already benchmarked (~1700-2500 msg/s mock Redis).
- **Against:** paying full repo overhead (CI, CodeQL, ADRs, CONTRIBUTING/SECURITY/CODEOWNERS, Zig toolchain) for one real caller today. Nobody owns Zig expertise if something breaks.

### Option B — Fold Bedd into `deepiri-external-bridge-service` as a vendored dependency
Since external-bridge is the only real consumer, move the Zig source (or just the compiled skill logic) into that repo, drop the separate `deepiri-bedd` repo and its GHCR image, and stop shipping the binary to the other 8 services that don't use it.
- **For:** one fewer repo/CI pipeline/release process to maintain; removes 8 services' worth of dead `COPY`/env-var cruft immediately; the Zig code doesn't need a dedicated maintainer if it's small and stable inside a repo someone already owns.
- **Against:** kills reusability — if LIS's document-bus redaction (or any other service) is ever actually finished, it either forks this logic again (the exact duplication ADR-001 exists to prevent) or has to depend cross-repo on external-bridge, which is worse than depending on a purpose-built shared repo.

### Option C — Shrink Bedd's scope instead of its ownership: library, not daemon
Keep it a separate repo (reusability preserved) but cut it down to just what's actually used: the `redact`/`fingerprint` skill logic as a linkable library + the `bedd filter` CLI mode, and drop `serve`/bus/tinder-routing/admin-metrics entirely since no service uses the daemon path today (the "13 embedded" story was env vars for a server nobody runs).
- **For:** dramatically smaller surface (skills only, no bus abstraction, no HTTP admin) — much less to maintain without a dedicated Zig dev; still reusable by any future service via the same `filter` pattern external-bridge already validated; deletes the dead `tinder.document-bus.json` / DLQ-consumer question outright since there's no daemon DLQ if there's no daemon.
- **Against:** requires an actual refactor now (remove `serve.zig`, `bus_redis.zig`, `bus_dlq.zig`, `admin/`, tinder routing) — not free, and loses the option of a shared daemon if a future use case needs the bus/exchange model (skill chains, recovery_skill, fanout).

### Option D — Reimplement redact/fingerprint natively in external-bridge, scrap Bedd entirely
Port the ~handful of skill functions (`redact`, `fingerprint`, `drop_fields`) directly into TypeScript inside external-bridge, delete `deepiri-bedd`.
- **For:** zero Zig anywhere; simplest possible ownership story; external-bridge is a Node service so no cross-language subprocess spawn overhead (`spawn('bedd', ...)` today).
- **Against:** loses whatever native-perf/correctness value the Zig implementation has today (untested claim either way — nobody has benchmarked the TS reimplementation against Bedd), and forecloses reuse entirely, which contradicts "we like having a Zig repo... if it's useful."

## Recommendation

**Option C**, with Option A as fallback if the document-bus/LIS integration is actually on the near-term roadmap (worth confirming with whoever owns that plan before deciding).

Reasoning: the repo is genuinely useful today (Option D throws away working, tested redaction logic for no proven gain) and the team explicitly said they like keeping it if it's load-bearing — it is, for external-bridge. But right now it's carrying a full daemon/bus/routing/DLQ architecture that has **zero real callers**, which is exactly the maintenance burden the team is worried about with no dedicated Zig dev to carry it. Cutting it down to the `filter`-mode skill library that's already proven in production removes most of the surface area (no `serve` loop, no bus client, no admin HTTP, no DLQ to drain) while keeping the repo, the reuse story, and the native performance for the one thing it's actually doing.

Concretely, if Option C is chosen: drop the `COPY --from=bedd` and unused `BEDD_*` env vars from the 8 services that don't invoke it (deepiri-suite, synapse, RTG, messaging, truss, jobs, telemetry, registry) as part of the same change — that's real dead weight regardless of which option wins.
