# Building Deepiri - No More 50GB Bloat

## The Problem (FIXED)
- Every rebuild created 50GB+ of dangling images
- Had to manually run cleanup scripts
- Not how normal Docker development works

## The Solution

### Normal Docker Compose Workflow (RECOMMENDED)

**Use the smart build scripts - they automatically clean up dangling images:**

```bash
cd deepiri

# Linux/Mac/WSL
./build.sh              # Build everything
./build.sh cyrex        # Build specific service
./build.sh --no-cache   # Clean rebuild

# Windows PowerShell
.\build.ps1              # Build everything
.\build.ps1 cyrex        # Build specific service
.\build.ps1 -NoCache     # Clean rebuild
```

**Or use docker compose directly:**
```bash
# Enable BuildKit first (prevents dangling images)
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Build
docker compose -f docker-compose.dev.yml build

# Build and start
docker compose -f docker-compose.dev.yml up --build -d

# Build specific service
docker compose -f docker-compose.dev.yml build cyrex
```

### NO Manual Cleanup Needed
The build scripts (`build.sh` and `build.ps1`) **automatically** remove dangling images after every build.

No more manual cleanup. No more 50GB bloat.

### Why This Works

1. **Build sections in docker-compose.dev.yml**: Docker knows how to build each service
2. **Docker layer caching**: Only rebuilds changed layers, not everything
3. **Auto-cleanup script**: Removes dangling `<none>` images after builds
4. **No more 50GB bloat**: Dangling images removed immediately

### Quick Commands

```bash
# Build all services
docker compose -f docker-compose.dev.yml build

# Build only what changed (fast)
docker compose -f docker-compose.dev.yml up --build -d

# Build specific service
docker compose -f docker-compose.dev.yml build <service-name>

# Clean up dangling images
./scripts/remove-dangling-images.sh

# Full cleanup (Docker + compact WSL)
./scripts/cleanup-and-compact.ps1  # Run as Admin in PowerShell
```

### Services You Can Build

All services now have build configurations:
- `api-gateway`
- `auth-service`
- `task-orchestrator`
- `engagement-service`
- `platform-analytics-service`
- `notification-service`
- `external-bridge-service`
- `challenge-service`
- `realtime-gateway`
- `cyrex` (AI service)
- `jupyter` (notebooks)
- `frontend-dev`

### Tips

1. **Use `--build` flag**: `docker compose up --build` rebuilds only changed services
2. **Layer caching is your friend**: Don't use `--no-cache` unless necessary
3. **Clean up regularly**: Run `./scripts/remove-dangling-images.sh` weekly
4. **Compact WSL monthly**: Run `cleanup-and-compact.ps1` as Admin to reclaim Windows storage

### No More Manual Scripts

You don't need:
- ❌ Skaffold for local development
- ❌ Minikube for Docker Compose
- ❌ Manual build scripts
- ❌ 50GB of dangling images

Just use normal Docker Compose commands like every other developer.

