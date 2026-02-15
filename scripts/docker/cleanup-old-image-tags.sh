#!/bin/bash

# Cleanup old image tags - keeps only :latest, removes duplicates
# Run this AFTER skaffold build to free up storage

set -e

# Point Docker to Minikube
eval $(minikube docker-env)

echo "🧹 Cleaning up old image tags (keeping only :latest)..."
echo ""

# List of all deepiri-dev-* images
IMAGES=(
    "deepiri-dev-cyrex"
    "deepiri-dev-jupyter"
    "deepiri-dev-frontend"
    "deepiri-dev-api-gateway"
    "deepiri-dev-auth-service"
    "deepiri-dev-task-orchestrator"
    "deepiri-dev-challenge-service"
    "deepiri-dev-engagement-service"
    "deepiri-dev-platform-analytics-service"
    "deepiri-dev-external-bridge-service"
    "deepiri-dev-notification-service"
    "deepiri-dev-realtime-gateway"
)

DELETED=0
for img in "${IMAGES[@]}"; do
    # Get all tags for this image (excluding :latest)
    OLD_TAGS=$(docker images --format "{{.Repository}}:{{.Tag}}" "$img" 2>/dev/null | grep -v ":latest$" || true)
    
    if [ -n "$OLD_TAGS" ]; then
        echo "🗑️  Removing old tags for $img:"
        while IFS= read -r tag; do
            if [ -n "$tag" ]; then
                docker rmi "$tag" 2>/dev/null && echo "   ✅ Deleted: $tag" && DELETED=$((DELETED + 1)) || echo "   ⚠️  Could not delete: $tag (may be in use)"
            fi
        done <<< "$OLD_TAGS"
    else
        echo "✅ $img:latest (no duplicates)"
    fi
done

# Also clean up any untagged/dangling images
echo ""
echo "🧹 Removing dangling images..."
DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
if [ "$DANGLING" -gt 0 ]; then
    docker image prune -f 2>/dev/null || true
    echo "✅ Removed dangling images"
else
    echo "✅ No dangling images"
fi

echo ""
echo "✅ Cleanup complete! Deleted $DELETED old image tags"
echo "   All images now use :latest tag only (saves storage!)"

