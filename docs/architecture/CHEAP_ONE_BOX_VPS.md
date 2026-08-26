# Cheap one-box VPS decision (PR #304)

Decision notes for hosting the non-AI platform stack from `docker-compose.yml` on a single cheap VPS. Companion to CloudInfra and [PR #304](https://github.com/Team-Deepiri/deepiri-platform/pull/304).

**Reviewer:** @daev1005 (David Li)

---

## Minimum services on the VPS

Shared control plane only. Heavy / experimental services stay local and call into the cloud gateway when needed.

| Role | Services |
|------|----------|
| Edge / portal | `frontend`, `nginx`, `api-gateway`, `auth-service` |
| Jobs | `jobs` |
| Realtime / messaging | `realtime-gateway`, `messaging-service`, `synapse`, `sugar-glider` |
| Data | **one** Postgres (logical DBs: `platform_auth`, `platform_core`, `platform_intelligence`) + `redis` |
| Portal domain | `registry`, `truss`, `telemetry`, `language-intelligence-service` |
| Ops (in PR) | `certbot`, `pg-backup` (+ optional `pg-backup-offsite`) |

**Out of cloud (local / later):** Cyrex, Ollama, MLflow, Milvus, etcd, MinIO, Kafka, Influx, admin UIs, prismpipe, external-bridge (Kafka-dependent).

Early priority under resource pressure was gateway + jobs first; the shippable set is the table above (what PR #304 composes).

---

## Local-prod measurement (idle)

Report: `ops/benchmark-results/20260812T021218Z` (2026-08-12).

| Metric | Value |
|--------|-------|
| Containers measured | 17 |
| Total memory snapshot | **~477.8 MiB** |
| Total CPU snapshot | **~8.64%** |
| Health | All health-checked services healthy |

Top memory (idle): messaging ~41.7 MiB, postgres-core ~41.5 MiB, synapse ~40.4 MiB, language-intelligence ~39.0 MiB, auth ~37.1 MiB.

That run still used **three** Postgres containers. PR #304 consolidates to **one** Postgres with three logical databases, so prod should be slightly leaner.

**Implication:** An **8 GB** VPS has large idle headroom (~16× measured RSS). Soft `mem_limit` caps on the compose profile sum near ~8.5 GB (ceiling if everything spikes together). OS + Docker need ~0.5–1 GB on top. 8 GB fits the designed MVP; 16 GB is headroom, not a requirement to boot.

---

## Netcup VPS 1000 G12 — pick one SKU, not both

Same machine class: **4 vCore / 8 GB DDR5 ECC / 256 GB NVMe**.

| Option | Product | Setup | Price / mo | Contract | First charge (approx.) |
|--------|---------|-------|------------|----------|-------------------------|
| **A — try / cancel anytime** | `VPS 1000 G12 iv NUE hourly-based` (Nuremberg) | **€4.20** | **€11.56** | 0 months | **~€15.76** |
| B — year prepaid | `VPS 1000 G12 iv 12M` | €0.00 | €8.70 | ≥12 months | **~€104.40** (12 × €8.70) |

Do **not** add both to the cart (that becomes ~€20.26/mo for two boxes).

**Recommendation for first deploy:** Option **A** (hourly NUE). Prove the stack for one month; cancel if it does not work. Full year on hourly ≈ €4.20 + 12×€11.56 ≈ **€143** vs **€104** prepaid — ~€40 extra for no lock-in.

Product pages:

- Catalog: https://www.netcup.com/en/server/vps
- 12M (avoid for a one-month trial): https://www.netcup.com/en/server/vps/vps-1000-g12-iv-12m
- Hourly (DE): https://www.netcup.com/de/server/vps/vps-1000-g12-stundenbasiert

---

## Month-to-month alternatives (same ~4 vCPU / 8 GB class)

| Provider / plan | Specs (approx.) | ~Price / mo | Link |
|-----------------|-----------------|-------------|------|
| OVHcloud VPS-2 | 4 vCore / 8 GB / 75 GB NVMe | ~$8.50 | https://www.ovhcloud.com/en/vps/ — order: https://us.ovhcloud.com/vps/configurator/ |
| Hetzner CX33 | 4 vCPU / 8 GB / 80 GB | ~€6.50–8 (+ IPv4) | https://www.hetzner.com/cloud/cost-optimized/ — create: https://console.hetzner.com/ |
| Hetzner CPX32 | 4 vCPU / 8 GB / 160 GB | ~€14–16 | https://www.hetzner.com/cloud/regular-performance/ |
| Contabo ~8 GB | varies | often cheaper | https://contabo.com/en-us/vps/ — treat as **staging only** (reliability tradeoffs) |

Netcup’s **256 GB** disk is the outlier vs OVH/Hetzner CX (~75–80 GB). Fine for lean compose; tighter once images + Postgres + local backups grow.

If memory headroom matters more than ~€10/mo: Netcup **VPS 2000 G12** (16 GB) — https://www.netcup.com/en/server/vps/vps-2000-g12-iv-12m (prefer hourly if available).

---

## Still needed after the box exists

1. Domain + DNS (Let’s Encrypt needs a real hostname; `VITE_API_URL` / `CORS_ORIGINS` need one too).
2. Real secrets in `ops/k8s/secrets/.env` (uncommitted).
3. Off-box backup bucket (S3-compatible) + `BACKUP_OFFSITE_*` if nightly dumps must leave the VPS disk.
4. Runtime validation of PR #304 on the real VPS (compose so far verified in local/throwaway Docker).

TLS via certbot in-compose is $0 once DNS points at the box.

---

## Decision summary

| Question | Answer |
|----------|--------|
| Will 8 GB run the PR #304 stack? | **Yes** — idle ~478 MiB; designed for 8 GB. |
| Cheapest credible “try one month”? | Netcup **hourly NUE** (~€16 first charge) or OVHcloud **VPS-2** (~$8.50/mo). |
| Buy the 12M prepaid now? | Only if committing for a year; otherwise skip. |
| Same as CloudInfra doc “Metrics Confirm” tab? | **Yes** — same `20260812T021218Z` local-prod summary. |
