#!/bin/bash
# Backend Team - Start Script
# Starts all backend services with k8s configmaps and secrets
# Matches docker-compose.backend-team.yml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🚀 Starting Backend Team Environment..."
echo "   (Using k8s configmaps and secrets from ops/k8s/)"
echo "   (Matching docker-compose.backend-team.yml)"
echo ""

# Use wrapper to auto-load k8s config
./docker-compose-k8s.sh -f docker-compose.backend-team.yml up -d

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
echo ""
echo "  Infrastructure:"
echo "  - PostgreSQL:             localhost:5432"
echo "  - Redis:                  localhost:6380"
echo "  - InfluxDB:               http://localhost:8086"
echo "  - pgAdmin:                http://localhost:5050"
echo "  - Adminer:                http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  View logs:                docker compose -f docker-compose.backend-team.yml logs -f"
echo "  View specific service:    docker compose -f docker-compose.backend-team.yml logs -f <service-name>"
echo "  Stop services:            docker compose -f docker-compose.backend-team.yml down"
echo "  Restart service:          docker compose -f docker-compose.backend-team.yml restart <service-name>"
echo ""
