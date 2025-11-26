#!/bin/bash
# Platform Engineers - Stop script
# Stops: ALL SERVICES (complete stack)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping Platform Engineers services..."
echo "Stopping: ALL SERVICES (complete stack)"

# Stop all services
docker compose -f docker-compose.dev.yml stop

echo "✅ Platform Engineers services stopped!"

