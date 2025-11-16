#!/bin/bash

# Deepiri Clean Rebuild Script
# Removes old images, rebuilds fresh, and starts services
# Usage: ./rebuild.sh [docker-compose-file]

set -e

COMPOSE_FILE="${1:-docker-compose.dev.yml}"

# Detect WSL and use .exe versions if needed
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null || [[ -n "$WSL_DISTRO_NAME" ]]; then
    DOCKER_CMD="docker.exe"
    COMPOSE_CMD="docker-compose.exe"
    echo "🔍 WSL detected - using docker.exe and docker-compose.exe"
else
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker compose"
fi

npm pkg set BUILD_TIMESTAMP=$(date +%s) &>/dev/null || true

export BUILD_TIMESTAMP=$(date +%s)

echo "🧹 Stopping containers and removing old images..."
if [[ "$COMPOSE_CMD" == "docker-compose.exe" ]]; then
    $COMPOSE_CMD -f "$COMPOSE_FILE" down --rmi all --volumes --remove-orphans
else
    $COMPOSE_CMD -f "$COMPOSE_FILE" down --rmi all --volumes --remove-orphans
fi

echo "🔨 Rebuilding containers (no cache)..."
if [[ "$COMPOSE_CMD" == "docker-compose.exe" ]]; then
    $COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache --pull
else
    $COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache --pull
fi

echo "🚀 Starting services..."
if [[ "$COMPOSE_CMD" == "docker-compose.exe" ]]; then
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
else
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
fi

echo "✅ Rebuild complete!"
echo ""
echo "View logs: $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
echo "Check status: $COMPOSE_CMD -f $COMPOSE_FILE ps"
