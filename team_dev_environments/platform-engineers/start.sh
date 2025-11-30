#!/bin/bash
# Platform Engineers - Start script
# Services from SERVICE_COMMUNICATION_AND_TEAMS.md:
# - All Services for platform tooling development

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Platform Engineers services..."
echo "Services: ALL SERVICES (complete stack)"

# Use --no-build to prevent automatic building (images should already be built)
docker compose -f docker-compose.dev.yml up -d --no-build

echo "✅ Platform Engineers services started!"
echo ""
API_GATEWAY_PORT=${API_GATEWAY_PORT:-5100}
echo "🌐 API Gateway: http://localhost:${API_GATEWAY_PORT}"
echo "🎨 Frontend: http://localhost:5173"
echo "🤖 Cyrex: http://localhost:8000"
echo "📊 MLflow: http://localhost:5500"
echo "📓 Jupyter: http://localhost:8888"
echo "🗄️  pgAdmin: http://localhost:5050"
echo "🔍 Adminer: http://localhost:8080"

