#!/bin/bash
# QA Team - Stop and Remove script
# Stops services, and if already stopped, removes the containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# QA team services
SERVICES=(
  postgres redis influxdb
  api-gateway auth-service task-orchestrator
  engagement-service platform-analytics-service
  notification-service external-bridge-service
  challenge-service realtime-gateway
  language-intelligence-service
  synapse adminer
)

echo "🛑 Stopping and removing QA Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# First, try to stop services (this will succeed even if already stopped)
echo "Step 1: Stopping services..."
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}" 2>/dev/null || true

echo ""
echo "Step 2: Removing containers..."
# Remove containers (force remove, ignore if already removed)
docker compose -f docker-compose.dev.yml rm -f "${SERVICES[@]}" 2>/dev/null || true

echo ""
echo "✅ QA Team services stopped and containers removed!"
echo ""
echo "Note: Volumes and networks are preserved."
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"

