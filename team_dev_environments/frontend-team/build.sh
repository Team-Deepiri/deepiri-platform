#!/bin/bash
# Frontend Team - Build script
# Builds: frontend-dev + all backend services

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building Frontend Team services..."
echo "Building: frontend-dev api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway"

docker compose -f docker-compose.dev.yml build \
  frontend-dev api-gateway auth-service task-orchestrator engagement-service \
  platform-analytics-service notification-service external-bridge-service \
  challenge-service realtime-gateway

echo "✅ Frontend Team services built successfully!"

