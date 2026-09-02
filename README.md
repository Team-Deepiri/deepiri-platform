# Deepiri Platform (cloud portal)

> **Cloud VPS** internal portal — auth, org, tools, Plaky. No Cyrex / LIS / AI runtime.  
> **Full local builder stack** → [Team-Deepiri/deepiri-control-plane](https://github.com/Team-Deepiri/deepiri-control-plane) (`docker-compose.dev.yml`, `setup-deepiri-dev.sh`, speech engine).

Deploy: `docker compose up -d` (see `docker-compose.yml`)  
Dev setup for Cyrex/LIS/speech: clone **deepiri-control-plane** and run `bash setup-deepiri-dev.sh`

> **NEW TO THE PROJECT?** [docs/getting-started/START_HERE.md](docs/getting-started/START_HERE.md)  
> **FIND YOUR TEAM:** [docs/getting-started/FIND_YOUR_TASKS.md](docs/getting-started/FIND_YOUR_TASKS.md)  
> **Architecture split:** [docs/architecture/REPO_SPLIT.md](docs/architecture/REPO_SPLIT.md)

## Quick Start (cloud portal)

```bash
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform
git checkout infra/cheap-one-box-compose-dev   # until merged to main

# Bootstrap secrets (see .env.example)
mkdir -p ops/k8s/secrets
cp .env.example ops/k8s/secrets/.env   # edit passwords before prod

docker compose -f docker-compose.yml up -d
```

## Full dev stack (Cyrex, LIS, speech engine)

Use **[deepiri-control-plane](https://github.com/Team-Deepiri/deepiri-control-plane)** — not this repo:

```bash
git clone git@github.com:Team-Deepiri/deepiri-control-plane.git
cd deepiri-control-plane
bash setup-deepiri-dev.sh
```

`setup-deepiri-dev.sh` in **this** repo only prints the redirect above.

## Common commands (cloud)

```bash
./build.sh                          # build cloud services
make up                             # docker compose -f docker-compose.yml up -d
make down
docker compose -f docker-compose.yml ps
```

### Access services (cloud portal)
- Frontend (via nginx): http://localhost (ports 80/443)
- API Gateway: internal (`api-gateway:5100` on compose network)
- Auth Service: internal (`auth-service:5001`)

## Cloud services (`docker-compose.yml`)

| Service | Role |
|---------|------|
| `postgres-platform` | Single Postgres (platform DB) |
| `redis` | Cache / sessions |
| `auth-service` | Authentication |
| `api-gateway` | API routing |
| `registry` | Service registry |
| `jobs` | Background jobs (+ pg backup) |
| `external-bridge-service` | External integrations (Plaky, etc.) |
| `platform-frontend` | Portal UI |
| `nginx` | Edge TLS / reverse proxy |
| `certbot` | TLS certificates |
| `pg-backup-offsite` | Optional offsite DB backup |

## Team dev environments

Team catalogs and `./setup-deepiri-dev.sh` live in **[deepiri-control-plane](https://github.com/Team-Deepiri/deepiri-control-plane)**.  
This repo keeps `teams/cloud-portal.yml` for VPS deploy and reference copies under `teams/` (see `teams/README.md`).

```bash
git clone git@github.com:Team-Deepiri/deepiri-control-plane.git
cd deepiri-control-plane
./setup-deepiri-dev.sh pull backend-team
./setup-deepiri-dev.sh build backend-team
./setup-deepiri-dev.sh start backend-team
```

## Submodule management (cloud build scope)

Cloud compose builds from `platform-services/` paths. Submodule init for CI/deploy is scoped in `.github/workflows/platform-build-and-test.yml`.  
Full team submodule lists → control-plane `teams/*.yml`.

## Documentation

- [Getting Started](docs/getting-started/START_HERE.md)
- [Find Your Tasks](docs/getting-started/FIND_YOUR_TASKS.md)
- [Service Communication](SERVICE_COMMUNICATION_AND_TEAMS.md)
- [Environment Variables](docs/getting-started/ENVIRONMENT_VARIABLES.md)
- [Building Services](HOW_TO_BUILD.md)

## Contributing

1. Clone the repository
2. Initialize submodules for your team
3. Create a feature branch
4. Make your changes
5. Build and test
6. Submit a pull request

## License

See [LICENSE.md](LICENSE.md)
