#!/bin/bash
# AI Team - Start script
# Services: mongodb influxdb redis cyrex jupyter mlflow challenge-service milvus etcd minio

set -e

cd "$(dirname "$0")/.." || exit 1

echo "🚀 Starting AI Team services..."
echo "Services: mongodb influxdb redis cyrex jupyter mlflow challenge-service milvus etcd minio"

# Build services that need building
docker compose -f docker-compose.dev.yml build \
  cyrex jupyter challenge-service

# Start all required services
docker compose -f docker-compose.dev.yml up -d \
  mongodb influxdb redis etcd minio milvus \
  cyrex jupyter mlflow challenge-service

echo "✅ AI Team services started!"
echo "📊 MLflow: http://localhost:5500"
echo "📓 Jupyter: http://localhost:8888"
echo "🤖 Cyrex: http://localhost:8000"

