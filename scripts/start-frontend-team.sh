#!/bin/bash
# Frontend Team - Start script
# Services: frontend + all backend services for API calls

set -e

cd "$(dirname "$0")/.." || exit 1

echo "🚀 Starting Frontend Team services..."
echo "Services: mongodb redis influxdb + all backend services + frontend"

# Build frontend and all backend services
docker compose -f docker-compose.dev.yml build \
  frontend-dev api-gateway auth-service task-orchestrator engagement-service \
  platform-analytics-service notification-service external-bridge-service \
  challenge-service realtime-gateway

# Start infrastructure + all backend + frontend
docker compose -f docker-compose.dev.yml up -d \
  mongodb redis influxdb \
  api-gateway auth-service task-orchestrator \
  engagement-service platform-analytics-service \
  notification-service external-bridge-service \
  challenge-service realtime-gateway frontend-dev

echo "✅ Frontend Team services started!"
echo "🎨 Frontend: http://localhost:5173"
echo "🌐 API Gateway: http://localhost:5000"
echo "⚡ Realtime Gateway: http://localhost:5008"

