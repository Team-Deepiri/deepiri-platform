# Docker Log Management

## Overview

Docker logs are now configured to be **minimal and auto-clearing**. This prevents log files from accumulating and consuming disk space.

## Current Configuration

### Per-Container Settings (docker-compose.dev.yml)

All services use minimal logging:

```yaml
x-logging: &minimal-logging
  driver: "local"
  options:
    max-size: "1m"      # Only 1MB per file
    max-file: "1"       # Only 1 file (no rotation backup)
    compress: "false"   # No compression (faster cleanup)
```

This means:
- ✅ Each container keeps only **1MB** of logs
- ✅ No backup/rotation files (only 1 file per container)
- ✅ Logs are automatically overwritten when limit is reached
- ✅ Total log space: ~17MB for all services (vs. 510MB before)

## Clearing Logs

### Automatic Clearing

Logs are automatically cleared when:
1. Container restarts
2. Log file reaches 1MB limit
3. You run `docker compose down` and `docker compose up`

### Manual Clearing

#### Option 1: PowerShell (Windows)
```powershell
cd deepiri
.\scripts\clear-docker-logs.ps1
```

#### Option 2: Bash (Linux/Mac/WSL)
```bash
cd deepiri
./scripts/clear-docker-logs.sh
```

#### Option 3: Docker Compose Restart
```bash
docker compose -f docker-compose.dev.yml restart
```

#### Option 4: Individual Container
```bash
docker compose -f docker-compose.dev.yml restart <service-name>
```

## Viewing Logs

### View Recent Logs (Recommended)

Since logs are limited to 1MB, always view recent logs:

```bash
# Last 50 lines
docker compose -f docker-compose.dev.yml logs --tail=50 <service-name>

# Last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100 <service-name>

# Follow logs (live stream)
docker compose -f docker-compose.dev.yml logs -f --tail=50 <service-name>
```

### View All Available Logs

```bash
# All logs (limited to 1MB)
docker compose -f docker-compose.dev.yml logs <service-name>

# All logs for all services
docker compose -f docker-compose.dev.yml logs
```

## Global Docker Configuration (Optional)

### For WSL2 Users

Create or edit `/etc/docker/daemon.json` in WSL:

```bash
sudo nano /etc/docker/daemon.json
```

Add:

```json
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "1m",
    "max-file": "1",
    "compress": "false"
  }
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

### For Docker Desktop Users

1. Open Docker Desktop
2. Go to **Settings** → **Docker Engine**
3. Add to the JSON configuration:

```json
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "1m",
    "max-file": "1",
    "compress": "false"
  }
}
```

4. Click **Apply & Restart**

## Logging Strategies

### Development (Current Setup)

- **Minimal logs (1MB)** - Fast, no disk space issues
- Suitable for local development
- View logs with `docker compose logs`

### Production (Different Setup)

For production, you would use:
- Centralized logging (ELK, Splunk, CloudWatch)
- Log aggregation services
- Longer retention periods
- This is handled by Kubernetes/cloud providers

## Troubleshooting

### "Logs are being truncated too quickly"

If you need more logs temporarily:

1. Edit `docker-compose.dev.yml`
2. Change the logging config:

```yaml
x-logging: &minimal-logging
  driver: "local"
  options:
    max-size: "5m"      # Increase to 5MB
    max-file: "2"       # Keep 2 files
```

3. Restart services:
```bash
docker compose -f docker-compose.dev.yml restart
```

### "I need to save logs for debugging"

Export logs before they're cleared:

```bash
# Export all logs
docker compose -f docker-compose.dev.yml logs > all-logs.txt

# Export specific service
docker compose -f docker-compose.dev.yml logs <service-name> > service-logs.txt

# Export with timestamps
docker compose -f docker-compose.dev.yml logs -t > logs-with-timestamps.txt
```

### "Where are the log files stored?"

Docker stores logs in:

- **Linux/WSL:** `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
- **Docker Desktop:** Inside the Docker VM (not directly accessible)

You should access logs using `docker logs` or `docker compose logs` commands.

## Comparison

### Before (Old Configuration)

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

- **Per service:** 30MB (10MB × 3 files)
- **Total (17 services):** ~510MB
- **Retention:** 3 rotated files

### After (Current Configuration)

```yaml
logging: *minimal-logging
  driver: "local"
  options:
    max-size: "1m"
    max-file: "1"
```

- **Per service:** 1MB (1MB × 1 file)
- **Total (17 services):** ~17MB
- **Retention:** No rotation, auto-clear

**Space Saved:** ~493MB (97% reduction)

## Best Practices

1. **View logs frequently** - Since logs are limited, check them regularly
2. **Use tail flag** - Always use `--tail=N` to limit output
3. **Export for analysis** - Save logs to file if you need to analyze them
4. **Monitor in real-time** - Use `-f` flag for live log streaming
5. **Clear periodically** - Run `clear-docker-logs.ps1` if needed

## Scripts

- `scripts/clear-docker-logs.ps1` - Clear all Docker logs (PowerShell)
- `scripts/clear-docker-logs.sh` - Clear all Docker logs (Bash)

## Additional Resources

- [Docker Logging Documentation](https://docs.docker.com/config/containers/logging/)
- [Docker Compose Logging](https://docs.docker.com/compose/compose-file/compose-file-v3/#logging)
- [Docker Local Logging Driver](https://docs.docker.com/config/containers/logging/local/)

---

**Last Updated:** 2025-11-22

