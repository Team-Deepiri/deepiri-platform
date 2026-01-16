#!/bin/bash
# Backend Team - Start Script
# Starts all backend services using docker-compose.dev.yml with service selection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Backend team services
SERVICES=(
  postgres redis influxdb
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  language-intelligence-service
  frontend-dev synapse adminer
)

echo "🚀 Starting Backend Team Environment..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Use wrapper to auto-load k8s config, then start selected services
#./docker-compose-k8s.sh -f docker-compose.dev.yml up -d "${SERVICES[@]}"
docker compose -f docker-compose.dev.yml up -d --no-build --no-deps "${SERVICES[@]}"

echo ""
echo "✅ Backend Team Environment Started!"
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
echo "  - Synapse:                 http://localhost:8002"
echo ""
echo "  Infrastructure:"
echo "  - PostgreSQL:             localhost:5432"
echo "  - Redis:                  localhost:6380"
echo "  - InfluxDB:               http://localhost:8086"
echo "  - pgAdmin:                http://localhost:5050"
echo "  - Adminer:                http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  View logs:                docker compose -f docker-compose.dev.yml logs -f ${SERVICES[*]}"
echo "  View specific service:    docker compose -f docker-compose.dev.yml logs -f <service-name>"
echo "  Stop services:            docker compose -f docker-compose.dev.yml stop ${SERVICES[*]}"
echo "  Restart service:          docker compose -f docker-compose.dev.yml restart <service-name>"
echo ""
