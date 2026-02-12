#!/usr/bin/env bash
# Deepiri Docker Cleanup (macOS) - remove all containers and images
# Improved CLI output

set -euo pipefail

# Function to print colored output
function echo_color() {
    local color=$1
    shift
    case $color in
        red)    printf "\033[0;31m%s\033[0m\n" "$*";;
        green)  printf "\033[0;32m%s\033[0m\n" "$*";;
        yellow) printf "\033[1;33m%s\033[0m\n" "$*";;
        cyan)   printf "\033[0;36m%s\033[0m\n" "$*";;
        *)      printf "%s\n" "$*";;
    esac
}

echo_color cyan "=========================================="
echo_color cyan "Deepiri Docker Cleanup (macOS)"
echo_color cyan "=========================================="
echo ""

# Check Docker availability
echo_color yellow "[INFO] Checking Docker availability..."
if ! command -v docker &>/dev/null; then
    echo_color red "[ERROR] Docker is not installed or not in PATH."
    exit 1
fi
echo_color green "[OK] Docker is available"
echo ""

# Step 1: Show current Docker disk usage
echo_color yellow "[INFO] Current Docker disk usage:"
docker system df
echo ""

# Step 2: Stop and remove all containers
echo_color yellow "[INFO] Stopping and removing all Docker containers..."
containers=$(docker ps -a -q)
if [[ -n "$containers" ]]; then
    while IFS= read -r container; do
        echo_color yellow "  Stopping container: $container"
        docker stop "$container" || true
        echo_color yellow "  Removing container: $container"
        docker rm "$container" || true
    done <<< "$containers"
    echo_color green "[OK] All containers stopped and removed"
else
    echo_color green "[INFO] No containers found"
fi
echo ""

# Step 3: Remove all Docker images
echo_color yellow "[INFO] Removing all Docker images..."
images=$(docker images -q)
if [[ -n "$images" ]]; then
    for image in $images; do
        echo_color yellow "  Removing image: $image"
        docker rmi -f "$image" || true
    done
    echo_color green "[OK] All Docker images removed"
else
    echo_color green "[INFO] No Docker images found"
fi
echo ""

# Step 4: Optional - prune volumes, networks, build cache
echo_color yellow "[INFO] Pruning unused Docker volumes, networks, and build cache..."
docker volume prune -f || true
docker network prune -f || true
docker builder prune -af || true
echo_color green "[OK] Docker prune complete"
echo ""

# Step 5: Show Docker disk usage after cleanup
echo_color yellow "[INFO] Docker disk usage after cleanup:"
docker system df
echo ""

# Final summary
echo_color cyan "=========================================="
echo_color cyan "Deepiri Docker cleanup complete!"
echo_color cyan "=========================================="
echo ""
echo_color green "[OK] All containers removed"
echo_color green "[OK] All images removed"
echo_color green "[OK] Unused volumes, networks, and build cache pruned"
echo_color cyan "Please restart Docker Desktop manually if needed"
echo ""
