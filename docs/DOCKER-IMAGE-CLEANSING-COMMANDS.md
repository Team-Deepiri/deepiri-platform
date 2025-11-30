# Docker Compose Rebuild Commands

## ✅ FIXED: Now docker-compose automatically manages images!

All services now have explicit `image:` tags, so docker-compose can properly clean them up.

## Normal Operation vs Rebuilding

### Normal Start (Uses Existing Images) ✅
```bash
# This does NOT rebuild - uses existing images (fast!)
docker compose -f docker-compose.dev.yml up -d
```

**Use this for:** Daily development, restarting services, normal operations.

### Rebuilding (Only When Needed)

Rebuild only when:
- Code changes require new images
- Dependencies updated
- You want fresh images
- After pulling new code

#### Using Rebuild Scripts (Easiest)
```bash
# Linux/Mac
./rebuild.sh

# Windows PowerShell
.\rebuild.ps1

# Or specify a different compose file
./rebuild.sh docker-compose.yml
.\rebuild.ps1 -ComposeFile docker-compose.yml
```

### Manual Commands

#### PowerShell
```powershell
# Stop and remove old images
docker compose -f docker-compose.dev.yml down --rmi local

# Clean build cache
docker builder prune -af

# Rebuild
docker compose -f docker-compose.dev.yml build --no-cache

# Start
docker compose -f docker-compose.dev.yml up -d
```

#### Bash/Linux
```bash
# One-liner
docker compose -f docker-compose.dev.yml down --rmi local && \
docker builder prune -af && \
docker compose -f docker-compose.dev.yml build --no-cache && \
docker compose -f docker-compose.dev.yml up -d
```

### Using Make (Optional - if you have `make` installed)
```bash
make rebuild        # Full clean rebuild
make rebuild-service SERVICE=cyrex  # Rebuild one service
make clean          # Clean everything
```

See [MAKEFILE-EXPLANATION.md](MAKEFILE-EXPLANATION.md) for details on the Makefile.

## What `--rmi local` Does

The `--rmi local` flag tells docker-compose to remove **only images created by this compose file**. This is safe because:
- ✅ Removes old `deepiri-dev-*` images
- ✅ Keeps base images (node, python, mongo, etc.)
- ✅ Keeps images from other projects

## Quick Reference

```powershell
# Check disk usage
docker system df

# Remove old images (safe)
docker compose -f docker-compose.dev.yml down --rmi local

# Clean build cache
docker builder prune -af

# Rebuild specific service
docker compose -f docker-compose.dev.yml build --no-cache cyrex

# Rebuild all
docker compose -f docker-compose.dev.yml build --no-cache
```

## Why This Works Now

Before: Services had no `image:` tag, so docker-compose created random names like `deepiri-dev_api-gateway_1` and couldn't clean them up properly.

After: All services have explicit `image: deepiri-dev-{service}:latest` tags, so:
- ✅ docker-compose knows which images belong to this project
- ✅ `--rmi local` removes them automatically
- ✅ No more storage bloat!

## Workflow Integration

### Recommended Workflow
1. **Normal operation:** Use `docker compose up` (no rebuild, fast!)
2. **After code changes:** Use `rebuild.sh` / `rebuild.ps1` to rebuild
3. **Check disk usage weekly**: `docker system df`
4. **Run cleanup if needed**: `docker builder prune -af`

### In Your Daily Workflow
```bash
# Normal start (uses existing images - fast!)
docker compose -f docker-compose.dev.yml up -d

# Restart services (no rebuild)
docker compose -f docker-compose.dev.yml restart

# Rebuild after code changes
./rebuild.sh              # Linux/Mac
.\rebuild.ps1             # Windows

# View logs
docker compose -f docker-compose.dev.yml logs -f
```

**Key Point:** Normal `docker compose up` does NOT rebuild - it's fast and efficient. Only rebuild when code changes!


