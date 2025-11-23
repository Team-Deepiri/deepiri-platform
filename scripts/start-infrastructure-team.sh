#!/bin/bash
# Infrastructure Team - Start script
# Services: All infrastructure + all microservices for monitoring

set -e

cd "$(dirname "$0")/.." || exit 1

echo "🚀 Starting Infrastructure Team services..."
echo "Services: All infrastructure + all microservices"

# Build all services
docker compose -f docker-compose.dev.yml build

# Start everything
docker compose -f docker-compose.dev.yml up -d

echo "✅ Infrastructure Team services started!"
echo "🗄️  MongoDB: localhost:27017"
echo "🗄️  Mongo Express: http://localhost:8081"
echo "💾 Redis: localhost:6380"
echo "📊 InfluxDB: http://localhost:8086"
echo "🌐 API Gateway: http://localhost:5000"

