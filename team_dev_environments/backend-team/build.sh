#!/bin/bash
# Backend Team - Build script
# Builds: All backend microservices and frontend-dev
# Based on docker-compose.backend-team.yml:
#   - API Gateway, Auth, Task Orchestrator, Engagement, Analytics, 
#     Notification, External Bridge, Challenge, Realtime Gateway, Frontend

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Backend Team services..."
echo "   (Matching docker-compose.backend-team.yml)"

# Build services that exist (skip submodules if not initialized)
# Services in order as they appear in docker-compose.backend-team.yml
SERVICES=()

# Check and add api-gateway
if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
  SERVICES+=("api-gateway")
else
  echo "⚠️  Skipping api-gateway (Dockerfile not found)"
fi

# Check and add auth-service
if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
  SERVICES+=("auth-service")
else
  echo "⚠️  Skipping auth-service (Dockerfile not found)"
fi

# Check and add task-orchestrator
if [ -f "platform-services/backend/deepiri-task-orchestrator/Dockerfile" ]; then
  SERVICES+=("task-orchestrator")
else
  echo "⚠️  Skipping task-orchestrator (Dockerfile not found)"
fi

# Check and add engagement-service
if [ -f "platform-services/backend/deepiri-engagement-service/Dockerfile" ]; then
  SERVICES+=("engagement-service")
else
  echo "⚠️  Skipping engagement-service (Dockerfile not found)"
fi

# Check and add platform-analytics-service
if [ -f "platform-services/backend/deepiri-platform-analytics-service/Dockerfile" ]; then
  SERVICES+=("platform-analytics-service")
else
  echo "⚠️  Skipping platform-analytics-service (Dockerfile not found)"
fi

# Check and add notification-service
if [ -f "platform-services/backend/deepiri-notification-service/Dockerfile" ]; then
  SERVICES+=("notification-service")
else
  echo "⚠️  Skipping notification-service (Dockerfile not found)"
fi

# Check and add external-bridge-service
if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
  SERVICES+=("external-bridge-service")
else
  echo "⚠️  Skipping external-bridge-service (Dockerfile not found)"
fi

# Check and add challenge-service
if [ -f "platform-services/backend/deepiri-challenge-service/Dockerfile" ]; then
  SERVICES+=("challenge-service")
else
  echo "⚠️  Skipping challenge-service (Dockerfile not found)"
fi

# Check and add realtime-gateway
if [ -f "platform-services/backend/deepiri-realtime-gateway/Dockerfile" ]; then
  SERVICES+=("realtime-gateway")
else
  echo "⚠️  Skipping realtime-gateway (Dockerfile not found)"
fi

# Check and add frontend-dev
if [ -f "deepiri-web-frontend/Dockerfile.dev" ]; then
  SERVICES+=("frontend-dev")
else
  echo "⚠️  Skipping frontend-dev (Dockerfile.dev not found)"
fi

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to build!"
  exit 1
fi

echo ""
echo "Building services: ${SERVICES[*]}"
echo ""

# Build services using team-specific compose file
docker compose -f docker-compose.backend-team.yml build "${SERVICES[@]}"

echo ""
echo "✅ Backend Team services built successfully!"
echo ""
echo "Services built:"
for service in "${SERVICES[@]}"; do
  echo "  ✓ $service"
done
