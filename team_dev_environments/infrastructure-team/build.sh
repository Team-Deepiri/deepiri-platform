#!/bin/bash
# Infrastructure Team - Build script
# Builds infrastructure team services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Infrastructure team services (all except frontend-dev)
SERVICES=(
  postgres pgadmin adminer redis influxdb etcd minio
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway synapse
)

echo "🔨 Building Infrastructure Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ Infrastructure Team services built successfully!"
