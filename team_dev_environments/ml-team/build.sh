#!/bin/bash
# ML Team - Build script
# Builds: cyrex cyrex-interface jupyter platform-analytics-service

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building ML Team services..."
echo "Building: cyrex cyrex-interface jupyter platform-analytics-service"

docker compose -f docker-compose.dev.yml build \
  cyrex cyrex-interface jupyter platform-analytics-service

echo "✅ ML Team services built successfully!"

