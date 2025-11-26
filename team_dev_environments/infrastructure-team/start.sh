#!/bin/bash
# Infrastructure Team - Start script
# Requirements: All services EXCEPT frontend + their dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Infrastructure Team services..."

# Start all services except frontend-dev
ALL_SERVICES=(
  mongodb redis influxdb mongo-express etcd minio milvus
  api-gateway auth-service task-orchestrator engagement-service platform-analytics-service
  notification-service external-bridge-service challenge-service realtime-gateway
  cyrex cyrex-interface mlflow jupyter
)

SERVICES_TO_START=()
for service in "${ALL_SERVICES[@]}"; do
  case $service in
    api-gateway)
      if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        SERVICES_TO_START+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    auth-service)
      if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
        SERVICES_TO_START+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    external-bridge-service)
      if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
        SERVICES_TO_START+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    cyrex|jupyter)
      if [ -f "diri-cyrex/Dockerfile" ] || [ -f "diri-cyrex/Dockerfile.jupyter" ]; then
        SERVICES_TO_START+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    *)
      # For non-submodule services or services without specific Dockerfiles
      SERVICES_TO_START+=("$service")
      ;;
  esac
done

if [ ${#SERVICES_TO_START[@]} -eq 0 ]; then
  echo "❌ No services to start for Infrastructure Team!"
  exit 1
fi

echo "Starting: ${SERVICES_TO_START[*]} (excluding frontend-dev)"

# Use --no-build to prevent automatic building (images should already be built)
docker compose -f docker-compose.dev.yml up -d --no-build "${SERVICES_TO_START[@]}"

echo "✅ Infrastructure Team services started!"
echo ""
echo "🗄️  MongoDB: localhost:27017"
echo "🗄️  Mongo Express: http://localhost:8081"
echo "💾 Redis: localhost:6380"
echo "📊 InfluxDB: http://localhost:8086"
echo "🌐 API Gateway: http://localhost:5000"

