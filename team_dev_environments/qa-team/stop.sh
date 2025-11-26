#!/bin/bash
# QA Team - Stop script
# Stops: ALL SERVICES (complete stack for testing)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping QA Team services..."
echo "Stopping: ALL SERVICES (complete stack for testing)"

# Stop all services
docker compose -f docker-compose.dev.yml stop

echo "✅ QA Team services stopped!"

