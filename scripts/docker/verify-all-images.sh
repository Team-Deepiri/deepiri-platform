#!/bin/bash
# Verify all required images exist

echo "🔍 Verifying all Docker Compose images exist..."
echo ""

eval $(minikube docker-env)

# All images Docker Compose expects
REQUIRED_IMAGES=(
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
for img in "${REQUIRED_IMAGES[@]}"; do
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}$"; then
        echo "✅ $img"
    else
        echo "❌ MISSING: $img"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
if [ $MISSING -eq 0 ]; then
    echo "✅ All images exist! Docker Compose should use them (not build)."
    echo ""
    echo "Run: docker compose -f docker-compose.dev.yml up -d"
else
    echo "⚠️  $MISSING image(s) missing!"
    echo ""
    echo "Build missing images with:"
    echo "  skaffold build -f skaffold/skaffold-local.yaml -p dev-compose"
    echo ""
    echo "Or run Docker Compose with --no-build to skip building:"
    echo "  docker compose -f docker-compose.dev.yml up -d --no-build"
fi

