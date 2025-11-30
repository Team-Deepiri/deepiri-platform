#!/bin/bash
# Frontend Team - Build script
# Builds: Frontend, Auth Service, API Gateway, Realtime Gateway
# Frontend connects to: 
#   - API Gateway (port 5100) for REST API calls
#   - Realtime Gateway (port 5008) for WebSocket connections
#   - Auth Service (via API Gateway for authentication)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Frontend Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in frontend-dev auth-service api-gateway realtime-gateway; do
  case $service in
    frontend-dev)
      if [ -f "deepiri-web-frontend/Dockerfile.dev" ] || [ -f "deepiri-web-frontend/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    api-gateway)
      if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
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
docker compose -f docker-compose.frontend-team.yml build "${SERVICES[@]}"

echo "✅ Frontend Team services built successfully!"
