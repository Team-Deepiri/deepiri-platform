#!/bin/bash

# Nuke All Docker Volumes Script
# WARNING: This will delete ALL Docker volumes, including your database data!
# Usage: ./nuke_volumes.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  NUKE ALL DOCKER VOLUMES ⚠️        ║${NC}"
echo -e "${RED}╚════════════════════════════════════════╝${NC}"
echo ""

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    exit 1
fi

# List current volumes
echo -e "${YELLOW}📦 Current Docker volumes:${NC}"
docker volume ls
echo ""

# Count volumes
VOLUME_COUNT=$(docker volume ls -q | wc -l)
if [ "$VOLUME_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ No volumes found. Nothing to delete.${NC}"
    exit 0
fi

echo -e "${RED}⚠️  WARNING: This will delete ALL $VOLUME_COUNT volumes!${NC}"
echo -e "${RED}   This includes:${NC}"
echo -e "${RED}   - MongoDB data${NC}"
echo -e "${RED}   - Redis data${NC}"
echo -e "${RED}   - InfluxDB data${NC}"
echo -e "${RED}   - MLflow data${NC}"
echo -e "${RED}   - All other volume data${NC}"
echo ""
read -p "Are you absolutely sure? Type 'NUKE' to confirm: " confirm

if [ "$confirm" != "NUKE" ]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}🗑️  Removing all volumes...${NC}"

# Remove all volumes
docker volume ls -q | xargs -r docker volume rm

echo ""
echo -e "${GREEN}✅ All volumes deleted!${NC}"
echo ""
echo -e "${YELLOW}📦 Remaining volumes:${NC}"
docker volume ls

