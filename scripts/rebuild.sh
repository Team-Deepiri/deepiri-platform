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

# Test if docker command works, fallback to .exe if needed
if ! command -v $DOCKER_CMD &> /dev/null; then
    if [[ "$DOCKER_CMD" == "docker" ]]; then
        if command -v docker.exe &> /dev/null; then
            DOCKER_CMD="docker.exe"
            echo "🔍 docker not found, using docker.exe"
        else
            echo "❌ Error: docker or docker.exe not found. Please install Docker." >&2
            exit 1
        fi
    fi
fi

# Test if docker daemon is accessible
if ! $DOCKER_CMD ps &> /dev/null; then
    echo "❌ Error: Cannot connect to Docker daemon. Is Docker running?" >&2
    exit 1
fi

# Test docker-compose command
if [[ "$COMPOSE_CMD" == "docker compose" ]]; then
    if ! $DOCKER_CMD compose version &> /dev/null; then
        # Try docker-compose.exe as fallback
        if command -v docker-compose.exe &> /dev/null; then
            COMPOSE_CMD="docker-compose.exe"
            echo "🔍 docker compose not available, using docker-compose.exe"
        elif command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
            echo "🔍 docker compose not available, using docker-compose"
        else
            echo "⚠️  Warning: docker compose not available, but continuing..."
        fi
    fi
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
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup .dev_venv if it doesn't exist (one level above deepiri)
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PATH="$PARENT_DIR/.dev_venv"
if [ ! -d "$VENV_PATH" ]; then
    echo "🔧 Setting up .dev_venv for faster builds..."
    if [ -f "$SCRIPT_DIR/scripts/setup-dev-venv.sh" ]; then
        bash "$SCRIPT_DIR/scripts/setup-dev-venv.sh"
    else
        echo "⚠️  Warning: setup-dev-venv.sh not found, skipping venv setup"
    fi
fi

# Note: Docker builds use prebuilt images and downloaded packages
# No need to export from host venv - builds are self-contained

# Build cyrex and jupyter with auto GPU detection (uses prebuilt, fastest)
echo "🤖 Building cyrex and jupyter with auto GPU detection..."
if [ -f "$SCRIPT_DIR/scripts/build-cyrex-auto.sh" ]; then
    bash "$SCRIPT_DIR/scripts/build-cyrex-auto.sh" all
else
    echo "⚠️  Warning: build-cyrex-auto.sh not found, falling back to standard build"
    if [[ "$COMPOSE_CMD" == "docker-compose.exe" ]]; then
        $COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache --pull cyrex jupyter
    else
        $COMPOSE_CMD -f "$COMPOSE_FILE" build --no-cache --pull cyrex jupyter
    fi
fi

echo ""
echo "🔨 Building other services..."
# Build other services (excluding cyrex and jupyter which were already built)
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
