#!/bin/bash
# ML Team - Stop script
# Stops: cyrex + its dependencies

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🛑 Stopping ML Team services..."

# Stop services that exist (skip submodules if not initialized)
SERVICES=()
for service in cyrex; do
  case $service in
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

echo "Stopping: ${SERVICES[*]} (and their dependencies: influxdb, milvus, etcd, minio)"

# Stop the services (dependencies will be stopped if not used by other services)
docker compose -f docker-compose.dev.yml stop "${SERVICES[@]}"

echo "✅ ML Team services stopped!"

