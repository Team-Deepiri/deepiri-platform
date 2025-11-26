#!/bin/bash
# Infrastructure Team - Build script
# Builds: All services

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building Infrastructure Team services..."
echo "Building: All services"

docker compose -f docker-compose.dev.yml build

echo "✅ Infrastructure Team services built successfully!"

