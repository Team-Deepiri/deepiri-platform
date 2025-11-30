#!/bin/bash
# QA Team - Build script
# Builds: ALL SERVICES (complete stack for testing)
# Based on SERVICE_TEAM_MAPPING.md: All services for end-to-end testing

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building QA Team services (All Services)..."

# Build all services using team-specific compose file
docker compose -f docker-compose.qa-team.yml build

echo "✅ QA Team services built successfully!"
