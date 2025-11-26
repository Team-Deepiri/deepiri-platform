#!/bin/bash
# Frontend Team - Stop script
# Stops: frontend-dev + auth-service + their dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping Frontend Team services..."

# Stop services that exist (skip submodules if not initialized)
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
  echo "❌ No services to stop!"
  exit 1
fi

echo "Stopping: ${SERVICES[*]} (and their dependencies: mongodb, influxdb)"

# Stop the services (dependencies will be stopped if not used by other services)
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo "✅ Frontend Team services stopped!"

