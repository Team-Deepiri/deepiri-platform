#!/bin/bash
# Frontend Team - Start script
# Starts ONLY the services needed by the frontend:
#   - frontend-dev: React frontend application
#   - api-gateway: Routes REST API calls from frontend
#   - realtime-gateway: WebSocket for real-time features
#   - auth-service, task-orchestrator, engagement-service, platform-analytics-service,
#     notification-service, challenge-service: Dependencies of api-gateway
#   - Infrastructure: postgres, redis, influxdb, pgadmin, adminer (started automatically)
#
# Services NOT started (not needed by frontend):
#   - external-bridge-service (only needed for integrations)
#   - core-api / deepiri-core-api (deprecated legacy monolith, replaced by microservices)
#   - cyrex, jupyter, mlflow (AI/ML services, not needed by frontend)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Frontend Team services (ONLY services needed by frontend)..."

# Start services that exist (skip submodules if not initialized)
# These are the exact services needed by the frontend - no more, no less
SERVICES=()
for service in frontend-dev api-gateway auth-service task-orchestrator engagement-service platform-analytics-service notification-service challenge-service realtime-gateway; do
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
      # For services without specific Dockerfile checks
      SERVICES+=("$service")
      ;;
  esac
done

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to start!"
  exit 1
fi

echo "Starting: ${SERVICES[*]} (and their dependencies: postgres, redis, influxdb, pgadmin)"

# Use --no-build to prevent automatic building (images should already be built)
# Dependencies (postgres, redis, influxdb, pgadmin) will be started automatically
docker compose -f docker-compose.frontend-team.yml up -d --no-build "${SERVICES[@]}"

# Get API Gateway port from environment or use default
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}

echo "✅ Frontend Team services started!"
echo ""
echo "🎨 Frontend: http://localhost:5173"
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🔐 Auth Service: http://localhost:5001"
echo "🗄️  pgAdmin: http://localhost:5050"
echo "🔍 Adminer: http://localhost:8080"

