#!/bin/bash
# AI Team - Build script
# Builds: Cyrex, Jupyter, MLflow, Challenge Service, Ollama
# Based on SERVICE_TEAM_MAPPING.md: Cyrex AI Service, Jupyter, MLflow, Challenge Service
# Ollama is included as it's needed for local LLM functionality

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building AI Team services..."

# Pull Ollama image (it's a pre-built image, not built from source)
echo "📥 Pulling Ollama Docker image..."
docker pull ollama/ollama:latest || echo "⚠️  Failed to pull Ollama image, will try again during start"

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in cyrex engagement-service external-bridge-service jupyter mlflow challenge-service; do
  case $service in
    cyrex)
      if [ -f "diri-cyrex/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    jupyter)
      if [ -f "diri-cyrex/Dockerfile.jupyter" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (Dockerfile.jupyter not found)"
      fi
      ;;
    mlflow)
      # MLflow uses pre-built image, but we can still include it
      SERVICES+=("$service")
      ;;
    *)
      SERVICES+=("$service")
      ;;
  esac
done

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to build!"
  exit 1
fi

echo "Building: ${SERVICES[*]}"

# Build services using team-specific compose file
docker compose -f docker-compose.ai-team.yml build "${SERVICES[@]}"

echo "✅ AI Team services built successfully!"
