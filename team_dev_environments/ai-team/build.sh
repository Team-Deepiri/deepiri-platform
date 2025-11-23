#!/bin/bash
# AI Team - Build script
# Builds: cyrex jupyter challenge-service

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building AI Team services..."
echo "Building: cyrex jupyter challenge-service"

docker compose -f docker-compose.dev.yml build \
  cyrex jupyter challenge-service

echo "✅ AI Team services built successfully!"

