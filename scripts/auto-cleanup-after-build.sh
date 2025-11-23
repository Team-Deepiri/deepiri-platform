#!/bin/bash
# Auto-cleanup script - runs automatically after builds
# Removes dangling images to prevent 50GB+ buildup

# Silently remove dangling images
docker images -f "dangling=true" -q | xargs -r docker rmi -f > /dev/null 2>&1 || true

# Also prune stopped containers silently
docker container prune -f > /dev/null 2>&1 || true

exit 0

