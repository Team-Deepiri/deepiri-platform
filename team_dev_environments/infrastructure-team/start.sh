#!/bin/bash
# Infrastructure Team - Start script
# Requirements: All services EXCEPT frontend + their dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Infrastructure Team services..."

# Start all services except frontend-dev and AI/ML services (cyrex, ollama, mlflow, jupyter, milvus)
ALL_SERVICES=(
  postgres pgadmin redis influxdb etcd minio
  api-gateway auth-service task-orchestrator engagement-service platform-analytics-service
  notification-service external-bridge-service challenge-service realtime-gateway synapse
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
    synapse)
      if [ -f "platform-services/shared/deepiri-synapse/Dockerfile" ]; then
        SERVICES_TO_START+=("$service")
      else
        echo "⚠️  Skipping $service (not found)"
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

# Get API Gateway port from environment or use default
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}

echo "✅ Infrastructure Team services started!"
echo ""
echo "🗄️  PostgreSQL: localhost:5432"
echo "📊 pgAdmin: http://localhost:5050"
echo "🔍 Adminer: http://localhost:8080"
echo "💾 Redis: localhost:6380"
echo "📊 InfluxDB: http://localhost:8086"
echo "📡 Synapse: http://localhost:8002"
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🔄 Synapse (Streaming): http://localhost:8002"
echo ""
echo "ℹ️  AI/ML services excluded: cyrex, ollama, mlflow, jupyter, milvus"

