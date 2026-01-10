# Docker Cleanup Guide

## Problem
Docker can accumulate a lot of disk space from:
- **Build cache**: Old build layers that are no longer needed (can be 10-50GB+)
- **Unused images**: Old versions of images after rebuilding
- **Stopped containers**: Containers that are no longer running

## Solution

### Quick Cleanup
After building containers, run:
```bash
./scripts/docker-cleanup.sh
```

This will:
- Remove all build cache (frees ~10-50GB typically)
- Remove unused images (keeps active ones)
- Remove stopped containers
- Show before/after disk usage

### Build with Auto-Cleanup
Use the build script that automatically cleans up after building:
```bash
./scripts/build-with-cleanup.sh docker-compose.dev.yml
```

This will:
1. Build all containers
2. Automatically clean up build cache
3. Show disk usage

### Manual Cleanup Commands

**Check disk usage:**
```bash
docker system df
```

**Remove build cache only:**
```bash
docker builder prune -a -f
```

**Remove unused images:**
```bash
docker image prune -a -f
```

**Remove stopped containers:**
```bash
docker container prune -f
```

**Full cleanup (removes everything unused):**
```bash
docker system prune -a --volumes -f
```
⚠️ **Warning**: This removes ALL unused images, containers, networks, and volumes!

## Automatic Cleanup

### Option 1: Use the Build Script
Always use `build-with-cleanup.sh` instead of `docker-compose build`:
```bash
./scripts/build-with-cleanup.sh docker-compose.dev.yml
```

### Option 2: Configure Docker Daemon (Advanced)
You can configure Docker to automatically prune build cache. Edit `/etc/docker/daemon.json`:
```json
{
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "10GB"
    }
  }
}
```

Then restart Docker:
```bash
sudo systemctl restart docker
```

## Understanding Docker Storage

When you rebuild containers:
- Docker **reuses** layers that haven't changed (saves space)
- Docker **keeps** old build cache (takes space)
- Docker **keeps** old image versions (takes space)

The cleanup scripts remove the unused cache and old images while keeping what's currently in use.

## Disk Usage Breakdown

Run `docker system df` to see:
- **Images**: Your container images (can be 30-50GB for all services)
- **Containers**: Running/stopped containers (usually small, <1GB)
- **Volumes**: Data volumes (MongoDB, Redis, etc. - keep these!)
- **Build Cache**: Build layers (can be 10-50GB - safe to remove)

## Best Practices

1. **After each build**: Run `docker builder prune -a -f` to clean cache
2. **Weekly**: Run `./scripts/docker-cleanup.sh` for full cleanup
3. **Before builds**: Check `docker system df` to see current usage
4. **Keep volumes**: Don't remove volumes unless you want to lose data

## Troubleshooting

**"No space left on device" error:**
```bash
# Check usage
docker system df

# Clean everything unused
docker system prune -a --volumes -f

# Or just build cache
docker builder prune -a -f
```

**Want to keep specific images:**
Tag them before cleanup:
```bash
docker tag old-image:tag backup-image:tag
```

