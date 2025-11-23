# Quick Reference

## Build and Run

### Build (with auto-cleanup of dangling images)

```bash
# Build all services
./build.sh

# Build specific service
./build.sh jupyter

# Build without cache (slower, forces rebuild)
./build.sh --no-cache
```

**Windows PowerShell:**
```powershell
.\build.ps1
.\build.ps1 jupyter
.\build.ps1 -NoCache
```

### Run

```bash
docker compose -f docker-compose.dev.yml up -d
```

### Stop

```bash
docker compose -f docker-compose.dev.yml down
```

## Logs

### View Logs

```bash
# All services (last 50 lines each)
docker compose -f docker-compose.dev.yml logs --tail=50

# Specific service (last 50 lines)
docker compose -f docker-compose.dev.yml logs --tail=50 <service-name>

# Follow logs (live stream)
docker compose -f docker-compose.dev.yml logs -f --tail=50 <service-name>

# All available logs for a service (limited to 1MB)
docker compose -f docker-compose.dev.yml logs <service-name>
```

### Clear Logs

```bash
# PowerShell (Windows)
.\scripts\clear-docker-logs.ps1

# Bash (Linux/Mac/WSL)
./scripts/clear-docker-logs.sh

# Or restart services
docker compose -f docker-compose.dev.yml restart
```

**Note:** Logs are automatically limited to 1MB per service and cleared on restart.

## Service Names

Use these names with `docker compose logs`:
- `api-gateway` - API Gateway (port 5000)
- `auth-service` - Authentication service (port 5001)
- `task-orchestrator` - Task management (port 5002)
- `engagement-service` - Gamification (port 5003)
- `platform-analytics-service` - Analytics (port 5004)
- `notification-service` - Notifications (port 5005)
- `external-bridge-service` - External integrations (port 5006)
- `challenge-service` - Challenges (port 5007)
- `realtime-gateway` - WebSocket/real-time (port 5008)
- `cyrex` - AI/ML service (port 8000)
- `frontend-dev` - Frontend (port 5173)
- `mongodb` - MongoDB (port 27017)
- `redis` - Redis (port 6380)
- `influxdb` - InfluxDB (port 8086)
- `mlflow` - MLflow (port 5000)
- `jupyter` - Jupyter (port 8888)

## Common Tasks

### Rebuild a Single Service

```bash
./build.sh <service-name>
docker compose -f docker-compose.dev.yml up -d <service-name>
```

### Restart a Service

```bash
docker compose -f docker-compose.dev.yml restart <service-name>
```

### View Service Status

```bash
docker compose -f docker-compose.dev.yml ps
```

### Execute Command in Container

```bash
docker compose -f docker-compose.dev.yml exec <service-name> sh
```

### Remove All Containers and Volumes

```bash
docker compose -f docker-compose.dev.yml down -v
```

## Disk Space Management

### Clear Docker Images

```bash
# PowerShell (Windows)
.\scripts\remove-dangling-images.ps1

# Bash (Linux/Mac/WSL)
./scripts/remove-dangling-images.sh
```

### Reclaim WSL2 Disk Space (Windows)

```bash
# PowerShell (run as Administrator)
.\scripts\GET_SPACE_BACK.ps1
```

See `GET_SPACE_BACK.md` for details.

## Documentation

- `docs/HOW_TO_BUILD.md` - Complete build guide
- `docs/SERVICES_OVERVIEW.md` - Service architecture and access
- `docs/DOCKER_LOG_MANAGEMENT.md` - Log management details
- `GET_SPACE_BACK.md` - Disk space recovery (WSL2)
- `AUTO_COMPACT_OPTIONS.md` - Automatic disk space management
- `DOCUMENTATION_INDEX.md` - All documentation

## Ports

| Service | Port |
|---------|------|
| Frontend | 5173 |
| API Gateway | 5000 |
| Auth Service | 5001 |
| Task Orchestrator | 5002 |
| Engagement Service | 5003 |
| Platform Analytics | 5004 |
| Notification Service | 5005 |
| External Bridge | 5006 |
| Challenge Service | 5007 |
| Realtime Gateway | 5008 |
| Cyrex (AI) | 8000 |
| MongoDB | 27017 |
| Redis | 6380 |
| InfluxDB | 8086 |
| MLflow | 5000 |
| Jupyter | 8888 |
| Mongo Express | 8081 |

---

**Last Updated:** 2025-11-22
