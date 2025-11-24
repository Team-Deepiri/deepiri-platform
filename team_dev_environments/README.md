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

## Quick Reference

### Setup Minikube (for Kubernetes/Skaffold builds)
```bash
# Check if Minikube is running
minikube status

# If not running, start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Configure Docker to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### Build
```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Or use your team's build script
cd team_dev_environments/<your-team>
./build.sh
```

### When you DO need to build / rebuild
Only build if:
1. **Dockerfile changes**
2. **package.json/requirements.txt changes** (dependencies)
3. **First time setup**

**Note:** With hot reload enabled, code changes don't require rebuilds - just restart the service!

### Run all services
```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop all services
```bash
docker compose -f docker-compose.dev.yml down
```

### Running only services you need for your team
```bash
docker compose -f docker-compose.<team_name>-team.yml up -d
# Examples:
docker compose -f docker-compose.ai-team.yml up -d
docker compose -f docker-compose.backend-team.yml up -d
docker compose -f docker-compose.frontend-team.yml up -d
```

### Stopping those services
```bash
docker compose -f docker-compose.<team_name>-team.yml down
```

### Logs (All services)
```bash
docker compose -f docker-compose.dev.yml logs -f
```

### Logs (Individual services)
```bash
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker compose -f docker-compose.dev.yml logs -f cyrex
docker compose -f docker-compose.dev.yml logs -f auth-service
# ... etc for all services
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

