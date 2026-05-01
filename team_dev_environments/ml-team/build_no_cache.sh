#!/bin/bash
# ML Team - Build script (No Cache)
# Builds ML team services using docker-compose.dev.yml with service selection (no cache)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Force legacy builder for consistency with the normal team build flow.
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

# ML team services
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb
  mlflow
  # jupyter  # DISABLED: No services depend on Jupyter - it's only for manual research/experimentation
  decision-intelligence synapse
)

echo "🔨 Building ML Team services (No Cache)..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Build services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"
