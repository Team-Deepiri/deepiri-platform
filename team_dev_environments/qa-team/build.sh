#!/bin/bash
# QA Team - Build script
# Builds: All services

set -e

cd "$(dirname "$0")/../.." || exit 1

echo "🔨 Building QA Team services..."
echo "Building: All services"

docker compose -f docker-compose.dev.yml build

echo "✅ QA Team services built successfully!"

