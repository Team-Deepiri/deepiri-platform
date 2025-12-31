#!/bin/bash
# Frontend Team - Start script
# Starts ONLY the services needed by the frontend using docker-compose.dev.yml with service selection

set -e

cd "$(dirname "$0")/../.." || exit 1

# Frontend team services - only what frontend engineers need
SERVICES=(
  frontend-dev
  api-gateway
  auth-service
  notification-service
)

echo "🚀 Starting Frontend Team services..."
echo "   (Using docker-compose.dev.yml with service selection)"
echo "   Services: ${SERVICES[*]}"
echo ""

# Use --no-build and --no-deps to start only these services without dependencies
docker compose -f docker-compose.dev.yml up -d --no-build --no-deps "${SERVICES[@]}"

# Get API Gateway port from environment or use default
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}

echo "✅ Frontend Team services started!"
echo ""
echo "🎨 Frontend: http://localhost:5173"
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🔐 Auth Service: http://localhost:5001"
echo "🔔 Notification Service: http://localhost:5005"

