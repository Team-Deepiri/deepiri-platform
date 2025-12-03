#!/bin/bash
# Build script for Backend + Frontend teams
# Builds:
#   Backend: API Gateway, Auth, Task Orchestrator, Engagement, Analytics, Notification,
#            External Bridge, Challenge, Realtime Gateway
#   Frontend: web-app, admin-portal, partner-portal

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Backend + Frontend services..."

BACKEND_SERVICES=()
FRONTEND_SERVICES=()

##
## BACKEND SERVICES
##
for service in api-gateway auth-service task-orchestrator engagement-service \
               platform-analytics-service notification-service external-bridge-service \
               challenge-service realtime-gateway frontend-dev; do
  case $service in
    api-gateway)
      if [ -f "platform-services/api-gateway/Dockerfile" ] || \
         [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        BACKEND_SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    auth-service)
      if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
        BACKEND_SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    external-bridge-service)
      if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
        BACKEND_SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    frontend-dev)
      if [ -f "deepiri-web-frontend/Dockerfile.dev" ] || [ -f "deepiri-web-frontend/Dockerfile" ]; then
        BACKEND_SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    *)
      BACKEND_SERVICES+=("$service")
      ;;
    
  esac
done

##
## FRONTEND SERVICES
##
for fservice in web-app admin-portal partner-portal; do
  case $fservice in
    web-app)
      if [ -f "platform-frontend/web-app/Dockerfile" ]; then
        FRONTEND_SERVICES+=("$fservice")
      else
        echo "⚠️  Skipping $fservice (not found)"
      fi
      ;;
    admin-portal)
      if [ -f "platform-frontend/admin-portal/Dockerfile" ]; then
        FRONTEND_SERVICES+=("$fservice")
      else
        echo "⚠️  Skipping $fservice (not found)"
      fi
      ;;
    partner-portal)
      if [ -f "platform-frontend/partner-portal/Dockerfile" ]; then
        FRONTEND_SERVICES+=("$fservice")
      else
        echo "⚠️  Skipping $fservice (not found)"
      fi
      ;;
  esac
done

ALL_SERVICES=("${BACKEND_SERVICES[@]}" "${FRONTEND_SERVICES[@]}")

if [ ${#ALL_SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to build!"
  exit 1
fi

echo "Building: ${ALL_SERVICES[*]}"

# Use a combined backend + frontend compose file
docker compose -f docker-compose.backend-team.yml \
               -f docker-compose.frontend-team.yml \
               build "${ALL_SERVICES[@]}"

echo "✅ Backend + Frontend services built successfully!"
