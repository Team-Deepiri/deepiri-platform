#!/bin/bash

# Deepiri Docker Stop and Cleanup Script
# This script stops all containers and cleans up Docker resources
# Usage: ./stop-and-cleanup.sh [--keep-volumes] [--keep-images]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
KEEP_VOLUMES=false
KEEP_IMAGES=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --keep-volumes)
      KEEP_VOLUMES=true
      shift
      ;;
    --keep-images)
      KEEP_IMAGES=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--keep-volumes] [--keep-images]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deepiri Docker Stop and Cleanup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if Docker is running
check_docker() {
  if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running or not accessible${NC}"
    exit 1
  fi
}

# Function to stop all containers
stop_containers() {
  echo -e "${YELLOW}Stopping all Deepiri containers...${NC}"
  
  # Stop all containers with deepiri in the name
  CONTAINERS=$(docker ps -a --filter "name=deepiri" --format "{{.Names}}" 2>/dev/null || true)
  
  if [ -z "$CONTAINERS" ]; then
    echo -e "${GREEN}No Deepiri containers found${NC}"
  else
    echo "$CONTAINERS" | while read -r container; do
      if [ ! -z "$container" ]; then
        echo -e "  Stopping: ${BLUE}$container${NC}"
        docker stop "$container" > /dev/null 2>&1 || true
      fi
    done
    
    # Also stop any containers started by docker-compose
    echo -e "${YELLOW}Stopping docker-compose services...${NC}"
    docker-compose -f docker-compose.yml down 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml down 2>/dev/null || true
    docker-compose -f docker-compose.microservices.yml down 2>/dev/null || true
    docker-compose -f docker-compose.enhanced.yml down 2>/dev/null || true
    
    echo -e "${GREEN}✓ All containers stopped${NC}"
  fi
}

# Function to remove containers
remove_containers() {
  echo -e "${YELLOW}Removing all Deepiri containers...${NC}"
  
  CONTAINERS=$(docker ps -a --filter "name=deepiri" --format "{{.Names}}" 2>/dev/null || true)
  
  if [ -z "$CONTAINERS" ]; then
    echo -e "${GREEN}No Deepiri containers to remove${NC}"
  else
    echo "$CONTAINERS" | while read -r container; do
      if [ ! -z "$container" ]; then
        echo -e "  Removing: ${BLUE}$container${NC}"
        docker rm -f "$container" > /dev/null 2>&1 || true
      fi
    done
    
    echo -e "${GREEN}✓ All containers removed${NC}"
  fi
}

# Function to remove images
remove_images() {
  if [ "$KEEP_IMAGES" = true ]; then
    echo -e "${YELLOW}Skipping image removal (--keep-images flag set)${NC}"
    return
  fi
  
  echo -e "${YELLOW}Removing Deepiri images...${NC}"
  
  # Remove images with deepiri in the name
  IMAGES=$(docker images --filter "reference=*deepiri*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
  
  if [ -z "$IMAGES" ]; then
    echo -e "${GREEN}No Deepiri images found${NC}"
  else
    echo "$IMAGES" | while read -r image; do
      if [ ! -z "$image" ]; then
        echo -e "  Removing: ${BLUE}$image${NC}"
        docker rmi -f "$image" > /dev/null 2>&1 || true
      fi
    done
    
    echo -e "${GREEN}✓ Images removed${NC}"
  fi
  
  # Also remove dangling images
  echo -e "${YELLOW}Removing dangling images...${NC}"
  DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null || true)
  if [ ! -z "$DANGLING" ]; then
    docker rmi -f $DANGLING > /dev/null 2>&1 || true
    echo -e "${GREEN}✓ Dangling images removed${NC}"
  else
    echo -e "${GREEN}No dangling images found${NC}"
  fi
}

# Function to remove volumes
remove_volumes() {
  if [ "$KEEP_VOLUMES" = true ]; then
    echo -e "${YELLOW}Skipping volume removal (--keep-volumes flag set)${NC}"
    return
  fi
  
  echo -e "${YELLOW}Removing unused volumes...${NC}"
  
  # Remove volumes with deepiri in the name
  VOLUMES=$(docker volume ls --filter "name=deepiri" --format "{{.Name}}" 2>/dev/null || true)
  
  if [ -z "$VOLUMES" ]; then
    echo -e "${GREEN}No Deepiri volumes found${NC}"
  else
    echo "$VOLUMES" | while read -r volume; do
      if [ ! -z "$volume" ]; then
        echo -e "  Removing: ${BLUE}$volume${NC}"
        docker volume rm "$volume" > /dev/null 2>&1 || true
      fi
    done
    
    echo -e "${GREEN}✓ Volumes removed${NC}"
  fi
  
  # Remove all unused volumes (not just deepiri)
  echo -e "${YELLOW}Removing all unused volumes...${NC}"
  docker volume prune -f > /dev/null 2>&1 || true
  echo -e "${GREEN}✓ Unused volumes pruned${NC}"
}

# Function to clean build cache
clean_build_cache() {
  echo -e "${YELLOW}Cleaning Docker build cache...${NC}"
  docker builder prune -af > /dev/null 2>&1 || true
  echo -e "${GREEN}✓ Build cache cleaned${NC}"
}

# Function to remove networks
remove_networks() {
  echo -e "${YELLOW}Removing Deepiri networks...${NC}"
  
  NETWORKS=$(docker network ls --filter "name=deepiri" --format "{{.Name}}" 2>/dev/null || true)
  
  if [ -z "$NETWORKS" ]; then
    echo -e "${GREEN}No Deepiri networks found${NC}"
  else
    echo "$NETWORKS" | while read -r network; do
      if [ ! -z "$network" ] && [ "$network" != "deepiri-network" ] && [ "$network" != "deepiri-dev-network" ]; then
        echo -e "  Removing: ${BLUE}$network${NC}"
        docker network rm "$network" > /dev/null 2>&1 || true
      fi
    done
    
    # Remove the main networks if no containers are using them
    for network in deepiri-network deepiri-dev-network; do
      if docker network inspect "$network" > /dev/null 2>&1; then
        CONTAINERS_IN_NETWORK=$(docker network inspect "$network" --format '{{len .Containers}}' 2>/dev/null || echo "0")
        if [ "$CONTAINERS_IN_NETWORK" = "0" ]; then
          echo -e "  Removing: ${BLUE}$network${NC}"
          docker network rm "$network" > /dev/null 2>&1 || true
        fi
      fi
    done
    
    echo -e "${GREEN}✓ Networks removed${NC}"
  fi
}

# Function to show disk usage before and after
show_disk_usage() {
  echo ""
  echo -e "${BLUE}Docker Disk Usage:${NC}"
  docker system df
  echo ""
}

# Main execution
main() {
  check_docker
  
  echo -e "${YELLOW}Current Docker disk usage:${NC}"
  show_disk_usage
  
  # Confirm before proceeding
  if [ "$KEEP_VOLUMES" = false ] || [ "$KEEP_IMAGES" = false ]; then
    echo -e "${RED}WARNING: This will remove Docker resources!${NC}"
    if [ "$KEEP_VOLUMES" = false ]; then
      echo -e "${RED}  - All volumes will be removed${NC}"
    fi
    if [ "$KEEP_IMAGES" = false ]; then
      echo -e "${RED}  - All images will be removed${NC}"
    fi
    echo -e "${RED}  - Build cache will be cleared${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Aborted${NC}"
      exit 0
    fi
  fi
  
  echo ""
  
  # Execute cleanup steps
  stop_containers
  remove_containers
  remove_images
  remove_volumes
  clean_build_cache
  remove_networks
  
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Cleanup Complete!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  
  echo -e "${YELLOW}Final Docker disk usage:${NC}"
  show_disk_usage
  
  echo -e "${GREEN}All Deepiri Docker resources have been cleaned up!${NC}"
}

# Run main function
main

