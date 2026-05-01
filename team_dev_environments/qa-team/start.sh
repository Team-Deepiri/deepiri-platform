#!/bin/bash
# QA Team - Start Script
# Starts all backend services using docker-compose.dev.yml with service selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# QA team services (language-intelligence-service is optional - only if image exists)
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb
  api-gateway auth-service workflow-orchestrator
  incentive-engine decision-intelligence
  communications-hub external-bridge-service
  adaptive-experience-engine realtime-gateway
  language-intelligence-service messaging-service
  frontend-dev synapse adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🚀 Starting QA Team Environment..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Check if frontend image exists, build if missing
if ! docker image inspect deepiri-dev-frontend:latest >/dev/null 2>&1; then
  echo "⚠️  Frontend image not found. Building frontend-dev..."
  docker compose -f docker-compose.dev.yml build frontend-dev
  echo ""
fi

# Start infrastructure services first (without --no-deps to ensure proper startup order)
echo "📦 Starting infrastructure services..."
docker compose -f docker-compose.dev.yml up -d --no-build postgres-auth postgres-core postgres-intelligence redis influxdb synapse

# Wait a moment for infrastructure to be ready
echo "⏳ Waiting for infrastructure to be ready..."
sleep 3

# Start backend services (can use --no-deps since infrastructure is up)
echo "🔧 Starting backend services..."
docker compose -f docker-compose.dev.yml up -d --no-build --no-deps \
  api-gateway auth-service workflow-orchestrator \
  incentive-engine decision-intelligence \
  communications-hub external-bridge-service \
  adaptive-experience-engine realtime-gateway messaging-service \
  adminer

# Try to start language-intelligence-service if image exists (optional service)
if docker image inspect deepiri-dev-language-intelligence-service:latest >/dev/null 2>&1; then
  echo "📝 Starting language-intelligence-service..."
  docker compose -f docker-compose.dev.yml up -d --no-build --no-deps language-intelligence-service || echo "⚠️  language-intelligence-service failed to start (optional service)"
else
  echo "⚠️  Skipping language-intelligence-service (image not found - optional service)"
fi

# Start frontend last (it depends on synapse, so we don't use --no-deps for it)
echo "🎨 Starting frontend..."
docker compose -f docker-compose.dev.yml up -d --no-build frontend-dev

# Check if frontend container is running
echo ""
echo "🔍 Checking frontend status..."
sleep 2
if docker ps --format '{{.Names}}' | grep -q '^deepiri-frontend-dev$'; then
  echo "✅ Frontend container is running"
  echo "📋 Frontend logs (last 20 lines):"
  docker compose -f docker-compose.dev.yml logs --tail=20 frontend-dev
else
  echo "❌ Frontend container failed to start. Checking logs..."
  docker compose -f docker-compose.dev.yml logs --tail=50 frontend-dev
  exit 1
fi

echo ""
echo "✅ QA Team Environment Started!"
echo ""
echo "Access your services:"
echo ""
echo "  Frontend & Services:"
echo "  - Frontend (Vite HMR):     http://localhost:5173"
echo "  - API Gateway:             http://localhost:${API_GATEWAY_PORT:-5100}"
echo "  - Auth Service:            http://localhost:5001"
echo "  - Workflow Orchestrator:   http://localhost:5002"
echo "  - Incentive Engine:        http://localhost:5003"
echo "  - Decision Intelligence:   http://localhost:5004"
echo "  - Communications Hub:      http://localhost:5005"
echo "  - External Bridge:         http://localhost:5006"
echo "  - Adaptive Experience:     http://localhost:5007"
echo "  - Realtime Gateway:        http://localhost:5008"
echo "  - Messaging Service:       http://localhost:5009"
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
