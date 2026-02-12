#!/bin/bash
# Remove Dangling/Untagged Docker Images
# Purpose: Quickly remove all untagged (<none>) Docker images to free up space
# Run this regularly to prevent buildup of dangling images
#
# Usage:
#   1. Make executable: chmod +x remove-dangling-images.sh
#   2. Navigate to the deepiri/scripts directory: cd deepiri/scripts
#   3. Run the script: ./remove-dangling-images.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Remove Dangling Docker Images${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if Docker is available
echo -e "${YELLOW}Checking Docker availability...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] Docker is not accessible${NC}"
    echo -e "${YELLOW}Please ensure Docker is running${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Docker is running${NC}"
echo ""

# Show current disk usage
echo -e "${YELLOW}Current Docker disk usage:${NC}"
docker system df
echo ""

# Get list of dangling images
echo -e "${YELLOW}Finding dangling (untagged) images...${NC}"
danglingImages=$(docker images -f "dangling=true" -q)

if [ -z "$danglingImages" ]; then
    echo -e "${GREEN}[OK] No dangling images found!${NC}"
    echo ""
    exit 0
fi

# Count images
imageCount=$(echo "$danglingImages" | wc -l)
echo -e "${CYAN}Found $imageCount dangling image(s)${NC}"
echo ""

# Ask for confirmation
echo -e -n "${YELLOW}Do you want to remove these images? (Y/N): ${NC}"
read -r confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Removing dangling images...${NC}"

# Remove dangling images
echo "$danglingImages" | xargs -r docker rmi -f > /dev/null 2>&1

echo -e "${GREEN}[OK] Dangling images removed${NC}"
echo ""

# Show updated disk usage
echo -e "${YELLOW}Updated Docker disk usage:${NC}"
docker system df
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Note: To reclaim space in your filesystem, you may need to run cleanup-and-compact${NC}"
echo ""

