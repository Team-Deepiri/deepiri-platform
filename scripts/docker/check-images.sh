#!/bin/bash
# Quick script to check if images exist and stop Docker Compose from building

echo "🔍 Checking for Docker Compose images..."
echo ""

# Ensure Docker is pointing to Minikube
eval $(minikube docker-env)

echo "Looking for images Docker Compose expects:"
echo ""

EXPECTED_IMAGES=(
    "deepiri-dev-cyrex:latest"
    "deepiri-dev-frontend:latest"
    "deepiri-dev-api-gateway:latest"
    "deepiri-dev-auth-service:latest"
    "deepiri-dev-truss:latest"
    "deepiri-dev-jobs:latest"
    "deepiri-dev-registry:latest"
    "deepiri-dev-telemetry:latest"
    "deepiri-dev-external-bridge-service:latest"
    "deepiri-dev-realtime-gateway:latest"
)

MISSING=0
for img in "${EXPECTED_IMAGES[@]}"; do
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}$"; then
        echo "✅ Found: $img"
    else
        echo "❌ Missing: $img"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
if [ $MISSING -gt 0 ]; then
    echo "⚠️  $MISSING images are missing!"
    echo ""
    echo "Build them with:"
    echo "  eval \$(minikube docker-env)"
    echo "  skaffold build -f skaffold/skaffold-local.yaml -p dev-compose"
    echo ""
else
    echo "✅ All images exist! Docker Compose should use them (not build)."
    echo ""
    echo "If Docker Compose is still building, try:"
    echo "  docker compose -f docker-compose.dev.yml up -d --no-build"
fi

