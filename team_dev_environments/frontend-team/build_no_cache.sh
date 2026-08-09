#!/bin/bash
# Frontend Team - Build script (No Cache)
# Builds frontend team services using docker-compose.dev.yml with service selection (no cache)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder for consistency with the normal team build flow.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

# Frontend team services - only what frontend engineers need
SERVICES=(
  frontend-dev
  api-gateway
  auth-service
  messaging-service
  realtime-gateway
  postgres-auth
  postgres-core
  postgres-intelligence
)

echo "🔨 Building Frontend Team services (No Cache)..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo "✅ Frontend Team services built successfully!"
echo "   Built services: ${SERVICES[*]}"
