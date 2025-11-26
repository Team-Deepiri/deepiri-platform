#!/bin/bash
# Backend Team - Build script
# Builds: All backend microservices

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building Backend Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway; do
  case $service in
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

docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ Backend Team services built successfully!"

