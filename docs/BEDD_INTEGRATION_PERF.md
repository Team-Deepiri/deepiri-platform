# Bedd bus integration + performance

Bedd is embedded **into worker images** (Bun-style), not a Compose sidecar.

## Embed

Install/embed recipes live in [deepiri-bedd docs/INSTALL.md](https://github.com/Team-Deepiri/deepiri-bedd/blob/main/docs/INSTALL.md) (`install.sh` + image Dockerfile). Platform only `COPY --from` that image.

Images that include `/usr/local/bin/bedd`:

| Image | libc |
|-------|------|
| deepiri-suite (alpine + slim) | musl or gnu (auto) |
| diri-cyrex (+cpu, cyrex-agi) | gnu |
| deepiri-modelkit | gnu |
| LIS, RTG, messaging, decision-intelligence, external-bridge, adaptive-experience, communications-hub, api-gateway | musl (suite alpine) |
| workflow-orchestrator | gnu (node:18-slim) |
| prismpipe, synapse | gnu |

Sugar Glider is transport-only — **not** embedded.

## Env (host / compose)

```yaml
BEDD_BUS_URL: ${BEDD_BUS_URL:-redis://redis:6379}
BEDD_DLQ_STREAM: ${BEDD_DLQ_STREAM:-bedd.dlq}
BEDD_SKILLS_DIR: /opt/bedd/skills
```

## Perf matrix (mock Redis)

Run from [deepiri-bedd](https://github.com/Team-Deepiri/deepiri-bedd):

```bash
./scripts/perf-matrix.sh
# or: zig build && zig-out/bin/bedd bench --scenario mix --n 200 --mock-redis
```

### Results (2026-07-18, ReleaseSafe baseline, mock Redis)

| run | n | err% | thr/s | p95 |
|-----|---|------|-------|-----|
| echo_50 | 50 | 0 | ~2500 | 1ms |
| mix_50 | 50 | 0 | ~2500 | 1ms |
| mix_200 | 200 | 0 | ~1740 | 1ms |
| redact_100 | 100 | 0 | ~1667 | 1ms |

**Verdict:** Better with Bedd when a **specific worker** needs portable stream skills (`echo` / `passthrough` / `redact` / `fingerprint` / `schema_gate`) on Redis Streams. Worse as a freestanding Compose sidecar on every hop — do not add `docker-compose.bedd.yml`.

## A/B host check (optional)

With stack up and Bedd in a worker image:

```bash
docker compose exec <worker> bedd help
docker compose exec <worker> bedd bench --scenario mix --n 50 --mock-redis
```
