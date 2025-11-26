#!/bin/bash
# Infrastructure Team - Stop script
# Stops: All services EXCEPT frontend + their dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping Infrastructure Team services..."

# Stop all services except frontend-dev
ALL_SERVICES=(
  mongodb redis influxdb mongo-express etcd minio milvus
  api-gateway auth-service task-orchestrator engagement-service platform-analytics-service
  notification-service external-bridge-service challenge-service realtime-gateway
  cyrex cyrex-interface mlflow jupyter
)

SERVICES_TO_STOP=()
for service in "${ALL_SERVICES[@]}"; do
  case $service in
    api-gateway)
      if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        SERVICES_TO_STOP+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    auth-service)
      if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
        SERVICES_TO_STOP+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    external-bridge-service)
      if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
        SERVICES_TO_STOP+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    cyrex|jupyter)
      if [ -f "diri-cyrex/Dockerfile" ] || [ -f "diri-cyrex/Dockerfile.jupyter" ]; then
        SERVICES_TO_STOP+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    *)
      # For non-submodule services or services without specific Dockerfiles
      SERVICES_TO_STOP+=("$service")
      ;;
  esac
done

if [ ${#SERVICES_TO_STOP[@]} -eq 0 ]; then
  echo "❌ No services to stop for Infrastructure Team!"
  exit 1
fi

echo "Stopping: ${SERVICES_TO_STOP[*]} (excluding frontend-dev)"

# Stop the services (dependencies will be stopped if not used by other services)
docker compose -f docker-compose.dev.yml stop "${SERVICES_TO_STOP[@]}"

echo "✅ Infrastructure Team services stopped!"

