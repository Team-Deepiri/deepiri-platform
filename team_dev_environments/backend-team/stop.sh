#!/bin/bash
# Backend Team - Stop script
# Stops and removes all containers started by backend-team/run.py

set -e

echo "🛑 Stopping Backend Team services..."

# List of containers started by backend-team/run.py
CONTAINERS=(
    "deepiri-postgres-backend"
    "deepiri-pgadmin-backend"
    "deepiri-adminer-backend"
    "deepiri-redis-backend"
    "deepiri-influxdb-backend"
    "deepiri-api-gateway-backend"
    "deepiri-auth-service-backend"
    "deepiri-task-orchestrator-backend"
    "deepiri-engagement-service-backend"
    "deepiri-platform-analytics-service-backend"
    "deepiri-notification-service-backend"
    "deepiri-external-bridge-service-backend"
    "deepiri-challenge-service-backend"
    "deepiri-realtime-gateway-backend"
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

echo "✅ Backend Team services stopped and removed!"
