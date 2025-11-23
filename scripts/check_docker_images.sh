#!/bin/bash
# Check if images exist in Minikube's Docker

eval $(minikube docker-env)

echo "Checking for deepiri-dev-*:latest images..."
echo ""

IMAGES=(
    "deepiri-dev-cyrex:latest"
    "deepiri-dev-frontend:latest"
    "deepiri-dev-api-gateway:latest"
    "deepiri-dev-auth-service:latest"
    "deepiri-dev-task-orchestrator:latest"
    "deepiri-dev-challenge-service:latest"
    "deepiri-dev-engagement-service:latest"
    "deepiri-dev-platform-analytics-service:latest"
    "deepiri-dev-external-bridge-service:latest"
    "deepiri-dev-notification-service:latest"
    "deepiri-dev-realtime-gateway:latest"
    "deepiri-dev-jupyter:latest"
)

MISSING=0
for img in "${IMAGES[@]}"; do
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}$"; then
        echo "✅ $img"
    else
        echo "❌ MISSING: $img"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
if [ $MISSING -gt 0 ]; then
    echo "⚠️  $MISSING images are missing!"
    echo ""
    echo "Build them with:"
    echo "  skaffold build -f skaffold-local.yaml -p dev-compose"
    echo "  ./scripts/tag-skaffold-to-latest.sh"
else
    echo "✅ All images exist!"
fi

