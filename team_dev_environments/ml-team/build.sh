#!/bin/bash
# ML Team - Build script
# Builds ML team services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# ML team services
SERVICES=(
  postgres redis influxdb
  jupyter mlflow
  platform-analytics-service synapse
)

echo "🔨 Building ML Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"
