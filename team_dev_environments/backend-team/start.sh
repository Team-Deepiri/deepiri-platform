#!/bin/bash
# Backend Team - Start script
# Requirements: core-api, web-frontend, api-gateway, auth + all their dependencies
# Dependencies will be started automatically by docker compose

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Backend Team services..."

# Start services that exist (skip submodules if not initialized)
SERVICES=()
for service in frontend-dev api-gateway auth-service; do
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

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to start!"
  exit 1
fi

echo "Starting: ${SERVICES[*]} (and their dependencies)"

# Use --no-build to prevent automatic building (images should already be built)
# Dependencies (mongodb, redis, influxdb, etcd, minio, milvus, cyrex, task-orchestrator, 
# engagement-service, platform-analytics-service, notification-service, challenge-service, 
# realtime-gateway) will be started automatically
docker compose -f docker-compose.dev.yml up -d --no-build "${SERVICES[@]}"

echo "✅ Backend Team services started!"
echo ""
echo "🎨 Frontend: http://localhost:5173"
echo "🌐 API Gateway: http://localhost:5000"
echo "🔐 Auth Service: http://localhost:5001"

