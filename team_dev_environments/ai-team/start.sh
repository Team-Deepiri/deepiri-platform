#!/bin/bash
# AI Team - Start script
# Services: mongodb influxdb redis etcd minio milvus cyrex cyrex-interface jupyter mlflow challenge-service

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting AI Team services..."
echo "Services: mongodb influxdb redis etcd minio milvus cyrex cyrex-interface jupyter mlflow challenge-service"

docker compose -f docker-compose.dev.yml up -d \
  mongodb influxdb redis etcd minio milvus \
  cyrex cyrex-interface jupyter mlflow challenge-service

echo "✅ AI Team services started!"
echo ""
echo "📊 MLflow: http://localhost:5500"
echo "📓 Jupyter: http://localhost:8888"
echo "🤖 Cyrex: http://localhost:8000"
echo "🖥️  Cyrex Interface: http://localhost:5175"
echo "🏆 Challenge Service: http://localhost:5007"

