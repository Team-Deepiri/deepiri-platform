#!/bin/bash
# Platform Engineers - Build script (No Cache)
# Builds ALL services using docker-compose.dev.yml (no cache)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder for consistency with the normal team build flow.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

echo "🔨 Building Platform Engineers services (All Services, No Cache)..."
echo "   (Using docker-compose.dev.yml)"
echo ""

# Build all services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache

echo "✅ Platform Engineers services built successfully!"
