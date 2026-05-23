#!/bin/bash

# Deepiri Complete Rebuild Script
# This script: Stops containers → Removes old images → Rebuilds → Starts everything
# Perfect for when you have ~50GB of old Docker images and want a fresh start
# Usage: ./rebuild-fresh.sh [docker-compose-file]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

COMPOSE_FILE="${1:-docker-compose.dev.yml}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Deepiri Complete Rebuild Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check Docker
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    exit 1
fi

# Step 1: Show current disk usage
echo -e "${CYAN}📊 Current Docker disk usage:${NC}"
docker system df
echo ""

# Step 2: Stop all containers
echo -e "${YELLOW}[1/5] Stopping all containers...${NC}"
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
echo -e "${GREEN}✅ Containers stopped${NC}"
echo ""

# Step 3: Remove old images (keep base images like node, redis, etc.)
echo -e "${YELLOW}[2/5] Removing old Deepiri images (keeping base images)...${NC}"
DEEPIRI_IMAGES=$(docker images --filter "reference=deepiri-dev-*" --format "{{.ID}}" 2>/dev/null || true)
if [ -n "$DEEPIRI_IMAGES" ]; then
    echo "$DEEPIRI_IMAGES" | xargs -r docker rmi -f 2>/dev/null || true
    echo -e "${GREEN}✅ Old Deepiri images removed${NC}"
else
    echo -e "${GREEN}✅ No old Deepiri images found${NC}"
fi
echo ""

# Step 4: Clean build cache
echo -e "${YELLOW}[3/5] Cleaning Docker build cache...${NC}"
docker builder prune -a -f
echo -e "${GREEN}✅ Build cache cleaned${NC}"
echo ""

# Step 5: Rebuild everything (no cache)
echo -e "${YELLOW}[4/5] Rebuilding all containers (this will take a while)...${NC}"
echo -e "${CYAN}   Using compose file: $COMPOSE_FILE${NC}"
docker-compose -f "$COMPOSE_FILE" build --no-cache
echo -e "${GREEN}✅ All containers rebuilt${NC}"
echo ""

# Step 6: Start everything
echo -e "${YELLOW}[5/5] Starting all services...${NC}"
docker-compose -f "$COMPOSE_FILE" up -d
echo -e "${GREEN}✅ All services started${NC}"
echo ""

# Final disk usage
echo -e "${CYAN}📊 Final Docker disk usage:${NC}"
docker system df
echo ""

# Show running containers
echo -e "${CYAN}🐳 Running containers:${NC}"
docker-compose -f "$COMPOSE_FILE" ps
echo ""

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Rebuild Complete!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}View logs:${NC} docker-compose -f $COMPOSE_FILE logs -f"
echo -e "${CYAN}Stop all:${NC} docker-compose -f $COMPOSE_FILE down"

