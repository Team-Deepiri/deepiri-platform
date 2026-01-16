#!/bin/bash
# Frontend Team - Stop and Remove script
# Stops services, and if already stopped, removes the containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Frontend team services
SERVICES=(
  frontend-dev
  api-gateway
  auth-service
  notification-service
)

echo "🛑 Stopping and removing Frontend Team services..."
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
echo "✅ Frontend Team services stopped and containers removed!"
echo ""
echo "Note: Volumes and networks are preserved."
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"

