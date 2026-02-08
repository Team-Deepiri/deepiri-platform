#!/bin/bash
# Platform Engineers - Stop and Remove script
# Stops all services, and if already stopped, removes the containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🛑 Stopping and removing Platform Engineers services (Full Stack)..."
echo "   (Using docker-compose.dev.yml)"
echo ""

# First, try to stop all services (this will succeed even if already stopped)
echo "Step 1: Stopping all services..."
docker compose -f docker-compose.dev.yml stop 2>/dev/null || true

echo ""
echo "Step 2: Removing all containers..."
# Remove all containers (force remove, ignore if already removed)
docker compose -f docker-compose.dev.yml rm -f 2>/dev/null || true

echo ""
echo "✅ Platform Engineers services stopped and containers removed!"
echo ""
echo "Note: Volumes and networks are preserved."
echo "To remove volumes as well: docker compose -f docker-compose.dev.yml down -v"

