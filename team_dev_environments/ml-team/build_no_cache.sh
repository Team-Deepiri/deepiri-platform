#!/bin/bash
# ML Team - Build script (No Cache)
# Builds ML team services using docker-compose.dev.yml with service selection (no cache)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# ML team services
SERVICES=(
  postgres redis influxdb
  mlflow
  # jupyter  # DISABLED: No services depend on Jupyter - it's only for manual research/experimentation
  platform-analytics-service synapse
)

echo "🔨 Building ML Team services (No Cache)..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"

