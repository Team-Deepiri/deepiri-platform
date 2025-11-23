# How to Build Deepiri (Development)

**THE ONLY BUILD GUIDE YOU NEED**

## Quick Start

```bash
cd deepiri

# Linux/Mac/WSL - Build everything with auto-cleanup
./build.sh

# Windows PowerShell - Build everything with auto-cleanup
.\build.ps1
```

That's it. The scripts automatically clean up dangling images so you **never** get 50GB bloat.

---

## What the Build Script Does

1. Enables BuildKit (better caching, faster builds)
2. Builds all services via Docker Compose
3. **Automatically removes dangling `<none>` images**
4. Shows disk usage

No manual cleanup needed. Ever.

---

## Build Specific Services

```bash
# Build only one service (faster)
./build.sh cyrex              # Linux/Mac/WSL
.\build.ps1 cyrex             # Windows

# Force clean rebuild (no cache)
./build.sh --no-cache         # Linux/Mac/WSL
.\build.ps1 -NoCache          # Windows
```

---

## Run the Stack

```bash
# Start everything
docker compose -f docker-compose.dev.yml up -d

# Check status
docker compose -f docker-compose.dev.yml ps

# View logs
docker compose -f docker-compose.dev.yml logs -f

# View specific service logs
docker compose -f docker-compose.dev.yml logs -f cyrex
```

---

## Stop the Stack

```bash
# Stop all containers
docker compose -f docker-compose.dev.yml down

# Stop and remove volumes (clean slate)
docker compose -f docker-compose.dev.yml down -v
```

---

## Common Workflows

### Daily Development
```bash
# Make code changes...

# Rebuild changed services
./build.sh

# Restart containers
docker compose -f docker-compose.dev.yml restart
```

### Clean Rebuild
```bash
# Stop everything
docker compose -f docker-compose.dev.yml down

# Clean build
./build.sh --no-cache

# Start fresh
docker compose -f docker-compose.dev.yml up -d
```

### Check Disk Usage
```bash
docker system df
```

---

## Services You Can Build

All services now have build configurations:
- `api-gateway` - API Gateway
- `auth-service` - Authentication
- `task-orchestrator` - Task management
- `engagement-service` - Gamification
- `platform-analytics-service` - Analytics
- `notification-service` - Notifications
- `external-bridge-service` - External integrations
- `challenge-service` - Challenges
- `realtime-gateway` - WebSocket gateway
- `cyrex` - AI/ML service (Python)
- `jupyter` - Jupyter notebooks
- `frontend-dev` - React frontend

---

## Why No More 50GB Bloat?

1. **BuildKit enabled** - Better layer caching
2. **Auto-cleanup in build scripts** - Removes dangling images immediately
3. **Docker Compose build sections** - Proper layer reuse
4. **No Skaffold artifacts** - No intermediate tagged images

The old Skaffold workflow created 50GB of dangling `<none>` images every build. The new Docker Compose workflow with auto-cleanup prevents this completely.

---

## Troubleshooting

### "No space left on device"
Run the cleanup script:
```bash
./scripts/remove-dangling-images.sh       # Linux/Mac/WSL
.\scripts\remove-dangling-images.ps1      # Windows
```

### "Image not found"
Build first:
```bash
./build.sh
```

### Builds are slow
Use cache:
```bash
./build.sh              # Uses cache (fast)
# NOT: ./build.sh --no-cache (slow)
```

### Need to reclaim Windows disk space
Run as Administrator:
```powershell
.\scripts\cleanup-and-compact.ps1
```

This compacts the WSL2 virtual disk and returns space to Windows.

---

## Files Reference

- `build.sh` / `build.ps1` - Smart build scripts (use these)
- `docker-compose.dev.yml` - Development configuration
- `scripts/remove-dangling-images.*` - Manual cleanup if needed
- `scripts/cleanup-and-compact.ps1` - Full cleanup + WSL compact

---

## What About Skaffold?

**Don't use Skaffold for local development.** It was causing the 50GB bloat issue.

Skaffold docs moved to `docs/archive/skaffold/` for reference only.

Use the Docker Compose workflow documented here.

