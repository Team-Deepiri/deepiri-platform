#!/bin/bash
# QA Team - Start Script
# Starts all backend services using docker-compose.dev.yml with service selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# QA team services (language-intelligence-service is handled separately — optional)
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb kafka
  synapse synapse-sugar-glider
  api-gateway auth-service workflow-orchestrator
  incentive-engine decision-intelligence
  communications-hub external-bridge-service
  adaptive-experience-engine realtime-gateway
  messaging-service frontend-dev adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🚀 Starting QA Team Environment..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# # Check if frontend image exists, build if missing
# if ! docker image inspect deepiri-dev-frontend:latest >/dev/null 2>&1; then
#   echo "⚠️  Frontend image not found. Building frontend-dev..."
#   docker compose -f docker-compose.dev.yml build frontend-dev
#   echo ""
# fi

echo "🔧 Starting services..."
docker compose -f docker-compose.dev.yml up -d --no-build --no-deps "${SERVICES[@]}"

# language-intelligence-service is optional — only start if image exists
if docker image inspect deepiri-dev-language-intelligence-service:latest >/dev/null 2>&1; then
  echo "📝 Starting language-intelligence-service..."
  docker compose -f docker-compose.dev.yml up -d --no-build --no-deps language-intelligence-service || echo "⚠️  language-intelligence-service failed to start (optional service)"
else
  echo "⚠️  Skipping language-intelligence-service (image not found - optional service)"
fi

echo ""
echo "✅ QA Team Environment Started!"
echo ""
echo "Access your services:"
echo ""
echo "  Frontend & Services:"
echo "  - Frontend (Vite HMR):              http://localhost:5173"
echo "  - API Gateway:                      http://localhost:${API_GATEWAY_PORT:-5100}"
echo "  - Auth Service:                     http://localhost:5001"
echo "  - Workflow Orchestrator:            http://localhost:5002"
echo "  - Incentive Engine:                 http://localhost:5003"
echo "  - Decision Intelligence:            http://localhost:5004"
echo "  - Communications Hub:               http://localhost:5005"
echo "  - External Bridge:                  http://localhost:5006"
echo "  - Adaptive Experience Engine:       http://localhost:5007"
echo "  - Realtime Gateway:                 http://localhost:5008"
echo "  - Messaging Service:                http://localhost:5009"
echo "  - Synapse:                          http://localhost:8002"
echo ""
echo "  Infrastructure:"
echo "  - PostgreSQL (core):              localhost:5432"
echo "  - PostgreSQL (auth):              localhost:5433"
echo "  - PostgreSQL (intelligence):      localhost:5434"
echo "  - Redis:                          localhost:6380"
echo "  - InfluxDB:                       http://localhost:8086"
echo "  - Adminer:                        http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  View logs:                docker compose -f docker-compose.dev.yml logs -f ${SERVICES[*]}"
echo "  View specific service:    docker compose -f docker-compose.dev.yml logs -f <service-name>"
echo "  Stop services:            docker compose -f docker-compose.dev.yml stop ${SERVICES[*]}"
echo "  Restart service:          docker compose -f docker-compose.dev.yml restart <service-name>"
echo ""
