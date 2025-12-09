#!/bin/bash
# Backend Team - Stop script
# Stops and removes all containers defined in docker-compose.backend-team.yml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🛑 Stopping Backend Team services..."
echo "   (Matching docker-compose.backend-team.yml)"
echo ""

# Use docker-compose to stop and remove all services
# This automatically handles all containers defined in the compose file
docker compose -f docker-compose.backend-team.yml down

echo ""
echo "✅ Backend Team services stopped and removed!"
echo ""
echo "Note: Volumes are preserved by default."
echo "To remove volumes as well, run:"
echo "  docker compose -f docker-compose.backend-team.yml down -v"
echo ""
