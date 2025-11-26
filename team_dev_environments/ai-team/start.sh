#!/bin/bash
# AI Team - Start script
# Requirements: cyrex, api-gateway, engagement-service, challenge-service, external-bridge-service + their dependencies
# Dependencies will be started automatically by docker compose

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting AI Team services..."

# Start services that exist (skip submodules if not initialized)
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
  echo "❌ No services to start!"
  exit 1
fi

echo "Starting: ${SERVICES[*]} (and their dependencies)"

# Use --no-build to prevent automatic building (images should already be built)
# Dependencies (mongodb, redis, influxdb, etcd, minio, milvus, auth-service, task-orchestrator,
# platform-analytics-service, notification-service, realtime-gateway) will be started automatically
docker compose -f docker-compose.dev.yml up -d --no-build "${SERVICES[@]}"

echo "✅ AI Team services started!"
echo ""
echo "🤖 Cyrex: http://localhost:8000"
echo "🌐 API Gateway: http://localhost:5000"
echo "🎮 Engagement Service: http://localhost:5003"
echo "🏆 Challenge Service: http://localhost:5007"
echo "🌉 External Bridge: http://localhost:5006"

