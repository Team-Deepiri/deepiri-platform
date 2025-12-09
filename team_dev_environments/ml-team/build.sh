#!/bin/bash
# ML Team - Build script
# Builds: Cyrex, Jupyter, MLflow, Platform Analytics Service
# Based on SERVICE_TEAM_MAPPING.md: Cyrex AI Service, Jupyter, MLflow, Analytics Service

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building ML Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in cyrex jupyter mlflow platform-analytics-service; do
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
docker compose -f docker-compose.ml-team.yml build "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"
