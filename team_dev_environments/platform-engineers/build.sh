#!/bin/bash
# Platform Engineers - Build script
# Builds ALL services using docker-compose.dev.yml

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Platform Engineers services (All Services)..."
echo "   (Using docker-compose.dev.yml)"
echo ""

# Build all services using docker-compose.dev.yml
docker compose -f docker-compose.dev.yml build

echo "✅ Platform Engineers services built successfully!"
