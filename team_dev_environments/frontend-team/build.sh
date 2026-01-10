#!/bin/bash
# Frontend Team - Build script
# Builds frontend team services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Frontend team services - only what frontend engineers need
SERVICES=(
  frontend-dev
  api-gateway
  auth-service
  notification-service
)

echo "🔨 Building Frontend Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml with --no-deps to avoid building dependencies
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ Frontend Team services built successfully!"
echo "   Built services: ${SERVICES[*]}"
