#!/bin/bash
# Backend Team - Stop script
# Stops backend team services using docker-compose.dev.yml with service selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Backend team services
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb
  api-gateway auth-service workflow-orchestrator
  incentive-engine decision-intelligence
  communications-hub external-bridge-service
  adaptive-experience-engine realtime-gateway
  language-intelligence-service messaging-service
  synapse synapse-sugar-glider frontend-dev adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🛑 Stopping Backend Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Stop selected services
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo ""
echo "✅ Backend Team services stopped!"
echo ""
echo "Note: Containers are stopped but not removed."
echo "To remove containers: docker compose -f docker-compose.dev.yml rm -f ${SERVICES[*]}"
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"
echo ""
