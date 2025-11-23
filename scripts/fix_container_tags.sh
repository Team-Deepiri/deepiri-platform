#!/bin/bash
# Fixed command to tag all Skaffold images with :latest

# Make sure Docker is pointing to Minikube
eval $(minikube docker-env)

# Tag all images with :latest
for img in deepiri-dev-cyrex deepiri-dev-frontend deepiri-dev-api-gateway deepiri-dev-auth-service deepiri-dev-task-orchestrator deepiri-dev-challenge-service deepiri-dev-engagement-service deepiri-dev-platform-analytics-service deepiri-dev-external-bridge-service deepiri-dev-notification-service deepiri-dev-realtime-gateway; do
    # Find the source image (any tag except :latest)
    SOURCE=$(docker images --format "{{.Repository}}:{{.Tag}}" "$img" 2>/dev/null | grep -v ":latest$" | head -1)
    
    # If that didn't work, try alternative method
    if [ -z "$SOURCE" ]; then
        SOURCE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${img}:" | grep -v ":latest$" | head -1)
    fi
    
    # Tag if source found
    if [ -n "$SOURCE" ]; then
        docker tag "$SOURCE" "${img}:latest" 2>/dev/null && echo "✅ Tagged: $SOURCE -> ${img}:latest" || echo "⚠️  Failed: $img"
    else
        # Check if :latest already exists
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}:latest$"; then
            echo "✅ Already tagged: ${img}:latest"
        else
            echo "⚠️  Not found: $img"
        fi
    fi
done

echo ""
echo "✅ Done! Now run: docker compose -f docker-compose.dev.yml up -d"

