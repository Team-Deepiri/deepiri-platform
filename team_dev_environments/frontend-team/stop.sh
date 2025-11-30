#!/bin/bash
# Frontend Team - Stop script
# Stops and removes all containers started by frontend-team/run.py

set -e

echo "🛑 Stopping Frontend Team services..."

# List of containers started by frontend-team/run.py
CONTAINERS=(
    "deepiri-postgres-frontend"
    "deepiri-pgadmin-frontend"
    "deepiri-adminer-frontend"
    "deepiri-redis-frontend"
    "deepiri-frontend-frontend"
    "deepiri-api-gateway-frontend"
    "deepiri-realtime-gateway-frontend"
)

# Stop and remove containers
for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "Stopping ${container}..."
        docker stop "${container}" 2>/dev/null || true
        echo "Removing ${container}..."
        docker rm "${container}" 2>/dev/null || true
    else
        echo "⚠️  Container ${container} not found, skipping..."
    fi
done

echo "✅ Frontend Team services stopped and removed!"
