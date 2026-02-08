#!/bin/bash
# Smart build script - automatically cleans up dangling images
# Usage: ./build.sh [service-name] [--no-cache]

set -e

cd "$(dirname "$0")"

# Enable BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICE="${1:-}"
NO_CACHE_FLAG=""

# Check for --no-cache flag
if [[ "$1" == "--no-cache" ]] || [[ "$2" == "--no-cache" ]]; then
    NO_CACHE_FLAG="--no-cache"
    echo -e "${YELLOW}Building with --no-cache (slower, forces rebuild)${NC}"
fi

# Build
echo -e "${GREEN}Building${NC}..."
if [ -z "$SERVICE" ] || [ "$SERVICE" == "--no-cache" ]; then
    docker compose -f docker-compose.dev.yml build $NO_CACHE_FLAG
else
    docker compose -f docker-compose.dev.yml build $NO_CACHE_FLAG "$SERVICE"
fi

# Auto-cleanup dangling images
echo -e "${GREEN}Cleaning up dangling images...${NC}"
docker images -f "dangling=true" -q | xargs -r docker rmi -f > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Build complete!${NC}"
docker system df

