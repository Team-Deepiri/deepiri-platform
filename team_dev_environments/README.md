# Team Development Environments

This directory contains team-specific build and start scripts for each development team.

## Directory Structure

Each team has its own folder with:
- `build.sh` - Builds the services that team needs
- `start.sh` - Starts all required services
- `README.md` - Team-specific documentation

## Teams

- **ai-team/** - AI Team (cyrex, jupyter, mlflow, challenge-service)
- **ml-team/** - ML Team (cyrex, jupyter, mlflow, platform-analytics-service)
- **backend-team/** - Backend Team (all backend microservices)
- **frontend-team/** - Frontend Team (frontend + all backend services)
- **infrastructure-team/** - Infrastructure Team (all infrastructure + all microservices)
- **platform-engineers/** - Platform Engineers (everything)
- **qa-team/** - QA Team (everything)

## Quick Start

1. Navigate to your team's directory:
   ```bash
   cd team_dev_environments/backend-team
   ```

2. Build your services:
   ```bash
   ./build.sh
   ```

3. Start your services:
   ```bash
   ./start.sh
   ```

## How It Works

All scripts use the main `docker-compose.dev.yml` file. They:
- **Build scripts**: Use `docker compose -f docker-compose.dev.yml build <services>`
- **Start scripts**: Use `docker compose -f docker-compose.dev.yml up -d <services>`

This means:
- ✅ Single source of truth (`docker-compose.dev.yml`)
- ✅ No duplicate configuration
- ✅ Easy to maintain
- ✅ Each team only builds/starts what they need

## Stopping Services

To stop services, go back to the repo root and use docker compose:

```bash
cd ../..
docker compose -f docker-compose.dev.yml stop <service-name>
# or stop all
docker compose -f docker-compose.dev.yml down
```

## Rebuilding After Code Changes

Just run the build and start scripts again:

```bash
./build.sh
./start.sh
```

