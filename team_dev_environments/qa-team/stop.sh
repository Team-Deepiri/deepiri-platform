#!/bin/bash
# QA Team - Stop script
# Stops backend team services using docker-compose.dev.yml with service selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# QA team services
SERVICES=(
  postgres-auth postgres-core postgres-intelligence redis influxdb
  api-gateway auth-service truss
  registry telemetry
  communications-hub external-bridge-service
  jobs realtime-gateway
  language-intelligence-service messaging-service
  synapse sugar-glider adminer
  # deepiri-prismpipe  # PrismPipe - Capability-Routed API Pipeline (Coming Soon)
)

echo "🛑 Stopping QA Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Stop selected services
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo ""
echo "✅ QA Team services stopped!"
echo ""
echo "Note: Containers are stopped but not removed."
echo "To remove containers: docker compose -f docker-compose.dev.yml rm -f ${SERVICES[*]}"
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"
echo ""
