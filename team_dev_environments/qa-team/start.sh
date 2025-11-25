#!/bin/bash
# QA Team - Start script
# Services: Everything (all services for end-to-end testing)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting QA Team services..."
echo "Services: ALL SERVICES (complete stack for testing)"

docker compose -f docker-compose.dev.yml up -d

echo "✅ QA Team services started!"
echo ""
echo "🎨 Frontend: http://localhost:5173"
echo "🌐 API Gateway: http://localhost:5000"
echo "🤖 Cyrex: http://localhost:8000"
echo "📊 MLflow: http://localhost:5500"
echo "📓 Jupyter: http://localhost:8888"
echo "🗄️  Mongo Express: http://localhost:8081"

