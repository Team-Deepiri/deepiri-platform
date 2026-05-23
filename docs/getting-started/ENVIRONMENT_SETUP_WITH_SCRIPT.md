# Environment setup (scripted)

This guide is the **fast path** for local development: **[`setup-deepiri-dev.sh`](../../setup-deepiri-dev.sh)** at the repo root installs missing tooling, configures GitHub SSH if needed, optionally clones **`deepiri-platform`**, pulls the **submodules your team needs**, then runs your team’s **Docker build/start** scripts and seeds Postgres when possible.

For a fuller stack walkthrough (Skaffold, minikube, etc.), see **[COMPLETE_SETUP.md](COMPLETE_SETUP.md)**.

---

## 1. Prerequisites by OS

### Windows

1. Install **WSL2** with a **Debian** distribution. The setup script **exits on non‑Debian** Linux/WSL—it expects Debian’s `apt` toolchain.
   - Example (PowerShell, as appropriate for your setup): install Debian via WSL, then open a **Debian** shell (not Ubuntu unless you migrate—use Debian as documented in the script).
2. Install **Docker** in a form the script can use:
   - **Option A:** **Docker Desktop for Windows** with **WSL2 integration** enabled for your Debian distro, **or**
   - **Option B:** **Docker Engine** inside Debian/WSL (the script can install packages on Debian; you may still need Desktop running on Windows depending on how you integrate).
3. You need a **GitHub account** with access to **`Team-Deepiri/deepiri-platform`** and SSH access (the script prompts for key setup).

**Run the setup script only from inside your Debian/WSL terminal**, not from classic Windows CMD unless your workflow explicitly supports it.

### macOS

1. The script installs **missing** CLI tools via **Homebrew** if Homebrew is absent (it runs the official Homebrew installer).
2. **Docker Desktop for Mac** is the usual path: the script may install the app, but **you must open Docker Desktop** and wait until **“Engine running”** (the script checks whether `docker info` works).
3. **GitHub SSH** configured for cloning `git@github.com:Team-Deepiri/deepiri-platform.git`.

### Linux (bare metal)

- Use **Debian** (matching the script’s WSL/Linux requirement). The script installs `git`, `curl`, **`docker` + Compose plugin**, `python3`, `pip3`, `node`, `npm`, and OpenSSH clients where missing via `apt`.
- Start the daemon if needed (e.g. `sudo systemctl start docker` or equivalent) until `docker ps` works.

---

## 2. Docker in this repo (what you’re running)

Deepiri runs **mostly in containers** orchestrated by **Docker Compose**, using manifests like **`docker-compose.dev.yml`** at the **`deepiri-platform`** repo root.

- **Docker Engine** builds and runs **images** defined in service Dockerfiles; your code often **bind-mounts** into containers for hot reload, so host-side `pip install` / `npm install` are **not** the primary dependency path—that happens **inside images** during **`docker compose build`** (via your team’s **`team_dev_environments/<team>/build.sh`**).
- **Compose** reads **`docker-compose.dev.yml`**, wires **networks and ports**, and starts named **services** (e.g. `api-gateway`, `cyrex`).
- **`docker compose` vs legacy `docker-compose`:** Prefer **`docker compose`** (v2 plugin). The setup script ensures the Compose plugin where it can.

If **`docker info`** fails, fix the daemon first (Docker Desktop UI on Mac, WSL integration or `service docker` on Linux/WSL) before blaming application code.

---

## 3. What the setup script installs and does

| Step | Behavior |
|------|----------|
| Team choice | Prompt: AI / Backend / Frontend / Infrastructure / ML / Platform / QA → maps to `team_dev_environments/<folder>/` |
| Prerequisites | Installs missing: `git`, `curl`, `python3`, `pip3`, `node`, `npm`, `ssh`, **Docker**, **Compose**; ensures **`pyyaml`** for `team_dev_environments/*/run.py` (only this Python dependency is intentional on the host) |
| GitHub SSH | Helps generate `~/.ssh/id_ed25519`, shows public key to add at [GitHub SSH settings](https://github.com/settings/ssh/new), optional connectivity test |
| Clone | Prompts for parent folder (default `$HOME`), clones to **`$PARENT/Deepiri/deepiri-platform`**—or reuses existing clone if you run the script from inside `deepiri-platform` |
| Submodules | Runs **`team_submodule_commands/<team>/pull_submodules.sh`** |
| Containers | Runs **`team_dev_environments/<team>/build.sh`** then **`start.sh`** |
| DB seed | Applies **`scripts/database/postgres-seed.sql`** against **`deepiri-postgres-core-dev`** when that container is up |

**Why you don’t see `pip install -r requirements.txt` for every service:** services install dependencies **when their Docker images build** after submodules are present—not from a single global host venv in this workflow.

---

## 4. Installation (run the script)

1. Obtain **`setup-deepiri-dev.sh`** (repo root or as distributed by the team).

2. In a terminal (Debian WSL / macOS Terminal / Debian Linux):

```bash
bash setup-deepiri-dev.sh
```

3. Follow prompts: choose **team**, confirm **SSH**, choose **checkout location**, wait for submodule pull and Docker build/start (first build can take a long time).

---

## 5. Teams, folders, and submodules

### Team ↔ directory mapping

When the script asks for your team, it uses this mapping:

| You select | Submodule commands folder | Dev environment folder |
|------------|-----------------------------|-------------------------|
| AI | `team_submodule_commands/ai-team` | `team_dev_environments/ai-team` |
| Backend | `team_submodule_commands/backend-team` | `team_dev_environments/backend-team` |
| Frontend | `team_submodule_commands/frontend-team` | `team_dev_environments/frontend-team` |
| Infrastructure | `team_submodule_commands/infrastructure-team` | `team_dev_environments/infrastructure-team` |
| ML | `team_submodule_commands/ml-team` | `team_dev_environments/ml-team` |
| Platform | `team_submodule_commands/platform-engineers` | `team_dev_environments/platform-engineers` |
| QA | `team_submodule_commands/qa-team` | `team_dev_environments/qa-team` |

Your team script pulls **only what that team needs**; see **`team_submodule_commands/README.md`** for which submodule paths apply to each team.

### Pull submodules manually (same as script, or refresh after `git pull`)

From **`deepiri-platform`** repo root:

```bash
cd team_submodule_commands/<your-team-folder>
chmod +x pull_submodules.sh
./pull_submodules.sh
```

Examples:

```bash
./team_submodule_commands/backend-team/pull_submodules.sh
./team_submodule_commands/frontend-team/pull_submodules.sh
```

### “Pull everything” / all submodules

Use either team script that initializes **the full submodule set**:

- **`team_submodule_commands/platform-engineers/pull_submodules.sh`**
- **`team_submodule_commands/qa-team/pull_submodules.sh`**

Or, if you cloned without submodules and want Git to recurse everything pinned by the repo:

```bash
git submodule update --init --recursive
```

Platform still recommends your team-specific script where possible so expectation matches onboarding docs.

After pulling submodules, build/start again from your team folder if Dockerfiles depend on submodule paths:

```bash
cd team_dev_environments/<your-team-folder>
./build.sh
./start.sh
```

---

## 6. Secrets and environment variables

Sensitive and non‑sensitive config for Compose-style runs is modeled after Kubernetes files under **`ops/k8s/`**:

- Drop the provided **`/secrets`** payload into **`deepiri-platform/ops/k8s/secrets`** (as your team distributes it).
- For variable names and file layout, see **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)**.

Until required secrets/config exist, some services may **fail health checks** or exit—check **`docker compose` logs** (below).

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

### Team scripts (alternate stop path)

- **Stop (team wrapper):** `./team_dev_environments/<your-team-folder>/stop.sh`

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

Same idea as **`setup-deepiri-dev.sh`** (adjust user/database if yours differ):

```bash
docker exec -i deepiri-postgres-core-dev psql -U deepiri -d deepiri < scripts/database/postgres-seed.sql
```

### Destructive cleanup (wipes named volumes Compose created—**data loss**)

```bash
docker compose -f docker-compose.dev.yml down -v
```

---

## 8. Optional: team runner without relying on the outer script later

Some teams prefer **`python run.py`** inside **`team_dev_environments/<team>/`** (loads K8s-style configmaps/secrets). Requires **`pyyaml`** on the host—already covered by **`setup-deepiri-dev.sh`**. Details: **`team_dev_environments/README.md`** and **[COMPLETE_SETUP.md](COMPLETE_SETUP.md)**.
