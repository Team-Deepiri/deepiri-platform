#!/bin/bash
# AI Team - Build script
# Builds AI/ML services using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# AI team services
SERVICES=(
  redis influxdb etcd minio milvus
  cyrex cyrex-interface jupyter mlflow
  challenge-service external-bridge-service
  ollama
)

echo "🔨 Building AI Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Pull Ollama image (it's a pre-built image, not built from source)
echo "📥 Pulling Ollama Docker image..."
docker pull ollama/ollama:latest || echo "⚠️  Failed to pull Ollama image, will try again during start"
echo ""

# Build services using docker-compose.dev.yml
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ AI Team services built successfully!"
