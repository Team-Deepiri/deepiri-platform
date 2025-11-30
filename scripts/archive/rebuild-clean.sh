#!/bin/bash

# Deepiri Clean Rebuild Script (Bash)
# Removes old images BEFORE rebuilding to prevent storage bloat
# Usage: ./rebuild-clean.sh [docker-compose-file] [service-name]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

COMPOSE_FILE="${1:-docker-compose.dev.yml}"
SERVICE="${2:-}"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Deepiri Clean Rebuild Script${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check Docker
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    exit 1
fi

# Show disk usage before
echo -e "${YELLOW}📊 Docker disk usage BEFORE:${NC}"
docker system df
echo ""

# Step 1: Stop containers
echo -e "${YELLOW}[1/4] Stopping containers...${NC}"
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
echo -e "${GREEN}✅ Containers stopped${NC}"
echo ""

# Step 2: Remove old images
echo -e "${YELLOW}[2/4] Removing old Deepiri images...${NC}"

REMOVED_COUNT=0

# Get all images and filter for deepiri images
ALL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" 2>/dev/null || true)

if [ -n "$ALL_IMAGES" ]; then
    echo "$ALL_IMAGES" | while read -r line; do
        if [ -n "$line" ]; then
            IMAGE_NAME=$(echo "$line" | awk '{print $1}')
            IMAGE_ID=$(echo "$line" | awk '{print $2}')
            
            # Remove images that match deepiri but skip base images
            if echo "$IMAGE_NAME" | grep -q "deepiri" && \
               ! echo "$IMAGE_NAME" | grep -qE "^(node|python|mongo|redis|influxdb|prometheus|grafana|mlflow|mongo-express|ghcr.io)"; then
                echo "  Removing: $IMAGE_NAME"
                docker rmi -f "$IMAGE_ID" 2>/dev/null || true
            fi
        fi
    done
fi

# Remove dangling images
echo -e "${YELLOW}  Removing dangling images...${NC}"
docker image prune -f 2>/dev/null || true

echo -e "${GREEN}✅ Old images removed${NC}"
echo ""

# Step 3: Clean build cache
echo -e "${YELLOW}[3/4] Cleaning Docker build cache...${NC}"
docker builder prune -af
echo -e "${GREEN}✅ Build cache cleaned${NC}"
echo ""

# Step 4: Rebuild
echo -e "${YELLOW}[4/4] Rebuilding containers...${NC}"
if [ -n "$SERVICE" ]; then
    echo -e "${CYAN}  Building service: $SERVICE${NC}"
    docker-compose -f "$COMPOSE_FILE" build --no-cache "$SERVICE"
else
    echo -e "${CYAN}  Building all services${NC}"
    docker-compose -f "$COMPOSE_FILE" build --no-cache
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Containers rebuilt${NC}"
echo ""

# Clean build cache again
echo -e "${YELLOW}Cleaning build cache after build...${NC}"
docker builder prune -af
echo ""

# Show final disk usage
echo -e "${YELLOW}📊 Docker disk usage AFTER:${NC}"
docker system df
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Clean Rebuild Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}To start services:${NC}"
echo "  docker-compose -f $COMPOSE_FILE up -d"
echo ""

