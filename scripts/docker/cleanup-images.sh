#!/bin/bash
# Clean up duplicate Docker images - keep only :latest tags for deepiri-dev-*

set -e

echo "🧹 Cleaning up duplicate Docker images..."
echo ""

# Ensure Docker is pointing to Minikube
eval $(minikube docker-env)

# Images we want to keep (with :latest tag)
KEEP_IMAGES=(
    "deepiri-dev-cyrex:latest"
    "deepiri-dev-frontend:latest"
    "deepiri-dev-api-gateway:latest"
    "deepiri-dev-auth-service:latest"
    "deepiri-dev-workflow-orchestrator:latest"
    "deepiri-dev-adaptive-experience-engine:latest"
    "deepiri-dev-incentive-engine:latest"
    "deepiri-dev-decision-intelligence:latest"
    "deepiri-dev-external-bridge-service:latest"
    "deepiri-dev-communications-hub:latest"
    "deepiri-dev-realtime-gateway:latest"
)

echo "📋 Images to keep (with :latest tag):"
for img in "${KEEP_IMAGES[@]}"; do
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}$"; then
        echo "  ✅ $img"
    else
        echo "  ⚠️  $img (not found)"
    fi
done

echo ""
echo "🗑️  Deleting old tags (keeping :latest only)..."

DELETED=0
for img_base in "${KEEP_IMAGES[@]}"; do
    img_name="${img_base%:*}"  # Remove :latest
    
    # Get all tags for this image (except :latest)
    OLD_TAGS=$(docker images --format "{{.Repository}}:{{.Tag}}" "$img_name" 2>/dev/null | grep -v ":latest$" | grep -v "^$")
    
    if [ -n "$OLD_TAGS" ]; then
        echo "$OLD_TAGS" | while read -r tag; do
            if docker rmi "$tag" 2>/dev/null; then
                echo "  ✅ Deleted: $tag"
                DELETED=$((DELETED + 1))
            fi
        done
    fi
done

echo ""
echo "🗑️  Deleting old deepiri-* images (without -dev-)..."

# Delete old deepiri-* images (not deepiri-dev-*)
OLD_DEEPIRI=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^deepiri-" | grep -v "deepiri-dev-" | grep -v "deepiri-core-api")

if [ -n "$OLD_DEEPIRI" ]; then
    echo "$OLD_DEEPIRI" | while read -r img; do
        if docker rmi "$img" 2>/dev/null; then
            echo "  ✅ Deleted: $img"
        fi
    done
fi

echo ""
echo "🧹 Cleaning up dangling images..."
docker image prune -f

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Remaining images:"
docker images | grep "deepiri-dev" | grep ":latest"

