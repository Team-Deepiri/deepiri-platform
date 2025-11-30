#!/bin/bash
# Backend Team - Build script
# Builds: All backend microservices (no frontend)
# Based on SERVICE_TEAM_MAPPING.md: API Gateway, Auth, Task Orchestrator, 
#   Engagement, Analytics, Notification, External Bridge, Challenge, Realtime Gateway

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Backend Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway; do
  case $service in
    api-gateway)
      if [ -f "platform-services/api-gateway/Dockerfile" ] || [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    auth-service)
      if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    external-bridge-service)
      if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
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
docker compose -f docker-compose.backend-team.yml build "${SERVICES[@]}"

echo "✅ Backend Team services built successfully!"
