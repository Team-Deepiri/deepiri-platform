#!/bin/bash
# Infrastructure Team - Start script
# Currently same as backend team
#
# Note: Infrastructure team will work on cloud infrastructure and data infrastructure
# services in the future (e.g., cloud storage, data pipelines, monitoring infrastructure, etc.)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Infrastructure Team Environment..."

# Infrastructure team services (currently same as backend team)
# Future: Will include cloud infrastructure and data infrastructure services
ALL_SERVICES=(
  postgres redis influxdb
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  language-intelligence-service messaging-service
  frontend-dev synapse adminer
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

echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES_TO_START[*]}"
echo ""

# Use wrapper to auto-load k8s config, then start selected services
#./docker-compose-k8s.sh -f docker-compose.dev.yml up -d "${SERVICES_TO_START[@]}"
docker compose -f docker-compose.dev.yml up -d --no-build --no-deps "${SERVICES_TO_START[@]}"

# Get API Gateway port from environment or use default
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}

echo "✅ Infrastructure Team Environment Started!"
echo ""
echo "Access your services:"
echo ""
echo "  Frontend & Services:"
echo "  - Frontend (Vite HMR):     http://localhost:5173"
echo "  - API Gateway:             http://localhost:${API_GATEWAY_PORT:-5100}"
echo "  - Auth Service:            http://localhost:5001"
echo "  - Task Orchestrator:      http://localhost:5002"
echo "  - Engagement Service:     http://localhost:5003"
echo "  - Platform Analytics:      http://localhost:5004"
echo "  - Notification Service:    http://localhost:5005"
echo "  - External Bridge:         http://localhost:5006"
echo "  - Challenge Service:       http://localhost:5007"
echo "  - Realtime Gateway:        http://localhost:5008"
echo "  - Messaging Service:       http://localhost:5009"
echo "  - Synapse:                 http://localhost:8002"
echo ""
echo "  Infrastructure:"
echo "  - PostgreSQL:             localhost:5432"
echo "  - Redis:                  localhost:6380"
echo "  - InfluxDB:               http://localhost:8086"
echo "  - Adminer:                http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  View logs:                docker compose -f docker-compose.dev.yml logs -f ${SERVICES_TO_START[*]}"
echo "  View specific service:    docker compose -f docker-compose.dev.yml logs -f <service-name>"
echo "  Stop services:            docker compose -f docker-compose.dev.yml stop ${SERVICES_TO_START[*]}"
echo "  Restart service:          docker compose -f docker-compose.dev.yml restart <service-name>"
echo ""

