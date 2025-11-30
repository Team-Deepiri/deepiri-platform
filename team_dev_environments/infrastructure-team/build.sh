#!/bin/bash
# Infrastructure Team - Build script
# Builds: All infrastructure + API Gateway + All Microservices (no frontend)
# Based on SERVICE_TEAM_MAPPING.md: All Infrastructure Services + API Gateway + All Microservices

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Infrastructure Team services..."

# Build all services except frontend-dev
ALL_SERVICES=(
  api-gateway auth-service task-orchestrator engagement-service platform-analytics-service
  notification-service external-bridge-service challenge-service realtime-gateway
  cyrex jupyter mlflow
)

SERVICES_TO_BUILD=()
for service in "${ALL_SERVICES[@]}"; do
  case $service in
    api-gateway)
      if [ -f "platform-services/api-gateway/Dockerfile" ] || [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    auth-service)
      if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    external-bridge-service)
      if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    cyrex|jupyter)
      if [ -f "diri-cyrex/Dockerfile" ] || [ -f "diri-cyrex/Dockerfile.jupyter" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    *)
      # For non-submodule services or services without specific Dockerfiles
      SERVICES_TO_BUILD+=("$service")
      ;;
  esac
done

if [ ${#SERVICES_TO_BUILD[@]} -eq 0 ]; then
  echo "❌ No services to build for Infrastructure Team!"
  exit 1
fi

echo "Building: ${SERVICES_TO_BUILD[*]} (excluding frontend-dev)"

# Build services using team-specific compose file
docker compose -f docker-compose.infrastructure-team.yml build "${SERVICES_TO_BUILD[@]}"

echo "✅ Infrastructure Team services built successfully!"
