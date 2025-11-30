#!/bin/bash
# Platform Engineers - Stop script
# Stops and removes all containers started by platform-engineers/run.py

set -e

echo "🛑 Stopping Platform Engineers services (Full Stack)..."

# List of containers started by platform-engineers/run.py (ALL services)
CONTAINERS=(
    "deepiri-postgres-platform-engineers"
    "deepiri-pgadmin-platform-engineers"
    "deepiri-adminer-platform-engineers"
    "deepiri-redis-platform-engineers"
    "deepiri-influxdb-platform-engineers"
    "deepiri-api-gateway-platform-engineers"
    "deepiri-auth-service-platform-engineers"
    "deepiri-task-orchestrator-platform-engineers"
    "deepiri-engagement-service-platform-engineers"
    "deepiri-platform-analytics-service-platform-engineers"
    "deepiri-notification-service-platform-engineers"
    "deepiri-external-bridge-service-platform-engineers"
    "deepiri-challenge-service-platform-engineers"
    "deepiri-realtime-gateway-platform-engineers"
    "deepiri-frontend-platform-engineers"
    "deepiri-cyrex-platform-engineers"
    "deepiri-mlflow-platform-engineers"
    "deepiri-jupyter-platform-engineers"
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

echo "✅ Platform Engineers services stopped and removed!"
