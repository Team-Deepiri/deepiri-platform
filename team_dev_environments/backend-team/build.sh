#!/bin/bash
# Backend Team - Build script
# Builds: All backend microservices

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building Backend Team services..."
echo "Building: api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway"

docker compose -f docker-compose.dev.yml build \
  api-gateway auth-service task-orchestrator engagement-service \
  platform-analytics-service notification-service external-bridge-service \
  challenge-service realtime-gateway

echo "✅ Backend Team services built successfully!"

