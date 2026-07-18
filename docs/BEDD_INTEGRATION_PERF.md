# Bedd integration (runtime, not a service)

Base: `bao_t/feature/kafka-redis-streams-integration` (platform PR #184).

## Model (like Bun)

| Bun | Bedd |
|-----|------|
| `oven/bun` image / install script | `ghcr.io/team-deepiri/bedd` / `install.sh` |
| `COPY --from=bun` into app Dockerfile | `COPY --from=bedd /usr/local/bin/bedd` into **worker** Dockerfile |
| `bun run` / `bun test` | `bedd serve` / `bedd eval` / `bedd bench` |
| Not a Redis-side microservice | Not a Sugar Glider-side microservice |

LIS owns document.* routing ([LIS PR #64](https://github.com/Team-Deepiri/deepiri-language-intelligence-service/pull/64)). Cyrex/Helox own their consumers. Bedd is optional tooling **inside** a worker image that needs portable skills.

## Install into a worker

See [`deploy/bedd/Dockerfile.snippet.md`](../deploy/bedd/Dockerfile.snippet.md). Example routes: [`deploy/bedd/tinder.document-bus.json`](../deploy/bedd/tinder.document-bus.json).

## Perf

Mock matrix (Bedd 0.6, local): 0% errors, ~1.5–2.5k strikes/s, p95 ≤1ms on mock bus.

```bash
# from a deepiri-bedd checkout
./scripts/perf-matrix.sh
```

Host A/B (optional): measure SG publish/read/ack alone vs same path with a worker that runs `bedd serve` after installing Bedd into that worker image.

## Verdict

**Use Bedd** when a worker needs a portable skill runtime on the bus (redact/fingerprint/WASM).  
**Do not** invent a separate compose service for it — that fights the Bun model and adds hop inventory without ownership clarity.  
**Final:** better *as installed runtime in the right worker*; worse *as a freestanding platform service on every hop*.
