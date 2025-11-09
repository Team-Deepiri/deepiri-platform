# Log Inspection Guide - Deepiri

## Quick Reference

### View Logs for Individual Containers

#### 1. Using Docker Compose (Recommended)

**Backend API Logs:**
```bash
docker compose -f docker-compose.dev.yml logs backend
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
docker logs deepiri-backend-dev
docker logs deepiri-pyagent-dev
docker logs deepiri-frontend-dev
docker logs deepiri-mongodb-dev
docker logs deepiri-redis-dev
docker logs deepiri-mongo-express-dev
```

#### 3. Useful Options

**Follow logs in real-time (like `tail -f`):**
```bash
docker compose -f docker-compose.dev.yml logs -f backend
docker logs -f deepiri-backend-dev
```

**View last N lines:**
```bash
docker compose -f docker-compose.dev.yml logs --tail=100 backend
docker logs --tail=100 deepiri-backend-dev
```

**View logs with timestamps:**
```bash
docker compose -f docker-compose.dev.yml logs -t backend
docker logs -t deepiri-backend-dev
```

**View logs since specific time:**
```bash
docker compose -f docker-compose.dev.yml logs --since 10m backend
docker logs --since 2024-11-04T20:00:00 deepiri-backend-dev
```

**View logs until specific time:**
```bash
docker compose -f docker-compose.dev.yml logs --until 2024-11-04T21:00:00 backend
```

**Combine options:**
```bash
# Follow last 50 lines with timestamps
docker compose -f docker-compose.dev.yml logs -f --tail=50 -t backend
```

#### 4. View Multiple Services at Once

**View logs for multiple services:**
```bash
docker compose -f docker-compose.dev.yml logs backend pyagent
docker compose -f docker-compose.dev.yml logs backend frontend-dev mongodb
```

**View all services:**
```bash
docker compose -f docker-compose.dev.yml logs
```

#### 5. Filter Logs

**Search logs for specific text:**
```bash
docker compose -f docker-compose.dev.yml logs backend | grep "error"
docker logs deepiri-backend-dev | grep -i "challenge"
```

**Case-insensitive search:**
```bash
docker logs deepiri-backend-dev | grep -i "error"
```

**Search with context (show surrounding lines):**
```bash
docker logs deepiri-backend-dev | grep -A 5 -B 5 "error"
```

**Multiple search terms:**
```bash
docker logs deepiri-backend-dev | grep -E "error|warn|challenge"
```

#### 6. Save Logs to File

**Save logs to file:**
```bash
docker compose -f docker-compose.dev.yml logs backend > backend.log
docker logs deepiri-backend-dev > backend.log
```

**Append to file:**
```bash
docker logs deepiri-backend-dev >> backend.log
```

**Save with timestamps:**
```bash
docker logs -t deepiri-backend-dev > backend-with-timestamps.log
```

#### 7. Inspect Container Logs Directly

**View log file location:**
```bash
docker inspect deepiri-backend-dev | grep LogPath
```

**View container stats (includes log info):**
```bash
docker stats deepiri-backend-dev
```

## Common Use Cases

### Debug Backend Errors
```bash
# View recent errors
docker compose -f docker-compose.dev.yml logs --tail=100 backend | grep -i error

# Follow logs in real-time to see errors as they happen
docker compose -f docker-compose.dev.yml logs -f backend
```

### Monitor API Requests
```bash
# Watch backend logs for API calls
docker compose -f docker-compose.dev.yml logs -f backend | grep "GET\|POST\|PUT\|DELETE"
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

# View specific services together
docker compose -f docker-compose.dev.yml logs -f backend pyagent frontend-dev
```

### Check Container Health
```bash
# View health check logs
docker inspect deepiri-backend-dev | grep -A 10 Health

# View container status
docker ps -a --filter "name=deepiri"
```

## Troubleshooting

### Container Not Starting
```bash
# Check why container exited
docker logs deepiri-backend-dev

# View last 100 lines
docker logs --tail=100 deepiri-backend-dev
```

### High Memory Usage
```bash
# Monitor resource usage
docker stats deepiri-backend-dev

# Check logs for memory issues
docker logs deepiri-backend-dev | grep -i memory
```

### Connection Issues
```bash
# Check backend connection logs
docker compose -f docker-compose.dev.yml logs backend | grep -i "connect\|mongodb\|redis"

# Check all services for connection errors
docker compose -f docker-compose.dev.yml logs | grep -i "error\|failed\|timeout"
```

## Log File Locations

### Application Logs (Inside Containers)
- **Backend**: `/app/logs/` (mounted to `./api-server/logs/`)
- **Python Service**: Logs to stdout/stderr (captured by Docker)

### Docker Logs
Docker stores logs in:
- **Linux**: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
- **Windows**: `C:\ProgramData\docker\containers\<container-id>\<container-id>-json.log`

### Access Log Files Directly
```bash
# View backend application logs (if mounted)
cat ./api-server/logs/combined.log
cat ./api-server/logs/error.log

# Follow backend logs
tail -f ./api-server/logs/combined.log
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
# All services
docker compose -f docker-compose.dev.yml logs -f

# Single service
docker compose -f docker-compose.dev.yml logs -f backend

# Last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100 backend

# With timestamps
docker compose -f docker-compose.dev.yml logs -f -t backend

# Search for errors
docker compose -f docker-compose.dev.yml logs backend | grep -i error

# Multiple services
docker compose -f docker-compose.dev.yml logs -f backend pyagent

# Save to file
docker compose -f docker-compose.dev.yml logs backend > backend.log
```

