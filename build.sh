#!/bin/bash
# Smart build script - automatically cleans up dangling images
# Usage: ./build.sh [service-name] [--no-cache]
# Cloud portal → docker-compose.yml | control plane → docker-compose.dev.yml

set -e

cd "$(dirname "$0")"
# shellcheck source=scripts/utils/resolve-compose-file.sh
source "$(dirname "$0")/scripts/utils/resolve-compose-file.sh"
resolve_compose_file "." || exit 1

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICE="${1:-}"
NO_CACHE_FLAG=""

if [[ "$1" == "--no-cache" ]] || [[ "$2" == "--no-cache" ]]; then
    NO_CACHE_FLAG="--no-cache"
    echo -e "${YELLOW}Building with --no-cache (slower, forces rebuild)${NC}"
fi

echo -e "${GREEN}Building ($REPO_ROLE, $COMPOSE_FILE)...${NC}"
if [ -z "$SERVICE" ] || [ "$SERVICE" == "--no-cache" ]; then
    docker compose -f "$COMPOSE_FILE" build $NO_CACHE_FLAG
else
    docker compose -f "$COMPOSE_FILE" build $NO_CACHE_FLAG "$SERVICE"
fi

echo -e "${GREEN}Cleaning up dangling images...${NC}"
docker images -f "dangling=true" -q | xargs -r docker rmi -f > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Build complete!${NC}"
docker system df
