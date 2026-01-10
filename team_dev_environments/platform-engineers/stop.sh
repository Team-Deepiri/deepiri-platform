#!/bin/bash
# Platform Engineers - Stop script
# Stops all services using docker-compose.dev.yml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🛑 Stopping Platform Engineers services (Full Stack)..."
echo "   (Using docker-compose.dev.yml)"
echo ""

# Stop all services
docker compose -f docker-compose.dev.yml stop

echo ""
echo "✅ Platform Engineers services stopped!"
echo ""
echo "Note: Containers are stopped but not removed."
echo "To remove containers: docker compose -f docker-compose.dev.yml down"
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"
