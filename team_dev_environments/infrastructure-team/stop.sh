#!/bin/bash
# Infrastructure Team - Stop script
# Stops and removes all containers started by infrastructure-team/run.py

set -e

echo "🛑 Stopping Infrastructure Team services..."

# List of containers started by infrastructure-team/run.py
CONTAINERS=(
    "deepiri-postgres-infrastructure"
    "deepiri-pgadmin-infrastructure"
    "deepiri-adminer-infrastructure"
    "deepiri-redis-infrastructure"
    "deepiri-influxdb-infrastructure"
    "deepiri-api-gateway-infrastructure"
    "deepiri-auth-service-infrastructure"
    "deepiri-task-orchestrator-infrastructure"
    "deepiri-engagement-service-infrastructure"
    "deepiri-platform-analytics-service-infrastructure"
    "deepiri-notification-service-infrastructure"
    "deepiri-external-bridge-service-infrastructure"
    "deepiri-challenge-service-infrastructure"
    "deepiri-realtime-gateway-infrastructure"
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

echo "✅ Infrastructure Team services stopped and removed!"
