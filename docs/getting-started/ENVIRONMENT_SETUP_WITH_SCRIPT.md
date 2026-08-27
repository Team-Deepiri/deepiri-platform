# Environment setup (scripted)

> **Cloud portal repo:** This document applies to **deepiri-control-plane** for full local dev.  
> In **deepiri-platform** (cloud VPS), run `docker compose -f docker-compose.yml up -d` after configuring `ops/k8s/secrets/.env`.  
> `setup-deepiri-dev.sh` in the cloud repo redirects to control-plane.

This guide is the **fast path** for local development on **deepiri-control-plane**. A **single unified script** at the repo root does everything:

- **macOS / Debian Linux / Debian WSL2:** **[`setup-deepiri-dev.sh`](../../setup-deepiri-dev.sh)** (in **deepiri-control-plane**)
- **Windows (native PowerShell):** **[`setup-deepiri-dev.ps1`](../../setup-deepiri-dev.ps1)** (in **deepiri-control-plane**)

Either script detects your platform, installs missing tooling, configures GitHub SSH, clones (or reuses) **`deepiri-control-plane`**, initializes **only the submodules your team needs**, brings up **only the services your team + hardware tier needs** via `docker compose -f docker-compose.dev.yml`, and seeds Postgres when possible.

> **What changed.** There are no longer per‑team `team_dev_environments/<team>/build.sh` / `start.sh` or `team_submodule_commands/<team>/pull_submodules.sh` wrappers. That logic is now **built into the one script** and selected with **`--team`** and **`--tier`** flags (or interactive prompts). If a doc or script still tells you to `cd team_dev_environments/...`, it is stale — see [§9 Troubleshooting](#9-troubleshooting).

For a fuller stack walkthrough (Skaffold, minikube, etc.), see **[COMPLETE_SETUP.md](COMPLETE_SETUP.md)**.

---

## 1. Prerequisites by OS

### Windows

You have **two** supported paths:

- **Native PowerShell (recommended, no WSL required):** run **`setup-deepiri-dev.ps1`**. It auto‑installs prerequisites via **winget** (`git`, **Docker Desktop**, `python`, `node`), sets up an SSH key, and runs the same team/tier/submodule/docker orchestration. Docker Desktop provides the engine.
- **Debian on WSL2:** if you prefer a Linux shell, install **WSL2 with a Debian** distribution and run **`setup-deepiri-dev.sh`** from inside it. The bash script **exits on non‑Debian** Linux/WSL — it expects Debian's `apt` toolchain (install with `wsl --install -d Debian` from PowerShell, then open the **Debian** shell).

Either way you need a **GitHub account** with access to **`Team-Deepiri/deepiri-platform`**; both scripts help set up SSH.

### macOS

1. Run **`setup-deepiri-dev.sh`**. It installs **missing** CLI tools via **Homebrew** (running the official Homebrew installer if Homebrew is absent).
2. **Docker Desktop for Mac** is the usual path: the script may install the app, but **you must open Docker Desktop** and wait until **"Engine running"** (the script checks whether `docker info` works).
3. **GitHub SSH** configured for cloning `git@github.com:Team-Deepiri/deepiri-platform.git` (the script can generate a key and walk you through adding it).

> **Apple Silicon / MPS note (AI team):** on Mac the script **excludes `cyrex` and `ollama` from Docker** because they run **natively** against MPS instead. On Linux/WSL with a GPU those run in containers.

### Linux (bare metal)

- Use **Debian** (matching the WSL requirement) and run **`setup-deepiri-dev.sh`**. It installs `git`, `curl`, **`docker` + Compose plugin**, `python3`, `pip3`, `node`, `npm`, and OpenSSH clients where missing via `apt` (Docker Engine + Compose plugin from the official docker.com apt repo).
- Start the daemon if needed (e.g. `sudo systemctl start docker` or `sudo service docker start`) until `docker ps` works.

---

## 2. Docker in this repo (what you're running)

Deepiri runs **mostly in containers** orchestrated by **Docker Compose**, using **`docker-compose.dev.yml`** at the **`deepiri-control-plane`** repo root (not this cloud portal repo).

- **Docker Engine** builds and runs **images** defined in service Dockerfiles; your code often **bind-mounts** into containers for hot reload, so host-side `pip install` / `npm install` are **not** the primary dependency path — that happens **inside images** during **`docker compose build`**.
- **Compose** reads **`docker-compose.dev.yml`**, wires **networks and ports**, and starts named **services** (e.g. `api-gateway`, `cyrex`).
- **The setup script does not build images by default.** It runs `docker compose up -d --no-build` (fast startup against existing images). Pass **`--build`** (bash) / **`-Build`** (PowerShell) the first time, or when Dockerfiles change, to build images as part of startup. You can also build directly with `docker compose -f docker-compose.dev.yml build`.
- **`docker compose` vs legacy `docker-compose`:** prefer **`docker compose`** (v2 plugin). The setup script ensures the Compose plugin where it can.

> **Service names must match `docker-compose.dev.yml`.** There is **no single `postgres` service** — the Postgres services are **`postgres-core`, `postgres-auth`, `postgres-intelligence`, `postgres-cyrex`**. The old **`challenge-service`** no longer exists. The setup script's built‑in per‑team service lists are kept in sync with the compose file; if you ever hit a **"no such service"** error, confirm the real list per [§9 Troubleshooting](#9-troubleshooting).

If **`docker info`** fails, fix the daemon first (Docker Desktop UI on Mac/Windows, WSL integration or `service docker` on Linux/WSL) before blaming application code.

---

## 3. What the setup script installs and does

The script runs these steps in order:

| Step | Behavior |
|------|----------|
| Platform detection | Detects **macOS / Debian Linux / Debian WSL2** (bash) or Windows (PowerShell); refuses non‑Debian Linux/WSL |
| Team selection | Prompt or `--team`: **AI / Backend / Frontend / Infrastructure / ML / Platform / QA / Cyrex** — decides which submodules and services are in scope |
| Hardware + tier | Detects RAM/GPU, suggests a **tier** (see [§5](#tiers-t1--t2--t3)); prompt or `--tier` picks **T1 / T2 / T3** |
| Prerequisites | Installs missing: `git`, `curl`, `python3`, `pip3`, `node`, `npm`, `ssh`, **Docker**, **Compose plugin**; ensures **`pyyaml`** |
| GitHub SSH | Helps generate `~/.ssh/id_ed25519`, shows the public key to add at [GitHub SSH settings](https://github.com/settings/ssh/new), optional connectivity test |
| Clone | Prompts for parent folder (default `$HOME`), clones to **`$PARENT/Deepiri/deepiri-platform`** — or **reuses the existing clone** if you run the script from inside one |
| Submodules | **Team‑scoped** init, built in (replaces `team_submodule_commands/`). See the [submodule policy](#submodule-policy) |
| Services | **Team + tier‑scoped** `docker compose up -d` (replaces `team_dev_environments/`); `--no-build` unless you pass `--build` |
| DB seed | Applies **`scripts/database/postgres-seed.sql`** against **`deepiri-postgres-core-dev`** when that container is up |

**Why you don't see `pip install -r requirements.txt` for every service:** services install dependencies **when their Docker images build** after submodules are present — not from a single global host venv.

---

## 4. Installation (run the script)

### macOS / Debian Linux / Debian WSL2

From the repo root (or anywhere, if you don't have a clone yet):

```bash
bash setup-deepiri-dev.sh
```

Answer the prompts: **team**, **hardware tier**, **SSH**, and **checkout location**. The first run with `--build` can take a long time while images build.

**Flags** (all optional — omit any to be prompted):

| Flag | Effect |
|------|--------|
| `--team <team>` | `ai`, `backend`, `frontend`, `infrastructure`, `ml`, `platform`, `qa`, `cyrex` |
| `--tier <1\|2\|3>` | Force a hardware tier instead of the auto‑suggestion |
| `--build` | Build images during startup (otherwise `--no-build`) |
| `--update-submodules` | Force‑bump **every** submodule to its latest branch tip |
| `--skip-submodules` | Don't touch submodules |
| `--skip-docker` | Don't start any services |
| `--non-interactive` | Never prompt; use supplied flags/defaults, skip package installs |

Example — non‑interactive backend bring‑up with a fresh build:

```bash
bash setup-deepiri-dev.sh --team backend --tier 2 --build --non-interactive
```

### Windows (PowerShell)

```powershell
.\setup-deepiri-dev.ps1
```

Same flags in PowerShell form: `-Team <team>`, `-Tier <1|2|3>`, `-Build`, `-UpdateSubmodules`, `-SkipSubmodules`, `-SkipDocker`, `-NonInteractive`.

```powershell
.\setup-deepiri-dev.ps1 -Team frontend -Tier 2 -Build
```

---

## 5. Teams, tiers, and submodules

### Team → scope

When the script asks for your team (or you pass `--team`), it selects **only the submodules and services that team needs**. There are **no per‑team folders** to `cd` into anymore.

| Team (`--team`) | Roughly what it brings up |
|-----------------|---------------------------|
| `ai` | Cyrex + modelkit + ollama‑utils + api‑gateway + shared libs; Cyrex/Ollama run natively on Mac |
| `backend` | Full backend services + shared libs |
| `frontend` | Frontend dev server + api‑gateway + auth + shared libs |
| `infrastructure` | Full backend services + shared libs |
| `ml` | Helox + modelkit + ollama‑utils + shared libs (Synapse/Sugar Glider services) |
| `platform` | **All** submodules and **all** services |
| `qa` | Staged startup across infra + backend + frontend |
| `cyrex` | Cyrex + modelkit + shared libs; core Cyrex service set |

> The exact submodule and service lists live in `setup-deepiri-dev.sh` (functions `pull_submodules` and `start_services`) and are the source of truth.

### Tiers (T1 / T2 / T3)

The tier controls **how many services start**, based on your hardware. The script suggests one from detected RAM/GPU; you can override with `--tier`.

| Tier | Hardware | What runs |
|------|----------|-----------|
| **T1** | GPU **and** 16GB+ RAM | Full stack (best for local LLM / Ollama) |
| **T2** | No GPU, 16GB+ RAM | Full stack |
| **T3** | < 16GB RAM | **Core only** — `postgres-auth`, `postgres-core`, `redis`, `api-gateway`, `auth-service` |

Tier 3 is a hard override for **all** teams: only the core services start regardless of team.

### Submodule policy

The script never silently moves someone's submodule pointers:

- **Fresh / uninitialized** submodule → initialized **and** bumped to the latest branch tip.
- **Already initialized** submodule → **left exactly as‑is**.
- **`--update-submodules`** → force‑bump **every** submodule to the latest tip.

### Refresh submodules manually

If you cloned without submodules, or want Git to recurse everything pinned by the repo:

```bash
git submodule update --init --recursive
```

Or re-run the setup script with `--update-submodules --skip-docker` to just refresh your team's submodules.

### Verify submodules actually populated

Pulling can appear to succeed while leaving submodules **empty** (missing SSH access, a partial clone, or a skipped `--init`). Docker builds then fail with confusing "file not found" errors on submodule paths. Before building, confirm the working tree is actually populated:

```bash
git submodule status --recursive
```

Read the prefix on each line:

- Leading **`-`** → submodule is **not initialized** (empty). Re-run the setup script, or `git submodule update --init --recursive`.
- Leading **`+`** → checked-out commit differs from the commit the superproject pins (usually fine during active work).
- **No prefix** (leading space) → initialized and at the pinned commit.

Do **not** start a Docker build until every required submodule is initialized.

---

## 6. Secrets and environment variables

Sensitive and non‑sensitive config for Compose-style runs is modeled after Kubernetes files under **`ops/k8s/`**.

> **Do this _before_ you bring services up.** The **`/secrets`** payload is **not committed to the repo** — **request it from your team lead first**, then place it into **`deepiri-platform/ops/k8s/secrets/`**. Starting the stack before the secrets are in place leaves services **failing health checks** or exiting on startup.

Steps:

1. **Ask your team lead** for the current `/secrets` payload — do this **before** running the setup script (or before `--build` / bringing services up).
2. Drop the provided **`/secrets`** payload into **`deepiri-platform/ops/k8s/secrets/`** (as your team distributes it).
3. For variable names and file layout, see **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)**.

Until required secrets/config exist, some services may **fail health checks** or exit — check **`docker compose` logs** (below).

---

## 7. Additional useful commands

Run these from **`deepiri-platform`** unless noted.

### Service control (Compose)

- **Start stack in background:** `docker compose -f docker-compose.dev.yml up -d`
- **Stop and remove containers (keep volumes unless you use `-v`):** `docker compose -f docker-compose.dev.yml down`
- **Compose service status:** `docker compose -f docker-compose.dev.yml ps`
- **Build images:** `docker compose -f docker-compose.dev.yml build`
- **Rebuild one service (no cache example):** `docker compose -f docker-compose.dev.yml build --no-cache <service-name>`
- **Restart one service:** `docker compose -f docker-compose.dev.yml restart <service-name>`
- **Shell inside a service:** `docker compose -f docker-compose.dev.yml exec <service-name> sh`

### Re-run the setup script

- **Refresh just your team's submodules:** `bash setup-deepiri-dev.sh --team <team> --update-submodules --skip-docker`
- **Rebuild + restart your team's services:** `bash setup-deepiri-dev.sh --team <team> --tier <n> --build --skip-submodules`

### Docker inspection

- **Running containers:** `docker ps`
- **Resource usage:** `docker stats`

### Logs

```bash
docker compose -f docker-compose.dev.yml logs -f <service-name>
docker logs <exact-container-name-from-docker-ps>
```

Examples:

```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex api-gateway synapse
docker compose -f docker-compose.dev.yml logs -f
```

### Postgres seed (if you skipped automation or DB started late)

Same idea as the setup script (adjust user/database if yours differ):

```bash
docker exec -i deepiri-postgres-core-dev psql -U deepiri -d deepiri < scripts/database/postgres-seed.sql
```

### Destructive cleanup (wipes named volumes Compose created — **data loss**)

```bash
docker compose -f docker-compose.dev.yml down -v
```

---

## 8. Endpoints

After a successful full‑stack start, the script prints the local endpoints:

| Service | URL |
|---------|-----|
| API Gateway | http://localhost:5100 |
| Cyrex | http://localhost:8000 |
| Cyrex Interface | http://localhost:5175 |
| MLflow | http://localhost:5500 |
| Frontend | http://localhost:5173 |
| Synapse | http://localhost:8002 |
| Ollama (AI team, non‑Mac, non‑T3) | http://localhost:11434 |

---

## 9. Troubleshooting

### "port is already allocated"

A container from **another project** (or a previous run) is already bound to the host port Compose wants. Find the offender by port number:

```bash
docker ps -a | grep <port>          # e.g. docker ps -a | grep 5432
```

Then stop/remove the conflicting container (or change the host port mapping):

```bash
docker stop <container> && docker rm <container>
```

Common collisions: Postgres **5432**, Redis **6379**, and gateways on **8080 / 3000** shared with unrelated local stacks.

### "no such service" / unknown service during build or start

If **any** script references a service name that **isn't defined** in `docker-compose.dev.yml`, that's a **repo bug in the script**, not a problem with your machine. Known stale names are **`postgres`** and **`challenge-service`** — the real Postgres services are **`postgres-core` / `postgres-auth` / `postgres-intelligence` / `postgres-cyrex`**, and **`challenge-service` is gone**.

Confirm the authoritative service list straight from the compose file:

```bash
docker compose -f docker-compose.dev.yml config --services
```

If a script's service names don't all appear in that output, **fix the script (or report it)** rather than debugging your local environment.

### Stale references to `team_dev_environments/` or `team_submodule_commands/`

Those per‑team folders and their `build.sh` / `start.sh` / `stop.sh` / `run.py` / `pull_submodules.sh` wrappers have been **replaced** by the unified `setup-deepiri-dev.sh` (+ `.ps1`) with `--team` / `--tier` flags. If a doc, README, or script still points you there, it is **out of date** — use the setup script instead and report the stale reference.

### Build-time failures are usually repo bugs, not local issues

A failure **during `docker compose build`** (missing file, unknown service, bad build arg) generally means the repo/script is out of sync — not that your machine is broken. Before assuming your setup is at fault, check, in order:

1. Submodules are populated — [§5 Verify submodules actually populated](#verify-submodules-actually-populated).
2. Secrets are in place — [§6 Secrets and environment variables](#6-secrets-and-environment-variables).
3. Service names match the compose file — [previous section](#no-such-service--unknown-service-during-build-or-start).

If all three hold and it still fails to build, treat it as a **repo/script bug** and raise it with the team rather than reinstalling local tooling.
