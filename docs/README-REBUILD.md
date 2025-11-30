# Docker Rebuild Guide

## Problem
When rebuilding Docker containers, old images aren't automatically removed, causing:
- Storage bloat (50GB+ of old images)
- Builds stacking on top of old layers
- No disk space

## Solution: Use Clean Rebuild Scripts

### PowerShell (Windows)
```powershell
.\rebuild-clean.ps1
```

### Bash (Linux/WSL)
```bash
./rebuild-clean.sh
```

## What These Scripts Do

1. **Stop all containers** - Safely stops running containers
2. **Remove old Deepiri images** - Deletes all `deepiri-*` images before rebuilding
3. **Clean build cache** - Removes Docker build cache to free space
4. **Rebuild fresh** - Builds new images from scratch (no cache)
5. **Clean again** - Removes build cache after build

## Options

### Rebuild specific service
```powershell
.\rebuild-clean.ps1 -Service cyrex
```

### Rebuild with cache (faster but may keep old layers)
```powershell
.\rebuild-clean.ps1 -NoCache:$false
```

## Alternative: Manual Cleanup

If you just want to clean without rebuilding:

```powershell
.\stop-and-cleanup.ps1
```

Then rebuild normally:
```powershell
docker-compose -f docker-compose.dev.yml build --no-cache
```

## Quick Commands

### Check disk usage
```powershell
docker system df
```

### Remove all Deepiri images manually
```powershell
docker images --filter "reference=*deepiri*" --format "{{.ID}}" | ForEach-Object { docker rmi -f $_ }
```

### Clean build cache
```powershell
docker builder prune -af
```

### Nuclear option (removes EVERYTHING)
```powershell
docker system prune -a --volumes -f
```

## Best Practices

1. **Always use `rebuild-clean.ps1`** instead of `docker-compose build`
2. **Run cleanup weekly** to prevent storage bloat
3. **Check disk usage** before/after: `docker system df`
4. **Use `--no-cache`** when dependencies change

## Storage Management

Docker can use a lot of space. Regular cleanup prevents:
- Running out of disk space
- Slow builds (too many layers)
- Confusion from old images

Run `docker system df` regularly to monitor usage!


