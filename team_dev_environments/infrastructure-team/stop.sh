#!/bin/bash
# Infrastructure Team - Stop script
# Stops infrastructure team services using docker-compose.dev.yml with service selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Infrastructure team services (all except frontend-dev)
SERVICES=(
  postgres pgadmin adminer redis influxdb etcd minio milvus
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  cyrex cyrex-interface mlflow jupyter synapse
)

echo "🛑 Stopping Infrastructure Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Stop selected services
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo ""
echo "✅ Infrastructure Team services stopped!"
echo ""
echo "Note: Containers are stopped but not removed."
echo "To remove containers: docker compose -f docker-compose.dev.yml rm -f ${SERVICES[*]}"
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"
