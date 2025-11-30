# Storage Optimization - Preventing Duplicate Images

## Problem

Skaffold can create multiple image tags (SHA256 hashes, "dirty" tags, etc.) which wastes storage space. You want Skaffold to **overwrite** the `:latest` tag instead of creating duplicates.

## Solution

### 1. Skaffold Configuration (Already Set!)

The `skaffold-local.yaml` already has the correct configuration:

```yaml
tagPolicy:
  customTemplate:
    template: "latest"  # Always uses :latest tag (overwrites)
```

This ensures Skaffold always tags images as `:latest`, which **overwrites** the previous build instead of creating duplicates.

### 2. Automatic Cleanup After Builds

After running Skaffold builds, run the cleanup script to remove any old tags:

```bash
# After skaffold build
skaffold build -f skaffold-local.yaml -p dev-compose
./scripts/cleanup-old-image-tags.sh
```

### 3. Integrated Cleanup (Automatic)

The hybrid build script (`build-with-skaffold-run-with-docker.sh`) automatically cleans up old tags after building.

## Manual Cleanup

If you have duplicate images, clean them up manually:

```bash
# Point Docker to Minikube
eval $(minikube docker-env)

# Remove old tags (keeps only :latest)
./scripts/cleanup-old-image-tags.sh
```

## Force Rebuild (Without --no-cache)

To rebuild without using `--no-cache` (uses Docker cache, saves time):

```bash
# Normal rebuild (uses cache)
./scripts/force-rebuild-all.sh

# Force complete rebuild (no cache)
./scripts/force-rebuild-all.sh --no-cache
```

## Storage Savings

Before cleanup:
- `deepiri-dev-cyrex:latest`
- `deepiri-dev-cyrex:sha256-abc123`
- `deepiri-dev-cyrex:d13a904`
- `deepiri-dev-cyrex:dirty`

After cleanup:
- `deepiri-dev-cyrex:latest` ✅ (only one!)

This saves **significant storage space** by removing duplicate images.

