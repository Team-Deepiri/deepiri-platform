#!/bin/bash

# Point Docker to Minikube
eval $(minikube docker-env)

echo "🧹 Deleting all deepiri images (all names and tags)..."

# Delete ALL images matching deepiri-* pattern (catches both deepiri-* and deepiri-dev-*)
# This removes images with any tag (SHA256, latest, dirty, etc.)
echo "  Deleting by name pattern..."
docker images --format "{{.Repository}}:{{.Tag}}" | grep "^deepiri-" | xargs -r docker rmi -f 2>/dev/null || true

# Delete by image ID to catch any remaining (including untagged)
echo "  Deleting by image ID..."
docker images --format "{{.ID}} {{.Repository}}" | grep "deepiri" | awk '{print $1}' | sort -u | xargs -r docker rmi -f 2>/dev/null || true

# Also delete images with different names that Skaffold might find
echo "  Deleting alternative named images..."
for img in deepiri-api-gateway deepiri-auth-service deepiri-task-orchestrator \
           deepiri-challenge-service deepiri-engagement-service \
           deepiri-platform-analytics-service deepiri-external-bridge-service \
           deepiri-notification-service deepiri-realtime-gateway \
           deepiri-cyrex deepiri-frontend deepiri-jupyter \
           deepiri-core-api; do
    docker images "$img" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
done

# Remove dangling images (untagged images that Skaffold might find)
echo "  Removing dangling images..."
docker image prune -af --filter "dangling=true" 2>/dev/null || true

# Clear Docker build cache (important - Skaffold uses this)
echo "  Clearing Docker build cache..."
docker builder prune -af 2>/dev/null || true

echo "✅ All deepiri images and build cache deleted"
echo ""
echo "⚠️  IMPORTANT: Skaffold uses content-based hashing and may still find cached images."
echo "   To force a complete rebuild, use:"
echo "   ./scripts/force-rebuild-all.sh"
echo ""
echo "   OR use Docker directly:"
echo "   skaffold build -f skaffold-local.yaml -p dev-compose --cache-artifacts=false"

