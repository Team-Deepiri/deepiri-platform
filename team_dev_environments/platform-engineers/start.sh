#!/bin/bash
# Platform Engineers - Start script
# Services: Everything (all services for platform tooling development)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Platform Engineers services..."
echo "Services: ALL SERVICES (complete stack)"

docker compose -f docker-compose.dev.yml up -d

echo "✅ Platform Engineers services started!"
echo ""
echo "🌐 API Gateway: http://localhost:5000"
echo "🎨 Frontend: http://localhost:5173"
echo "🤖 Cyrex: http://localhost:8000"
echo "📊 MLflow: http://localhost:5500"
echo "📓 Jupyter: http://localhost:8888"
echo "🗄️  Mongo Express: http://localhost:8081"

