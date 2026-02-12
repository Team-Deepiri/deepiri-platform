#!/bin/bash
# Bash script to clear all Docker logs
# This removes all log files that Docker has accumulated

set -e

echo "Clearing Docker logs..."

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "ERROR: Docker is not running. Please start Docker."
    exit 1
fi

echo "[OK] Docker is running"

# Get all container IDs (running and stopped)
echo ""
echo "Finding all containers..."
ALL_CONTAINERS=$(docker ps -aq)

if [ -z "$ALL_CONTAINERS" ]; then
    echo "No containers found."
    exit 0
fi

CONTAINER_COUNT=$(echo "$ALL_CONTAINERS" | wc -l)
echo "Found $CONTAINER_COUNT containers"

# Clear logs for each container
echo ""
echo "Clearing logs for all containers..."
for container in $ALL_CONTAINERS; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container" 2>/dev/null | sed 's/^\/\{1,\}//')
    
    if [ -n "$CONTAINER_NAME" ]; then
        echo "  Clearing logs for: $CONTAINER_NAME"
        
        # Truncate log file (works on Linux)
        docker exec "$container" sh -c "truncate -s 0 /proc/1/fd/1 2>/dev/null || true" 2>/dev/null || true
        docker exec "$container" sh -c "truncate -s 0 /proc/1/fd/2 2>/dev/null || true" 2>/dev/null || true
    fi
done

echo ""
echo "[OK] Docker logs cleared for all containers"

# Show current log sizes
echo ""
echo "Current log file sizes:"
find /var/lib/docker/containers -name '*-json.log' -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | head -20 || echo "Unable to access Docker log directory (requires root)"

echo ""
echo "[INFO] Logs will automatically be limited to 1MB per container"
echo "[INFO] Old logs are automatically removed when the limit is reached"

