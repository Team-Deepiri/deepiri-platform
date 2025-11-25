#!/bin/bash
# Backend Team - Start script
# Services: mongodb redis influxdb + all backend microservices

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Backend Team services..."
echo "Services: mongodb redis influxdb api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway"

docker compose -f docker-compose.dev.yml up -d \
  mongodb redis influxdb \
  api-gateway auth-service task-orchestrator \
  engagement-service platform-analytics-service \
  notification-service external-bridge-service \
  challenge-service realtime-gateway

echo "✅ Backend Team services started!"
echo ""
echo "🌐 API Gateway: http://localhost:5000"
echo "🔐 Auth Service: http://localhost:5001"
echo "📋 Task Orchestrator: http://localhost:5002"
echo "🎮 Engagement Service: http://localhost:5003"
echo "📈 Analytics Service: http://localhost:5004"
echo "🔔 Notification Service: http://localhost:5005"
echo "🌉 External Bridge: http://localhost:5006"
echo "🏆 Challenge Service: http://localhost:5007"
echo "⚡ Realtime Gateway: http://localhost:5008"

