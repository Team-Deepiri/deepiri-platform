#!/bin/bash
# AI Team - Build script (No Cache)
# Builds AI/ML services using docker-compose.dev.yml with service selection (no cache)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# AI team services
SERVICES=(
  postgres redis influxdb etcd minio milvus
  cyrex cyrex-interface mlflow
  # jupyter  # DISABLED: No services depend on Jupyter - it's only for manual research/experimentation
  challenge-service api-gateway messaging-service realtime-gateway
  ollama synapse
)

echo "🔨 Building AI Team services (No Cache)..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Pull Ollama image (it's a pre-built image, not built from source)
echo "📥 Pulling Ollama Docker image..."
docker pull ollama/ollama:latest || echo "⚠️  Failed to pull Ollama image, will try again during start"
echo ""

# Build services using docker-compose.dev.yml with --no-cache
docker compose -f docker-compose.dev.yml build --no-cache "${SERVICES[@]}"

echo "✅ AI Team services built successfully!"

