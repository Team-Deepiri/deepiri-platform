#!/bin/bash
# Frontend Team - Stop script
# Stops and removes all containers for frontend team services
# This includes ONLY the services needed by the frontend (no core-api, external-bridge-service, cyrex, etc.)

set -e

echo "🛑 Stopping Frontend Team services..."

# List of containers for frontend team services (ONLY services needed by frontend)
# Infrastructure services
CONTAINERS=(
    "deepiri-postgres-frontend"
    "deepiri-pgadmin-frontend"
    "deepiri-adminer-frontend"
    "deepiri-redis-frontend"
    "deepiri-influxdb-frontend"
)

# Application services (frontend + api-gateway + all api-gateway dependencies)
CONTAINERS+=(
    "deepiri-frontend-frontend"
    "deepiri-api-gateway-frontend"
    "deepiri-realtime-gateway-frontend"
    "deepiri-auth-service-frontend"
    "deepiri-task-orchestrator-frontend"
    "deepiri-engagement-service-frontend"
    "deepiri-platform-analytics-service-frontend"
    "deepiri-notification-service-frontend"
    "deepiri-challenge-service-frontend"
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
