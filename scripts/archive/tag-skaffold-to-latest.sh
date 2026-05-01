#!/bin/bash
# Tag Skaffold-built images with :latest so Docker Compose can use them

set -e

echo "🏷️  Tagging Skaffold images with :latest for Docker Compose..."
echo ""

# Ensure Docker is pointing to Minikube
eval $(minikube docker-env)

# Find and tag all deepiri-dev-* images (any tag) to :latest
IMAGES=(
    "deepiri-dev-cyrex"
    "deepiri-dev-frontend"
    "deepiri-dev-api-gateway"
    "deepiri-dev-auth-service"
    "deepiri-dev-workflow-orchestrator"
    "deepiri-dev-adaptive-experience-engine"
    "deepiri-dev-incentive-engine"
    "deepiri-dev-decision-intelligence"
    "deepiri-dev-external-bridge-service"
    "deepiri-dev-communications-hub"
    "deepiri-dev-realtime-gateway"
)

TAGGED=0
for img in "${IMAGES[@]}"; do
    # Find the image with any tag (excluding :latest if it exists)
    # Use a more robust method to find the source image
    SOURCE_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" "$img" 2>/dev/null | grep -v ":latest$" | head -1)
    
    if [ -z "$SOURCE_IMAGE" ]; then
        # Try alternative method - get all images and filter
        SOURCE_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${img}:" | grep -v ":latest$" | head -1)
    fi
    
    if [ -n "$SOURCE_IMAGE" ]; then
        TARGET="${img}:latest"
        if docker tag "$SOURCE_IMAGE" "$TARGET" 2>/dev/null; then
            echo "✅ Tagged: $SOURCE_IMAGE -> $TARGET"
            TAGGED=$((TAGGED + 1))
        else
            echo "⚠️  Failed to tag: $SOURCE_IMAGE"
        fi
    else
        # Check if :latest already exists
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}:latest$"; then
            echo "✅ Already tagged: ${img}:latest"
        else
            echo "⚠️  Image not found: $img"
        fi
    fi
done

echo ""
if [ $TAGGED -gt 0 ]; then
    echo "✅ Tagged $TAGGED images with :latest!"
    echo ""
    echo "Now Docker Compose will use them:"
    echo "  docker compose -f docker-compose.dev.yml up -d"
else
    echo "⚠️  No images were tagged. Make sure Skaffold has built images."
    echo ""
    echo "Available images:"
    docker images --format "  - {{.Repository}}:{{.Tag}}" | grep "deepiri-dev" | head -15
fi

