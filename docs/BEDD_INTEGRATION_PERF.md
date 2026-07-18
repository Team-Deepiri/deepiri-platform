# Bedd integration + performance experiment

Base branch: `bao_t/feature/kafka-redis-streams-integration` (platform PR #184).

## What this is

Optional [deepiri-bedd](https://github.com/Team-Deepiri/deepiri-bedd) worker on the Sugar Glider bus.
**Not** a replacement for Cyrex / Helox / LIS. LIS document-bus cohesion is a separate feature ([LIS PR #64](https://github.com/Team-Deepiri/deepiri-language-intelligence-service/pull/64)).

## Run (overlay)

```bash
docker compose -f docker-compose.dev.yml -f docker-compose.bedd.yml up -d synapse-sugar-glider deepiri-bedd
curl -s http://127.0.0.1:9108/metrics
```

Routes: [`deploy/bedd/tinder.document-bus.json`](../deploy/bedd/tinder.document-bus.json) (host-owned; Bedd core stays topic-agnostic).

## Perf dimensions

| Dimension | How measured |
|-----------|----------------|
| Throughput (strikes/s) | `bedd bench` / host publish→consume loop |
| Latency p50/p95/p99 | strike wall time |
| Error rate | failed strikes / iterations |
| Publish + ack counts | ember metrics / mock counters |
| Skill mix | echo / redact / fingerprint |
| Bus hop cost | baseline SG publish/read vs Bedd strike path |

### Mock-bus results (Bedd 0.6.0, local ReleaseSafe)

| run | n | ok | err% | thr/s | mean ms | p50 | p95 | p99 |
|-----|---|----|------|-------|---------|-----|-----|-----|
| echo_50 | 50 | 50 | 0.00 | ~2500 | ~0.3 | 0 | 1 | 1 |
| mix_50 | 50 | 50 | 0.00 | ~2500 | ~0.4 | 0 | 1 | 1 |
| mix_200 | 200 | 200 | 0.00 | ~1740 | ~0.5 | 0 | 1 | 1 |
| redact_100 | 100 | 100 | 0.00 | ~1667 | ~0.5 | 1 | 1 | 1 |

Reproduce:

```bash
cd ../deepiri-bedd   # or clone Team-Deepiri/deepiri-bedd
zig build -Doptimize=ReleaseSafe -Dcpu=baseline
./scripts/perf-matrix.sh
```

### Host-bus (Sugar Glider) comparison

With stack up:

1. **Baseline:** `POST /v1/publish` + `POST /v1/read` + ack on `document.artifacts` (no Bedd).
2. **With Bedd:** same publish; Bedd consumes → skill → publish `inference-events`; measure end-to-end.

Expect Bedd to add skill+extra hop latency. It is a **win** when you need portable skill transforms on the bus; a **regression** if inserted on every event with no skill work.

## Verdict

**Mock path:** healthy — no regressions in Bedd 0.6.0 bench (0% errors, sub-ms p95 on local mock).

**Host path:** use Bedd **selectively** on streams that need skill processing (redact/fingerprint/WASM). Do **not** put Bedd on every platform/LIS hop by default — that would increase latency without product benefit.

**Final answer:** Bedd improves the architecture when used as an optional skill worker on chosen streams; it does **not** improve a pure transport closed loop versus SG alone. Prefer LIS/Cyrex/Helox ownership of business consumers; add Bedd where a portable skill runtime is the missing piece.
