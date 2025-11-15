# Log Inspection Guide - Deepiri

## Quick Reference

### View Logs for Individual Containers

#### 1. Using Docker Compose (Recommended)

**Backend API Logs:**
```bash
# For docker-compose.dev.yml (microservices architecture):
docker compose -f docker-compose.dev.yml logs api-gateway

# For docker-compose.yml (monolithic backend):
docker compose -f docker-compose.yml logs backend
```

**Python AI Service Logs:**
```bash
docker compose -f docker-compose.dev.yml logs pyagent
```

**Frontend Logs:**
```bash
docker compose -f docker-compose.dev.yml logs frontend-dev
```

**MongoDB Logs:**
```bash
docker compose -f docker-compose.dev.yml logs mongodb
```

**Redis Logs:**
```bash
docker compose -f docker-compose.dev.yml logs redis
```

**Mongo Express Logs:**
```bash
docker compose -f docker-compose.dev.yml logs mongo-express
```

#### 2. Using Docker Direct Commands

**By Container Name:**
```bash
# For docker-compose.dev.yml:
docker logs deepiri-api-gateway-dev
docker logs deepiri-pyagent-dev
docker logs deepiri-frontend-dev
docker logs deepiri-mongodb-dev
docker logs deepiri-redis-dev
docker logs deepiri-mongo-express-dev

# For docker-compose.yml:
docker logs deepiri-backend
docker logs deepiri-pyagent-dev
```

#### 3. Useful Options

**Follow logs in real-time (like `tail -f`):**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs -f api-gateway
docker logs -f deepiri-api-gateway-dev

# For docker-compose.yml:
docker compose -f docker-compose.yml logs -f backend
docker logs -f deepiri-backend
```

**View last N lines:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs --tail=100 api-gateway
docker logs --tail=100 deepiri-api-gateway-dev

# For docker-compose.yml:
docker compose -f docker-compose.yml logs --tail=100 backend
docker logs --tail=100 deepiri-backend
```

**View logs with timestamps:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs -t api-gateway
docker logs -t deepiri-api-gateway-dev

# For docker-compose.yml:
docker compose -f docker-compose.yml logs -t backend
docker logs -t deepiri-backend
```

**View logs since specific time:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs --since 10m api-gateway
docker logs --since 2024-11-04T20:00:00 deepiri-api-gateway-dev

# For docker-compose.yml:
docker compose -f docker-compose.yml logs --since 10m backend
docker logs --since 2024-11-04T20:00:00 deepiri-backend
```

**View logs until specific time:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs --until 2024-11-04T21:00:00 api-gateway

# For docker-compose.yml:
docker compose -f docker-compose.yml logs --until 2024-11-04T21:00:00 backend
```

**Combine options:**
```bash
# Follow last 50 lines with timestamps (docker-compose.dev.yml):
docker compose -f docker-compose.dev.yml logs -f --tail=50 -t api-gateway

# For docker-compose.yml:
docker compose -f docker-compose.yml logs -f --tail=50 -t backend
```

#### 4. View Multiple Services at Once

**View logs for multiple services:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs api-gateway pyagent
docker compose -f docker-compose.dev.yml logs api-gateway frontend-dev mongodb

# For docker-compose.yml:
docker compose -f docker-compose.yml logs backend pyagent
```

**View all services:**
```bash
docker compose -f docker-compose.dev.yml logs
```

#### 5. Filter Logs

**Search logs for specific text:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs api-gateway | grep "error"
docker logs deepiri-api-gateway-dev | grep -i "challenge"

# For docker-compose.yml:
docker compose -f docker-compose.yml logs backend | grep "error"
docker logs deepiri-backend | grep -i "challenge"
```

**Case-insensitive search:**
```bash
# For docker-compose.dev.yml:
docker logs deepiri-api-gateway-dev | grep -i "error"

# For docker-compose.yml:
docker logs deepiri-backend | grep -i "error"
```

**Search with context (show surrounding lines):**
```bash
# For docker-compose.dev.yml:
docker logs deepiri-api-gateway-dev | grep -A 5 -B 5 "error"

# For docker-compose.yml:
docker logs deepiri-backend | grep -A 5 -B 5 "error"
```

**Multiple search terms:**
```bash
# For docker-compose.dev.yml:
docker logs deepiri-api-gateway-dev | grep -E "error|warn|challenge"

# For docker-compose.yml:
docker logs deepiri-backend | grep -E "error|warn|challenge"
```

#### 6. Save Logs to File

**Save logs to file:**
```bash
# For docker-compose.dev.yml:
docker compose -f docker-compose.dev.yml logs api-gateway > api-gateway.log
docker logs deepiri-api-gateway-dev > api-gateway.log

# For docker-compose.yml:
docker compose -f docker-compose.yml logs backend > backend.log
docker logs deepiri-backend > backend.log
```

**Append to file:**
```bash
# For docker-compose.dev.yml:
docker logs deepiri-api-gateway-dev >> api-gateway.log

# For docker-compose.yml:
docker logs deepiri-backend >> backend.log
```

**Save with timestamps:**
```bash
# For docker-compose.dev.yml:
docker logs -t deepiri-api-gateway-dev > api-gateway-with-timestamps.log

# For docker-compose.yml:
docker logs -t deepiri-backend > backend-with-timestamps.log
```

#### 7. Inspect Container Logs Directly

**View log file location:**
```bash
# For docker-compose.dev.yml:
docker inspect deepiri-api-gateway-dev | grep LogPath

# For docker-compose.yml:
docker inspect deepiri-backend | grep LogPath
```

**View container stats (includes log info):**
```bash
# For docker-compose.dev.yml:
docker stats deepiri-api-gateway-dev

# For docker-compose.yml:
docker stats deepiri-backend
```

## Common Use Cases

### Debug Backend Errors
```bash
# View recent errors (docker-compose.dev.yml):
docker compose -f docker-compose.dev.yml logs --tail=100 api-gateway | grep -i error

# Follow logs in real-time to see errors as they happen
docker compose -f docker-compose.dev.yml logs -f api-gateway

# For docker-compose.yml:
docker compose -f docker-compose.yml logs --tail=100 backend | grep -i error
docker compose -f docker-compose.yml logs -f backend
```

### Monitor API Requests
```bash
# Watch backend logs for API calls (docker-compose.dev.yml):
docker compose -f docker-compose.dev.yml logs -f api-gateway | grep "GET\|POST\|PUT\|DELETE"

# For docker-compose.yml:
docker compose -f docker-compose.yml logs -f backend | grep "GET\|POST\|PUT\|DELETE"
```

### Check Challenge Generation
```bash
# Monitor Python AI service for challenge generation
docker compose -f docker-compose.dev.yml logs -f pyagent | grep -i challenge
```

### View Database Operations
```bash
# MongoDB logs
docker compose -f docker-compose.dev.yml logs -f mongodb

# Redis logs
docker compose -f docker-compose.dev.yml logs -f redis
```

### Monitor All Services
```bash
# View all logs together
docker compose -f docker-compose.dev.yml logs -f

# View specific services together (docker-compose.dev.yml):
docker compose -f docker-compose.dev.yml logs -f api-gateway pyagent frontend-dev

# For docker-compose.yml:
docker compose -f docker-compose.yml logs -f backend pyagent
```

### Check Container Health
```bash
# View health check logs (docker-compose.dev.yml):
docker inspect deepiri-api-gateway-dev | grep -A 10 Health

# For docker-compose.yml:
docker inspect deepiri-backend | grep -A 10 Health

# View container status
docker ps -a --filter "name=deepiri"
```

## Troubleshooting

### Container Not Starting
```bash
# Check why container exited (docker-compose.dev.yml):
docker logs deepiri-api-gateway-dev

# View last 100 lines
docker logs --tail=100 deepiri-api-gateway-dev

# For docker-compose.yml:
docker logs deepiri-backend
docker logs --tail=100 deepiri-backend
```

### High Memory Usage
```bash
# Monitor resource usage (docker-compose.dev.yml):
docker stats deepiri-api-gateway-dev

# Check logs for memory issues
docker logs deepiri-api-gateway-dev | grep -i memory

# For docker-compose.yml:
docker stats deepiri-backend
docker logs deepiri-backend | grep -i memory
```

### Connection Issues
```bash
# Check backend connection logs (docker-compose.dev.yml):
docker compose -f docker-compose.dev.yml logs api-gateway | grep -i "connect\|mongodb\|redis"

# Check all services for connection errors
docker compose -f docker-compose.dev.yml logs | grep -i "error\|failed\|timeout"

# For docker-compose.yml:
docker compose -f docker-compose.yml logs backend | grep -i "connect\|mongodb\|redis"
```

## Log File Locations

### Application Logs (Inside Containers)
- **API Gateway** (docker-compose.dev.yml): `/app/logs/` (mounted to `./services/api-gateway/logs/`)
- **Backend** (docker-compose.yml): `/app/logs/` (mounted to `./api-server/logs/`)
- **Python Service**: Logs to stdout/stderr (captured by Docker)

### Docker Logs
Docker stores logs in:
- **Linux**: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
- **Windows**: `C:\ProgramData\docker\containers\<container-id>\<container-id>-json.log`

### Access Log Files Directly
```bash
# View backend application logs (docker-compose.yml - if mounted)
cat ./api-server/logs/combined.log
cat ./api-server/logs/error.log

# View API Gateway logs (docker-compose.dev.yml - if mounted)
cat ./services/api-gateway/logs/combined.log
cat ./services/api-gateway/logs/error.log

# Follow backend logs
tail -f ./api-server/logs/combined.log
# Or for API Gateway:
tail -f ./services/api-gateway/logs/combined.log
```

## Best Practices

1. **Use Docker Compose logs** for service-specific logs (includes service name prefix)
2. **Use `-f` flag** to follow logs in real-time during development
3. **Use `--tail=N`** to limit output when logs are large
4. **Use `-t` flag** to see timestamps for debugging
5. **Save logs** when debugging production issues
6. **Filter logs** with grep to find specific errors or events

## Quick Commands Cheat Sheet

```bash
# All services (docker-compose.dev.yml)
docker compose -f docker-compose.dev.yml logs -f

# Single service (docker-compose.dev.yml - use api-gateway)
docker compose -f docker-compose.dev.yml logs -f api-gateway

# Last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100 api-gateway

# With timestamps
docker compose -f docker-compose.dev.yml logs -f -t api-gateway

# Search for errors
docker compose -f docker-compose.dev.yml logs api-gateway | grep -i error

# Multiple services
docker compose -f docker-compose.dev.yml logs -f api-gateway pyagent

# Save to file
docker compose -f docker-compose.dev.yml logs api-gateway > api-gateway.log

# For docker-compose.yml (monolithic backend):
docker compose -f docker-compose.yml logs -f backend
docker compose -f docker-compose.yml logs --tail=100 backend
docker compose -f docker-compose.yml logs backend | grep -i error
```

