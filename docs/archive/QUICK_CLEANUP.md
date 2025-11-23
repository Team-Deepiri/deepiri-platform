# Quick Image Cleanup

## The Problem

You have **TONS** of duplicate images with different tags:
- `deepiri-dev-api-gateway:latest` ✅ (keep this)
- `deepiri-dev-api-gateway:d13a904` ❌ (delete)
- `deepiri-dev-api-gateway:21b44718f445...` ❌ (delete)
- `deepiri-api-gateway:d13a904` ❌ (old, delete)
- etc.

## Quick Cleanup Commands

### Option 1: Keep Only :latest Tags (Recommended)

```bash
eval $(minikube docker-env)

# Delete all deepiri-dev-* images EXCEPT :latest
for img in deepiri-dev-cyrex deepiri-dev-frontend deepiri-dev-api-gateway deepiri-dev-auth-service deepiri-dev-task-orchestrator deepiri-dev-challenge-service deepiri-dev-engagement-service deepiri-dev-platform-analytics-service deepiri-dev-external-bridge-service deepiri-dev-notification-service deepiri-dev-realtime-gateway; do
    docker images --format "{{.Repository}}:{{.Tag}}" "$img" | grep -v ":latest$" | xargs -r docker rmi -f
done

# Delete old deepiri-* images (without -dev-)
docker images --format "{{.Repository}}:{{.Tag}}" | grep "^deepiri-" | grep -v "deepiri-dev-" | grep -v "deepiri-core-api" | xargs -r docker rmi -f
```

### Option 2: Use the Cleanup Script

```bash
chmod +x scripts/cleanup-images.sh
./scripts/cleanup-images.sh
```

### Option 3: Nuclear Option (Delete Everything Deepiri)

```bash
eval $(minikube docker-env)

# Delete ALL deepiri images
docker rmi $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "deepiri") -f

# Then rebuild with Skaffold
skaffold build -f skaffold-local.yaml -p dev-compose
```

## What You Should Keep

Only keep these `:latest` tags:
- `deepiri-dev-cyrex:latest`
- `deepiri-dev-frontend:latest`
- `deepiri-dev-api-gateway:latest`
- `deepiri-dev-auth-service:latest`
- `deepiri-dev-task-orchestrator:latest`
- `deepiri-dev-challenge-service:latest`
- `deepiri-dev-engagement-service:latest`
- `deepiri-dev-platform-analytics-service:latest`
- `deepiri-dev-external-bridge-service:latest`
- `deepiri-dev-notification-service:latest`
- `deepiri-dev-realtime-gateway:latest`

Everything else can be deleted!

## After Cleanup

```bash
# Verify you only have :latest tags
docker images | grep "deepiri-dev" | grep ":latest"

# Should show only 11 images
```

