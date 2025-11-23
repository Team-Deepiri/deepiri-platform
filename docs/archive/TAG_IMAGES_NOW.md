# Common Issue:

Skaffold builds images with commit hash tags (like `deepiri-dev-api-gateway:d13a904`), but Docker Compose expects `:latest` tags.

## Immediate Fix

Run this NOW to tag your existing images:

```bash
# Make sure Docker is pointing to Minikube
eval $(minikube docker-env)

# Tag all Skaffold-built images with :latest
docker tag deepiri-dev-api-gateway:d13a904 deepiri-dev-api-gateway:latest
docker tag deepiri-dev-auth-service:$(docker images --format "{{.Tag}}" deepiri-dev-auth-service | grep -v latest | head -1) deepiri-dev-auth-service:latest
docker tag deepiri-dev-task-orchestrator:$(docker images --format "{{.Tag}}" deepiri-dev-task-orchestrator | grep -v latest | head -1) deepiri-dev-task-orchestrator:latest
docker tag deepiri-dev-challenge-service:$(docker images --format "{{.Tag}}" deepiri-dev-challenge-service | grep -v latest | head -1) deepiri-dev-challenge-service:latest
docker tag deepiri-dev-engagement-service:$(docker images --format "{{.Tag}}" deepiri-dev-engagement-service | grep -v latest | head -1) deepiri-dev-engagement-service:latest
docker tag deepiri-dev-platform-analytics-service:$(docker images --format "{{.Tag}}" deepiri-dev-platform-analytics-service | grep -v latest | head -1) deepiri-dev-platform-analytics-service:latest
docker tag deepiri-dev-external-bridge-service:$(docker images --format "{{.Tag}}" deepiri-dev-external-bridge-service | grep -v latest | head -1) deepiri-dev-external-bridge-service:latest
docker tag deepiri-dev-notification-service:$(docker images --format "{{.Tag}}" deepiri-dev-notification-service | grep -v latest | head -1) deepiri-dev-notification-service:latest
docker tag deepiri-dev-realtime-gateway:$(docker images --format "{{.Tag}}" deepiri-dev-realtime-gateway | grep -v latest | head -1) deepiri-dev-realtime-gateway:latest

# Or use the script:
chmod +x scripts/tag-skaffold-to-latest.sh
./scripts/tag-skaffold-to-latest.sh
```

## Or Use the Script (Easier)

```bash
eval $(minikube docker-env)
chmod +x scripts/tag-skaffold-to-latest.sh
./scripts/tag-skaffold-to-latest.sh
docker compose -f docker-compose.dev.yml up -d
```

## Verify

```bash
docker images | grep "deepiri-dev-.*:latest"
```

You should see all 11 images with `:latest` tags.

## Then Run Docker Compose

```bash
docker compose -f docker-compose.dev.yml up -d
```

**It will use the images instead of building!**

