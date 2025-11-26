#!/bin/bash
# Backend Team - Build script
# Requirements: core-api, web-frontend, api-gateway, auth + all their dependencies
# Dependencies: api-gateway needs (auth-service, task-orchestrator, engagement-service, 
#   platform-analytics-service, notification-service, challenge-service, realtime-gateway, cyrex)
#   cyrex needs (influxdb, milvus), milvus needs (etcd, minio)
#   engagement-service needs (mongodb, redis)
#   challenge-service needs (mongodb, cyrex)
#   auth-service needs (mongodb, influxdb)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building Backend Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in frontend-dev api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service external-bridge-service challenge-service realtime-gateway cyrex; do
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
    cyrex)
      if [ -f "diri-cyrex/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    frontend-dev)
      if [ -f "deepiri-web-frontend/Dockerfile.dev" ]; then
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

# Note: deepiri-core-api is not in docker-compose.dev.yml
# If you need it, add it to the compose file or use a different compose file
if [ -f "deepiri-core-api/Dockerfile" ]; then
  echo "⚠️  Note: deepiri-core-api found but not in docker-compose.dev.yml"
  echo "   You may need to add it to the compose file or use a different compose file"
fi

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to build!"
  exit 1
fi

echo "Building: ${SERVICES[*]} (and their dependencies)"

# Build services with their dependencies
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ Backend Team services built successfully!"

