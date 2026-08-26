# Cheap one-box VPS decision (PR #304)

Decision notes for hosting the non-AI platform stack from `docker-compose.yml` on a single cheap VPS. Companion to CloudInfra and [PR #304](https://github.com/Team-Deepiri/deepiri-platform/pull/304).

**Reviewer:** @daev1005 (David Li)

---

## Minimum services on the VPS (cloud portal — post-decoupling)

**Hard rule:** no Cyrex, LIS, speech, Kafka, or messaging on the VPS.

| Role | Services |
|------|----------|
| Edge / portal | `platform-frontend`, `nginx`, `certbot`, `api-gateway`, `auth-service` |
| Portal domain | `registry`, `jobs`, `external-bridge-service` |
| Data | **`postgres-platform`** (single DB: `platform` schema) + `redis` |
| Ops | `jobs` (`platform.pg_backup` scheduler) + optional `pg-backup-offsite` |

**Out of cloud (control plane — `deepiri-control-plane`):** Cyrex, LIS, speech, Ollama, MLflow, Milvus, Kafka, synapse, sugar-glider, truss, telemetry, messaging, realtime-gateway, etc.

See [`REPO_SPLIT.md`](REPO_SPLIT.md) and [`DATABASES_AND_COMPOSE_BY_PLANE.md`](DATABASES_AND_COMPOSE_BY_PLANE.md).

---

## Local-prod measurement (idle + load)

Updated 2026-08-26 against the *current* branch tip (consolidated single Postgres, all 18 services, including this PR's `mem_limit` caps) — supersedes the 2026-08-12 three-Postgres-container numbers below.

**Idle** (`ops/benchmark-results/netcup-vps1000-g12-20260826T174449Z`, 90s sample):

| Metric | Value |
|--------|-------|
| Containers measured | 18 |
| Total memory snapshot | **~538.2 MiB** |
| Total CPU snapshot | **~1.37%** |
| Health | All health-checked services healthy |

**Under concurrent load** (autocannon, 200 total connections across `api-gateway`/`auth-service`/`language-intelligence-service`/`truss` simultaneously, 30s, ~330k requests, zero errors):

| Metric | Value |
|--------|-------|
| Peak memory (whole stack, single sample) | **~885 MiB** |
| Peak CPU, worst container (`language-intelligence-service`) | **~192%** (≈1.9 cores) |
| Peak CPU, next three (`api-gateway`/`truss`/`auth-service`) | 118% / 107% / 106% |
| Peak CPU, `postgres` | 46% |

Memory is not the constraint at any point tested — even under load, peak usage is ~11% of 8 GB. **CPU is the real ceiling**: if those five peaks landed simultaneously and stayed sustained, that's ~5.7 core-equivalents of demand against this box's 4 vCore, which would mean queuing/added latency under real concurrent load (not crashes — nothing here is memory-bound). `language-intelligence-service`'s `/health` does a live `SELECT 1` via Prisma per request, so its number is a reasonable stand-in for a real DB-backed request, not a trivial ping. Not tested: actual document upload/processing (Bedd + text extraction) — this harness's object storage isn't wired to a real backend, so that path — likely the single heaviest real workload — couldn't be exercised end-to-end.

**Bottom line for sizing:** fine for bursty usage (gaps between requests, which is the expected shape for a document-intelligence tool); worth watching CPU once real users hit it, if usage turns out to be more sustained/concurrent than expected.

### David Li (2026-08-26, 2:58 PM) — VPS sizing check

> **VPS sizing check: Netcup VPS 1000 G12 — suitable, with one thing to watch**
>
> Ran the full platform stack on hardware matching this VPS's specs (4 cores, 8GB RAM) and stress-tested it two ways:
>
> - **At rest:** uses under 7% of the box's memory. Huge headroom.
> - **Under simulated heavy traffic:** memory still fine, but CPU gets tight if multiple services get hit hard at the same time — the box's 4 cores could become a bottleneck under sustained concurrent load. Practically, that shows up as slower response times, not crashes or downtime.
>
> **Bottom line:** this VPS works for launch. Given how document-intelligence tools actually get used (bursts of activity, not constant high-volume traffic), it should hold up fine. Worth keeping an eye on CPU usage once we have real users, and upgrading is a quick, non-disruptive change if we ever need more headroom.
>
> **One gap:** I couldn't stress-test actual document upload/processing (the heaviest real workload) in this test environment — that's the one thing that could turn out heavier than measured.

<details>
<summary>Original 2026-08-12 measurement (stale — three Postgres containers, superseded above)</summary>

Report: `ops/benchmark-results/20260812T021218Z`.

| Metric | Value |
|--------|-------|
| Containers measured | 17 |
| Total memory snapshot | ~477.8 MiB |
| Total CPU snapshot | ~8.64% |

Top memory (idle): messaging ~41.7 MiB, postgres-core ~41.5 MiB, synapse ~40.4 MiB, language-intelligence ~39.0 MiB, auth ~37.1 MiB.

That run still used three Postgres containers; PR #304 has since consolidated to one Postgres with three logical databases (reflected in the updated numbers above, not just hypothesized).

</details>

**Implication:** An **8 GB** VPS has large memory headroom at both idle and under load (~15× measured idle RSS, ~9× peak-under-load RSS). Soft `mem_limit` caps on the compose profile sum near ~8.5 GB (ceiling if everything spikes together) — memory was never observed anywhere near that ceiling. CPU, not memory, is the dimension to actually watch on this box.

---

## Secrets / env readiness — David Li (2026-08-26, 3:40 PM)

> Here's what I got so far:
>
> **Generated** (real random secrets, 32 bytes each, never printed anywhere — including in this chat):
> `POSTGRES_PASSWORD`, `PLATFORM_DB_PASSWORD`, `INTERNAL_SERVICE_SECRET`, `JWT_SECRET`, `REDIS_PASSWORD`
>
> **Control-plane DB passwords** (`POSTGRES_AUTH_PASSWORD`, etc.) belong in **`secrets.7z` → deepiri-control-plane**, not the cloud VPS bundle.
>
> **Filled with safe, non-secret defaults** (matching what `docker-compose.yml` / `.env.example` already use — usernames, DB names, `NODE_ENV`, `BEDD_IMAGE`, service URLs, `BACKUP_RETENTION_DAYS`, `BACKUP_OFFSITE_ENABLED=false`, etc.)
>
> **Set to localhost placeholders**, flagged to update once DNS exists: `CLIENT_URL`, `CORS_ORIGIN` / `CORS_ORIGINS`, `VITE_API_URL`
>
> Also fixed along the way (unrelated to the request, but the file wouldn't have worked otherwise).
>
> **Still blocking a real deploy**, left as commented placeholders with notes. I don't think I have the resources for these:
>
> - `STORAGE_PROVIDER` / `BUCKET` / `REGION` / `ENDPOINT` / `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` — real object-storage bucket credentials. This one's hard-required by compose, so `docker compose up` will refuse to start with a clear error until it's set — that's intentional, not a bug.
> - `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` — real OAuth app credentials.
> - `BACKUP_OFFSITE_BUCKET` / `ENDPOINT` / `REGION` / `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` — **moot for now since `BACKUP_OFFSITE_ENABLED=false`**.

Target file: `ops/k8s/secrets/.env` (uncommitted). Templates: `ops/k8s/secrets-templates/cloud-portal/`. See `ops/k8s/secrets-templates/SECRETS_SPLIT.md` — **@daev1005** to publish **`cloud-portal-secrets.7z`** on Discord.

---

## Netcup VPS 1000 G12 — pick one SKU, not both

Same machine class: **4 vCore / 8 GB DDR5 ECC / 256 GB NVMe**.

| Option | Product | Setup | Price / mo | Contract | First charge (approx.) |
|--------|---------|-------|------------|----------|-------------------------|
| **A — try / cancel anytime** | `VPS 1000 G12 iv NUE hourly-based` (Nuremberg) | **€4.20** | **€11.56** | 0 months | **~€15.76** |
| B — year prepaid | `VPS 1000 G12 iv 12M` | €0.00 | €8.70 | ≥12 months | **~€104.40** (12 × €8.70) |

Do **not** add both to the cart (that becomes ~€20.26/mo for two boxes).

**Recommendation for first deploy:** Option **A** (hourly NUE). Prove the stack for one month; cancel if it does not work. Full year on hourly ≈ €4.20 + 12×€11.56 ≈ **€143** vs **€104** prepaid — ~€40 extra for no lock-in.

---

## Exact links

### Netcup (8 GB / 16 GB)

| What | URL |
|------|-----|
| VPS catalog (EN) | https://www.netcup.com/en/server/vps |
| VPS catalog (DE) | https://www.netcup.com/de/server/vps |
| **VPS 1000 G12 — 12-month prepaid** (`iv 12M`) — avoid for a 1-month trial | https://www.netcup.com/en/server/vps/vps-1000-g12-iv-12m |
| **VPS 1000 G12 — hourly / no min term** (`stundenbasiert`) | https://www.netcup.com/de/server/vps/vps-1000-g12-stundenbasiert |
| VPS 1000 G12 — hourly OpenClaw special (if still offered) | https://www.netcup.com/de/server/vps/vps-1000-g12-stundenbasiert-openclaw-special |
| VPS 2000 G12 — 16 GB, 12-month prepaid | https://www.netcup.com/en/server/vps/vps-2000-g12-iv-12m |

Checkout product names observed 2026-08-26:

- `VPS 1000 G12 iv 12M` — billing every 12 months, contract ≥12 months, “No preference Europe”, €0 setup / €8.70/mo
- `VPS 1000 G12 iv NUE hourly-based` — billing every 1 month, contract ≥0 months, Nuremberg, €4.20 setup / €11.56/mo

### OVHcloud (VPS-2 ≈ 4 vCore / 8 GB / 75 GB NVMe, ~$8.50/mo)

| What | URL |
|------|-----|
| VPS plans (worldwide) | https://www.ovhcloud.com/en/vps/ |
| VPS plans (US) | https://us.ovhcloud.com/vps/ |
| **Order / configurator (US)** | https://us.ovhcloud.com/vps/configurator/ |
| 8 GB overview | https://www.ovhcloud.com/en/vps/vps-8gb/ |

### Hetzner Cloud (hourly → monthly cap; cancel by deleting the server)

| What | URL |
|------|-----|
| Cloud overview | https://www.hetzner.com/cloud/ |
| **CX33** Cost-Optimized (4 vCPU / 8 GB / 80 GB) | https://www.hetzner.com/cloud/cost-optimized/ |
| **CPX32** Regular Performance (4 vCPU / 8 GB / 160 GB) | https://www.hetzner.com/cloud/regular-performance/ |
| Create / manage servers | https://console.hetzner.com/ |

### Contabo (staging only)

| What | URL |
|------|-----|
| Cloud VPS | https://contabo.com/en-us/vps/ |

### Related docs / PR

| What | URL |
|------|-----|
| Platform PR #304 (cheap one-box compose) | https://github.com/Team-Deepiri/deepiri-platform/pull/304 |
| CloudInfra Google Doc | https://docs.google.com/document/d/1dueFs3c2O74jn6X-5sLQtAHuMt_lmIs_UrdRL1hPgS0/edit |
| CloudInfra metrics tab | https://docs.google.com/document/d/1dueFs3c2O74jn6X-5sLQtAHuMt_lmIs_UrdRL1hPgS0/edit?tab=t.hluss5r9vfxc |

---

## Month-to-month alternatives (same ~4 vCPU / 8 GB class)

| Provider / plan | Specs (approx.) | ~Price / mo | Notes |
|-----------------|-----------------|-------------|-------|
| OVHcloud VPS-2 | 4 vCore / 8 GB / 75 GB NVMe | ~$8.50 | Best simple 1-month try outside Netcup. Links above. |
| Hetzner CX33 | 4 vCPU / 8 GB / 80 GB | ~€6.50–8 (+ IPv4) | Cost-Optimized stock can be limited. |
| Hetzner CPX32 | 4 vCPU / 8 GB / 160 GB | ~€14–16 | More disk; still cancel anytime. |
| Contabo ~8 GB | varies | often cheaper | Treat as **staging only** (reliability tradeoffs). |

Netcup’s **256 GB** disk is the outlier vs OVH/Hetzner CX (~75–80 GB). Fine for lean compose; tighter once images + Postgres + local backups grow.

If memory headroom matters more than ~€10/mo: Netcup **VPS 2000 G12** (16 GB) — prefer hourly if available; 12M link in Exact links above.

---

## Still needed after the box exists

1. Domain + DNS (Let’s Encrypt needs a real hostname; update `CLIENT_URL` / `VITE_API_URL` / `CORS_ORIGINS`).
2. **Object storage credentials** (`STORAGE_*`) — hard gate for compose; pick S3/R2/B2/Spaces/MinIO and fill keys.
3. Google OAuth app (`GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`) if login via Google is in scope for launch.
4. Off-box backup bucket only if flipping `BACKUP_OFFSITE_ENABLED=true` (optional at launch while false).
5. Runtime validation of PR #304 on the real VPS; watch **CPU** under concurrent load and document-upload path once available.

TLS via certbot in-compose is $0 once DNS points at the box.

---

## Decision summary

| Question | Answer |
|----------|--------|
| Will 8 GB run the PR #304 stack? | **Yes** — idle ~538 MiB, peak ~885 MiB under simulated concurrent load. Memory is not the constraint; CPU is. |
| CPU risk? | **Watch under concurrent load** — 4 cores can tighten (~5.7 core-eq peaks vs 4 vCore); upgrade if needed. |
| Document upload risk? | **Not stress-tested yet** — heaviest path may be heavier than measured. |
| Cheapest credible “try one month”? | Netcup **hourly NUE** (~€16 first charge) or OVHcloud **VPS-2** (~$8.50/mo). |
| Buy the 12M prepaid now? | Only if committing for a year; otherwise skip. |
| Deploy blocked on? | Real `STORAGE_*` (hard), Google OAuth if needed, DNS URLs; offsite backup optional while `BACKUP_OFFSITE_ENABLED=false`. |
| CloudInfra “Metrics Confirm” tab? | Historical Aug 12 idle (~478 MiB); **superseded** by Aug 26 idle+load numbers above. |
