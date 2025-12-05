#!/bin/bash
# Frontend Team - Build script
# Builds ONLY the services needed by the frontend:
#   - frontend-dev: The React frontend application
#   - api-gateway: Routes REST API calls from frontend
#   - realtime-gateway: WebSocket for real-time features
#   - auth-service: Authentication (dependency of api-gateway)
#   - task-orchestrator: Task management (dependency of api-gateway)
#   - engagement-service: Engagement features (dependency of api-gateway)
#   - platform-analytics-service: Analytics (dependency of api-gateway)
#   - notification-service: Notifications (dependency of api-gateway)
#   - challenge-service: Challenges (dependency of api-gateway)
#
# Note: This script ONLY builds these specific services and their dependencies.
# It does NOT build:
#   - external-bridge-service (only needed for integrations)
#   - core-api / deepiri-core-api (deprecated legacy monolith, replaced by microservices)
#   - cyrex, jupyter, mlflow (AI/ML services, not needed by frontend)
#   - Any other services not explicitly listed above

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Frontend Team services (ONLY services needed by frontend)..."

# Define the exact list of services needed by the frontend
# These are: frontend itself + api-gateway + realtime-gateway + all api-gateway dependencies
FRONTEND_SERVICES=(
  frontend-dev
  api-gateway
  realtime-gateway
  auth-service
  task-orchestrator
  engagement-service
  platform-analytics-service
  notification-service
  challenge-service
)

# Build services that exist (skip submodules if not initialized)
SERVICES_TO_BUILD=()
for service in "${FRONTEND_SERVICES[@]}"; do
  case $service in
    frontend-dev)
      if [ -f "deepiri-web-frontend/Dockerfile.dev" ] || [ -f "deepiri-web-frontend/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    api-gateway)
      if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    auth-service|task-orchestrator|engagement-service|platform-analytics-service|notification-service|challenge-service)
      if [ -f "platform-services/backend/deepiri-${service}/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    realtime-gateway)
      if [ -f "platform-services/backend/deepiri-realtime-gateway/Dockerfile" ]; then
        SERVICES_TO_BUILD+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    *)
      echo "⚠️  Unknown service: $service"
      ;;
  esac
done

if [ ${#SERVICES_TO_BUILD[@]} -eq 0 ]; then
  echo "❌ No services to build!"
  exit 1
fi

echo "Building ONLY these frontend-required services: ${SERVICES_TO_BUILD[*]}"

# Verify all services exist in the compose file before building
# This prevents errors when trying to build services that don't exist
AVAILABLE_SERVICES=$(docker compose -f docker-compose.frontend-team.yml config --services 2>/dev/null || echo "")
VALID_SERVICES=()
for service in "${SERVICES_TO_BUILD[@]}"; do
  if echo "$AVAILABLE_SERVICES" | grep -q "^${service}$"; then
    VALID_SERVICES+=("$service")
  else
    echo "⚠️  Skipping $service (not found in docker-compose.frontend-team.yml)"
  fi
done

if [ ${#VALID_SERVICES[@]} -eq 0 ]; then
  echo "❌ No valid services to build!"
  exit 1
fi

# Build ONLY the services we explicitly listed
# Using --no-deps would skip dependencies, but we want to build dependencies that are in our list
# We explicitly list all needed services above, so this will only build what we need
docker compose -f docker-compose.frontend-team.yml build "${VALID_SERVICES[@]}"

echo "✅ Frontend Team services built successfully!"
echo "   Built services: ${VALID_SERVICES[*]}"
