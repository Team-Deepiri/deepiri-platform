#!/bin/bash
# ML Team - Build script
# Builds: cyrex cyrex-interface jupyter platform-analytics-service

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building ML Team services..."

# Build services that exist (skip submodules if not initialized)
SERVICES=()
for service in cyrex cyrex-interface jupyter platform-analytics-service; do
  case $service in
    cyrex|jupyter)
      if [ -f "diri-cyrex/Dockerfile" ] || [ -f "diri-cyrex/Dockerfile.jupyter" ]; then
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

echo "Building: ${SERVICES[*]}"

docker compose -f docker-compose.dev.yml build "${SERVICES[@]}"

echo "✅ ML Team services built successfully!"

