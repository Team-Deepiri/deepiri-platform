#!/bin/bash
# ML Team - Start script
# Services: mongodb influxdb redis cyrex jupyter mlflow platform-analytics-service

set -e

cd "$(dirname "$0")/.." || exit 1

echo "🚀 Starting ML Team services..."
echo "Services: mongodb influxdb redis cyrex jupyter mlflow platform-analytics-service"

# Build services that need building
docker compose -f docker-compose.dev.yml build \
  cyrex jupyter platform-analytics-service

# Start all required services
docker compose -f docker-compose.dev.yml up -d \
  mongodb influxdb redis \
  cyrex jupyter mlflow platform-analytics-service

echo "✅ ML Team services started!"
echo "📊 MLflow: http://localhost:5500"
echo "📓 Jupyter: http://localhost:8888"
echo "🤖 Cyrex: http://localhost:8000"
echo "📈 Analytics: http://localhost:5004"

