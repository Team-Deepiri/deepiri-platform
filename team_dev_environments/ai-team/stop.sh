#!/bin/bash
# AI Team - Stop script
# Stops: cyrex, api-gateway, engagement-service, challenge-service, external-bridge-service + their dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping AI Team services..."

# Stop services that exist (skip submodules if not initialized)
SERVICES=()
for service in cyrex api-gateway engagement-service challenge-service external-bridge-service; do
  case $service in
    api-gateway)
      if [ -f "platform-services/backend/deepiri-api-gateway/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    external-bridge-service)
      if [ -f "platform-services/backend/deepiri-external-bridge-service/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (submodule not initialized)"
      fi
      ;;
    cyrex)
      if [ -f "diri-cyrex/Dockerfile" ]; then
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

echo "Stopping: ${SERVICES[*]} (and their dependencies)"

# Stop the services (dependencies will be stopped if not used by other services)
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo "✅ AI Team services stopped!"

