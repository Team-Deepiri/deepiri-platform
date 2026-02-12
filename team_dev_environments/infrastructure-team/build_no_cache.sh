#!/bin/bash
# Infrastructure Team - Build script (No Cache)
# Builds infrastructure team services using docker-compose.dev.yml with service selection (no cache)
#
# Note: Currently matches backend team setup. Infrastructure team will work on cloud
# infrastructure and data infrastructure services in the future (e.g., cloud storage,
# data pipelines, monitoring infrastructure, etc.)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Infrastructure team services (currently same as backend team)
# Future: Will include cloud infrastructure and data infrastructure services
SERVICES=(
  postgres redis influxdb
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  language-intelligence-service messaging-service
  synapse frontend-dev adminer
)

echo "🔨 Building Infrastructure Team services (No Cache)..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo ""
echo "✅ Infrastructure Team services built successfully!"
echo ""
echo "Services built:"
for service in "${SERVICES[@]}"; do
  echo "  ✓ $service"
done

