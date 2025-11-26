#!/bin/bash
# Platform Engineers - Build script
# Builds: All services

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building Platform Engineers services..."
echo "Building: All services"

docker compose -f docker-compose.dev.yml build

echo "✅ Platform Engineers services built successfully!"

