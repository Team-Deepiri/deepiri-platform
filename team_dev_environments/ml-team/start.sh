#!/bin/bash
# ML Team - Start script
# Requirements: Synapse + its dependencies
# Dependencies will be started automatically by docker compose

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🚀 Starting ML Team services..."

# Start services that exist (skip submodules if not initialized)
SERVICES=()
for service in synapse sugar-glider; do
  case $service in
    synapse)
      if [ -f "platform-services/shared/deepiri-synapse/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (not found)"
      fi
      ;;
    sugar-glider)
      if [ -f "platform-services/shared/deepiri-sugar-glider/Dockerfile" ]; then
        SERVICES+=("$service")
      else
        echo "⚠️  Skipping $service (not found)"
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

echo "Starting: ${SERVICES[*]} (and their dependencies: influxdb, milvus, etcd, minio)"

# Use --no-build to prevent automatic building (images should already be built)
# Dependencies (influxdb, milvus, etcd, minio) will be started automatically
docker compose -f docker-compose.dev.yml up -d --no-build "${SERVICES[@]}"

echo "✅ ML Team services started!"
echo ""
echo "📡 Synapse: http://localhost:8002"
echo "🛰️ Sugar Glider: http://localhost:8081"
