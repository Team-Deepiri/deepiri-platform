#!/bin/bash
# Quick script to tag Skaffold images for Docker Compose

set -e

echo "🏷️  Tagging Skaffold images for Docker Compose..."
echo ""

# Ensure Docker is pointing to Minikube
eval $(minikube docker-env)

# Tag mappings: find any Skaffold image -> tag as Docker Compose expects
TAG_MAPPINGS=(
    "deepiri-cyrex:deepiri-dev-cyrex:latest"
    "deepiri-frontend:deepiri-dev-frontend:latest"
    "deepiri-api-gateway:deepiri-dev-api-gateway:latest"
    "deepiri-auth-service:deepiri-dev-auth-service:latest"
    "deepiri-truss:deepiri-dev-truss:latest"
    "deepiri-jobs:deepiri-dev-jobs:latest"
    "deepiri-registry:deepiri-dev-registry:latest"
    "deepiri-telemetry:deepiri-dev-telemetry:latest"
    "deepiri-external-bridge-service:deepiri-dev-external-bridge-service:latest"
    "deepiri-realtime-gateway:deepiri-dev-realtime-gateway:latest"
)

TAGGED=0
for mapping in "${TAG_MAPPINGS[@]}"; do
    IFS=':' read -r source_name target_name target_tag <<< "$mapping"
    
    # Find the actual image (with any tag)
    SOURCE_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${source_name}:" | head -1)
    
    if [ -n "$SOURCE_IMAGE" ]; then
        TARGET="${target_name}:${target_tag}"
        docker tag "$SOURCE_IMAGE" "$TARGET" 2>/dev/null && {
            echo "✅ Tagged: $SOURCE_IMAGE -> $TARGET"
            TAGGED=$((TAGGED + 1))
        } || echo "⚠️  Failed to tag: $SOURCE_IMAGE"
    else
        echo "⚠️  Image not found: $source_name"
    fi
done

echo ""
if [ $TAGGED -gt 0 ]; then
    echo "✅ Tagged $TAGGED images successfully!"
    echo ""
    echo "Now you can run:"
    echo "  docker compose -f docker-compose.dev.yml up -d"
else
    echo "❌ No images were tagged. Make sure:"
    echo "   1. Skaffold has built images: skaffold build -f skaffold-local.yaml"
    echo "   2. Docker is pointing to Minikube: eval \$(minikube docker-env)"
fi

