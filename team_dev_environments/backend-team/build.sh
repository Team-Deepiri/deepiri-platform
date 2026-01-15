#!/bin/bash
# Backend Team - Build script
# Builds: All backend microservices using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Backend team services
SERVICES=(
  postgres redis influxdb
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  language-intelligence-service
  synapse frontend-dev adminer
)

echo "🔨 Building Backend Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo ""
echo "✅ Backend Team services built successfully!"
echo ""
echo "Services built:"
for service in "${SERVICES[@]}"; do
  echo "  ✓ $service"
done
