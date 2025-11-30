#!/bin/bash
# ML Team - Stop script
# Stops and removes all containers started by ml-team/run.py

set -e

echo "🛑 Stopping ML Team services..."

# List of containers started by ml-team/run.py
CONTAINERS=(
    "deepiri-postgres-ml"
    "deepiri-pgadmin-ml"
    "deepiri-adminer-ml"
    "deepiri-redis-ml"
    "deepiri-influxdb-ml"
    "deepiri-cyrex-ml"
    "deepiri-mlflow-ml"
    "deepiri-jupyter-ml"
    "deepiri-platform-analytics-service-ml"
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

echo "✅ ML Team services stopped and removed!"
