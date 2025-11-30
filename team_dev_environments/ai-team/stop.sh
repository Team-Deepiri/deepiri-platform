#!/bin/bash
# AI Team - Stop script
# Stops and removes all containers started by ai-team/run.py

set -e

echo "🛑 Stopping AI Team services..."

# List of containers started by ai-team/run.py
CONTAINERS=(
    "deepiri-postgres-ai"
    "deepiri-pgadmin-ai"
    "deepiri-adminer-ai"
    "deepiri-redis-ai"
    "deepiri-influxdb-ai"
    "deepiri-etcd-ai"
    "deepiri-minio-ai"
    "deepiri-milvus-ai"
    "deepiri-cyrex-ai"
    "deepiri-mlflow-ai"
    "deepiri-jupyter-ai"
    "deepiri-challenge-service-ai"
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

echo "✅ AI Team services stopped and removed!"
