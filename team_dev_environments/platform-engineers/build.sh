#!/bin/bash
# Platform Engineers - Build script
# Builds: ALL SERVICES (complete stack for platform development)
# Based on SERVICE_TEAM_MAPPING.md: All services for platform tooling development

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Platform Engineers services (All Services)..."

# Build all services using team-specific compose file
docker compose -f docker-compose.platform-engineers.yml build

echo "✅ Platform Engineers services built successfully!"
