# Automatic Cleanup Configuration

## What's Configured

### 1. Skaffold Auto-Cleanup (AUTOMATIC)

`skaffold-local.yaml` now has a **post-build hook** that automatically runs `docker image prune -f` after every build:

```yaml
hooks:
  after:
    - host:
        command: ["sh", "-c", "docker image prune -f > /dev/null 2>&1 || true"]
```

**This runs automatically** every time you run:
- `skaffold build -f skaffold-local.yaml -p dev-compose`
- Any Skaffold command

### 2. Docker BuildKit Config (AUTOMATIC)

`daemon.json` configures Docker to automatically garbage collect old build cache:

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

To apply this config:

**Linux/Mac:**
```bash
sudo cp daemon.json /etc/docker/daemon.json
sudo systemctl restart docker
```

**Windows:**
```powershell
# Copy to C:\ProgramData\docker\config\daemon.json
cp daemon.json C:\ProgramData\docker\config\daemon.json
# Restart Docker Desktop
```

**Minikube:**
```bash
# Minikube has its own Docker daemon, set env var
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain
```

### 3. Docker Compose Auto-Cleanup (ALREADY CONFIGURED)

`docker-compose.dev.yml` uses `pull_policy: never` which means it will:
- ✅ Use existing `:latest` images
- ✅ NOT build if images exist
- ✅ NOT create duplicates

## How It Works

When you run `skaffold build`:

1. **Build** - Skaffold builds images tagged as `:latest`
2. **Tag** - New image gets `:latest` tag
3. **Old image** - Previous `:latest` becomes untagged (dangling)
4. **Auto-cleanup** - Post-build hook runs `docker image prune -f`
5. **Result** - Only ONE `:latest` image exists, old dangling images removed

## No Scripts Needed!

You don't need to run cleanup scripts manually. The configuration handles it automatically:

```bash
# Just run this - cleanup happens automatically!
skaffold build -f skaffold-local.yaml -p dev-compose
```

## Verify It's Working

After running `skaffold build`, check for dangling images:

```bash
# Should show NO dangling images
docker images -f "dangling=true"
```

## Manual Cleanup (If Needed)

If you want to clean up manually:

```bash
# Remove dangling images
docker image prune -f

# Remove ALL unused images (aggressive)
docker image prune -a -f

# Remove build cache
docker builder prune -a -f
```

## Storage Savings

**Before auto-cleanup:**
- `deepiri-dev-cyrex:latest` (new)
- `<none>:<none>` (old, dangling)
- `<none>:<none>` (older, dangling)
- Total: 3 images taking up storage

**After auto-cleanup:**
- `deepiri-dev-cyrex:latest` (only one!)
- Total: 1 image ✅

**Automatic cleanup saves storage without any manual intervention!**

