#!/bin/bash
# AI Team - Build script
# Requirements: cyrex, api-gateway, engagement-service, challenge-service, external-bridge-service + their dependencies
# Dependencies: cyrex needs (influxdb, milvus), milvus needs (etcd, minio)
#   api-gateway needs (auth-service, task-orchestrator, engagement-service, platform-analytics-service, 
#     notification-service, challenge-service, realtime-gateway, cyrex)
#   engagement-service needs (mongodb, redis)
#   challenge-service needs (mongodb, cyrex)
#   external-bridge-service needs (mongodb)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building AI Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in cyrex api-gateway engagement-service challenge-service external-bridge-service; do
  case $service in
    api-gateway)
      if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
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
    *)
      SERVICES+=("$service")
      ;;
  esac
done

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to build!"
  exit 1
fi

echo "Building: ${SERVICES[*]} (and their dependencies)"

# Build services with their dependencies
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ AI Team services built successfully!"

