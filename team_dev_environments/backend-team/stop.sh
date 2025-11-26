#!/bin/bash
# Backend Team - Stop script
# Stops all backend team services and their dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping Backend Team services..."

# Stop all services in the backend-team compose file
# This stops all services defined in docker-compose.backend-team.yml:
# - frontend-dev, api-gateway, auth-service
# - task-orchestrator, engagement-service, platform-analytics-service
# - notification-service, external-bridge-service, challenge-service
# - realtime-gateway
# - mongodb, redis, influxdb
docker compose -f docker-compose.backend-team.yml stop

echo "✅ Backend Team services stopped!"

