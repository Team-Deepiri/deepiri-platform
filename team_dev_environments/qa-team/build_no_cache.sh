#!/bin/bash
# QA Team - Build script (No Cache)
# Builds: All backend microservices using docker-compose.dev.yml with service selection (no cache)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder for consistency with the normal team build flow.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

# QA team services (language-intelligence-service excluded - service directory is empty)
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb
  api-gateway auth-service workflow-orchestrator
  incentive-engine decision-intelligence
  communications-hub external-bridge-service
  adaptive-experience-engine realtime-gateway
  language-intelligence-service messaging-service
  synapse frontend-dev adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🔨 Building QA Team services (No Cache)..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo ""
echo "✅ QA Team services built successfully!"
echo ""
echo "Services built:"
for service in "${SERVICES[@]}"; do
  echo "  ✓ $service"
done
