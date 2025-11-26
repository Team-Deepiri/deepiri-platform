#!/bin/bash
# ML Team - Build script
# Requirements: Just cyrex + its dependencies
# Dependencies: cyrex needs (influxdb, milvus), milvus needs (etcd, minio)

set -e

cd "$(dirname "$0")/../.." || exit 1

# Enable BuildKit for better builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "🔨 Building ML Team services..."

# Build services that exist (skip submodules if not initialized)
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
  echo "❌ No services to build!"
  exit 1
fi

echo "Building: ${SERVICES[*]} (and their dependencies: influxdb, milvus, etcd, minio)"

# Build services with their dependencies
docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"

