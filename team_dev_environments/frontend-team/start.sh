#!/bin/bash
# Frontend Team - Start script
# Requirements: frontend-dev + auth-service + their dependencies
# Dependencies: mongodb, influxdb (for auth-service)

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting Frontend Team services..."

# Start services that exist (skip submodules if not initialized)
SERVICES=()
for service in frontend-dev auth-service; do
  case $service in
    auth-service)
      if [ -f "platform-services/backend/deepiri-auth-service/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    frontend-dev)
      if [ -f "deepiri-web-frontend/Dockerfile.dev" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    *)
      SERVICES+=("$service")
      ;;
  esac
done

if [ ${#SERVICES[@]} -eq 0 ]; then
  echo "❌ No services to start!"
  exit 1
fi

echo "Starting: ${SERVICES[*]} (and their dependencies: mongodb, influxdb)"

# Use --no-build to prevent automatic building (images should already be built)
# Dependencies (mongodb, influxdb) will be started automatically
docker compose -f docker-compose.dev.yml up -d --no-build "${SERVICES[@]}"

echo "✅ Frontend Team services started!"
echo ""
echo "🎨 Frontend: http://localhost:5173"
echo "🔐 Auth Service: http://localhost:5001"

