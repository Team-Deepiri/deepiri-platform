#!/bin/bash

# Build Docker containers and automatically clean up build cache
# Usage: ./build-with-cleanup.sh [docker-compose-file]

set -e

COMPOSE_FILE="${1:-docker-compose.dev.yml}"

echo "🔨 Building Docker containers..."
echo "Using compose file: $COMPOSE_FILE"
echo ""

# Build the containers
docker-compose -f "$COMPOSE_FILE" build --no-cache

echo ""
echo "✅ Build complete!"
echo ""
echo "🧹 Cleaning up build cache to free disk space..."

# Clean up build cache (this is safe - it only removes unused cache)
docker builder prune -a -f

echo ""
echo "📊 Current Docker disk usage:"
docker system df

echo ""
echo "✅ Done! Containers built and cache cleaned."

