# Build, Run, and Stop Workflow

## Normal Workflow (Recommended)

### 1. Build Everything
```bash
cd deepiri
skaffold build -f skaffold-local.yaml -p dev-compose
```

**Note:** This uses Docker's cache, which is GOOD! It makes rebuilds fast when you only change a few files.

### 2. Run Everything (Docker Compose)
```bash
docker compose -f docker-compose.dev.yml up -d
```

### 3. Stop Everything
```bash
docker compose -f docker-compose.dev.yml down
```

### 4. Clean Up Old Images (When Storage Gets Full)
```bash
# Clean up dangling images (safe - only removes unused layers)
docker system prune -f

# OR more aggressively - removes ALL unused images (frees more space)
docker system prune -a -f
```

## When You Make Changes

### Rebuild Only What Changed
```bash
# Skaffold will automatically detect changes and rebuild only affected images
skaffold build -f skaffold-local.yaml -p dev-compose
```

### Restart Containers
```bash
# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Start with new images
docker compose -f docker-compose.dev.yml up -d
```

## Complete Clean Slate (Only When Needed)

If you want to force a complete rebuild of everything:

```bash
# 1. Stop everything
docker compose -f docker-compose.dev.yml down

# 2. Remove all old images
docker system prune -a -f

# 3. Rebuild everything (will be slower, but fresh)
skaffold build -f skaffold-local.yaml -p dev-compose --cache-artifacts=false

# 4. Start everything
docker compose -f docker-compose.dev.yml up -d
```

## Quick Reference

### Setup Minikube (if you need the Kubernetes tooling)
1. Check status:
   ```bash
   minikube status
   ```
2. Start it (if the status is not running):
   ```bash
   minikube start --driver=docker --cpus=4 --memory=8192
   ```
3. Point Docker at Minikube’s daemon:
   ```bash
   eval $(minikube docker-env)
   ```

### Build, Run, Stop, Logs
| Task | Command |
|------|---------|
| Build | `skaffold build -f skaffold-local.yaml -p dev-compose` |
| Run | `docker compose -f docker-compose.dev.yml up -d` |
| Stop | `docker compose -f docker-compose.dev.yml down` |
| Logs (all) | `docker compose -f docker-compose.dev.yml logs -f` |
| Logs (service) | `docker compose -f docker-compose.dev.yml logs -f <service>` |

### General workflow
- Start the stack (build + run)
  ```bash
  skaffold build -f skaffold-local.yaml -p dev-compose
  docker compose -f docker-compose.dev.yml up -d
  ```
- Tail every container’s logs in one command:
  ```bash
  docker compose -f docker-compose.dev.yml logs -f
  ```

## Understanding Docker Cache

- ✅ **Cache is GOOD** - Makes rebuilds fast
- ✅ **Only changed layers rebuild** - If you change one file, only that layer rebuilds
- ✅ **Old images are safe to remove** - Docker keeps them until you prune
- ⚠️ **Storage grows** - Old images accumulate until you clean them

**Solution:** Run `docker system prune -a -f` periodically (weekly/monthly) to free up space.


