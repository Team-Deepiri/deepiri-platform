# Environment Setup

## 1. Prerequisites

This doc is the **fast path**: one script installs prerequisites, pulls the right submodules for your team, then builds + starts the Docker dev environment.

**Windows**: Install WSL2 with a **Debian** distribution (required).

**Mac**:
- Install **Docker Desktop** (the script can install the app, but it cannot start it for you).
- Ensure **Docker Engine is running** before you re-run the script.

**Linux**: Use **Debian**.

**Required accounts / access**:
- GitHub access to `Team-Deepiri/deepiri-platform`
- GitHub SSH key configured (the script will help you generate one if needed)

**What the script installs (if missing)**:
- `git`, `curl`, `python3`, `pip3`, `node`, `npm`, `ssh`
- `docker` + `docker compose`
- Python `pyyaml` (needed by `team_dev_environments/*/run.py`)

> **Note on Python packages:** the script intentionally does **not** `pip install -r requirements.txt` for all services. Most services run in Docker, so dependencies are installed **during Docker image builds** after the required submodules are pulled.

## 2. Installation

Download `setup-deepiri-dev.sh` and save it somewhere on your system. Open a terminal, `cd` into that directory, and run:

```bash
bash setup-deepiri-dev.sh
```

Follow the prompts in the terminal. The script will:
- Ask which team you're on (AI / Backend / Frontend / Infrastructure / ML / Platform / QA)
- Install missing prerequisites
- Help you set up GitHub SSH access
- Clone `deepiri-platform` (or use your existing clone)
- Pull only the submodules your team needs
- Build + start your team dev environment
- Seed the Postgres core DB (if applicable)

## 3. Secrets / environment variables

This setup intentionally avoids `.env` sprawl by loading environment variables from Kubernetes-style config files.

- Put your provided `/secrets` folder into:
  - `deepiri-platform/ops/k8s/secrets`

If you need a reference for what variables exist / where they come from, see:
- `docs/getting-started/ENVIRONMENT_VARIABLES.md`

## Additional: Useful Commands

### Service control

In the `deepiri-platform` directory

- Start everything: `docker compose -f docker-compose.dev.yml up -d`
- Stop everything (remove containers): `docker compose -f docker-compose.dev.yml down`
- Stop everything: `./team_dev_environments/<your-team-folder>/stop.sh`
- Check Docker services/containers status: `docker ps`

### Logs

To check the logs for a Docker services/containers

```bash
docker compose -f docker-compose.dev.yml logs -f <service-name>
# or
docker logs <exact-container-name-from-docker-ps>
```

Examples: 
- `docker compose -f docker-compose.dev.yml logs -f api-gateway` or `docker logs deepiri-api-gateway` shows logs for deepiri-api-gateway
- `docker compose -f docker-compose.dev.yml logs -f cyrex api-gateway synapse` shows logs for cyrex, api-gateway, and synapse... 
- `docker compose -f docker-compose.dev.yml logs -f` shows all logs for all services running
- etc...