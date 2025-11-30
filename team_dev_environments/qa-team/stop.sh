#!/bin/bash
# QA Team - Stop script
# Stops and removes all containers started by qa-team/run.py

set -e

echo "🛑 Stopping QA Team services (Full Stack)..."

# List of containers started by qa-team/run.py (ALL services)
CONTAINERS=(
    "deepiri-postgres-qa"
    "deepiri-pgadmin-qa"
    "deepiri-adminer-qa"
    "deepiri-redis-qa"
    "deepiri-influxdb-qa"
    "deepiri-api-gateway-qa"
    "deepiri-auth-service-qa"
    "deepiri-task-orchestrator-qa"
    "deepiri-engagement-service-qa"
    "deepiri-platform-analytics-service-qa"
    "deepiri-notification-service-qa"
    "deepiri-external-bridge-service-qa"
    "deepiri-challenge-service-qa"
    "deepiri-realtime-gateway-qa"
    "deepiri-frontend-qa"
    "deepiri-cyrex-qa"
    "deepiri-mlflow-qa"
    "deepiri-jupyter-qa"
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

echo "✅ QA Team services stopped and removed!"
