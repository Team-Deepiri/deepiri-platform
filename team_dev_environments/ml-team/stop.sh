#!/bin/bash
# ML Team - Stop script
# Stops ML team services using docker-compose.dev.yml with service selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# ML team services
SERVICES=(
  postgres redis influxdb
  jupyter mlflow
  platform-analytics-service synapse
)

echo "🛑 Stopping ML Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Stop selected services
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo ""
echo "✅ ML Team services stopped!"
echo ""
echo "Note: Containers are stopped but not removed."
echo "To remove containers: docker compose -f docker-compose.dev.yml rm -f ${SERVICES[*]}"
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"
