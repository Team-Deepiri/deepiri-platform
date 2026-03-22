#!/bin/bash

# Docker Cleanup Script
# Automatically cleans up Docker build cache and unused resources
# Run this after building containers to free up disk space

set -e

echo "🧹 Starting Docker cleanup..."

# Show disk usage before cleanup
echo ""
echo "📊 Disk usage BEFORE cleanup:"
docker system df

echo ""
echo "🗑️  Removing build cache..."
docker builder prune -a -f

echo ""
echo "🗑️  Removing unused images (keeping only active ones)..."
# Remove dangling images (untagged)
docker image prune -f

# Remove unused images (not used by any container)
# This keeps images that are currently in use
docker image prune -a -f --filter "until=24h" || docker image prune -a -f

echo ""
echo "🗑️  Removing stopped containers..."
docker container prune -f

echo ""
echo "📊 Disk usage AFTER cleanup:"
docker system df

echo ""
echo "✅ Cleanup complete!"

