#!/bin/bash
# Smart Docker Compose Startup Script
# Checks for port conflicts and cleans up failed containers before starting
# Usage: ./start-services.sh [--compose-file docker-compose.dev.yml] [--skip-checks]

set -e

COMPOSE_FILE="docker-compose.dev.yml"
SKIP_CHECKS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --compose-file|-c)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        --skip-checks|-s)
            SKIP_CHECKS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_PATH="$REPO_ROOT/$COMPOSE_FILE"

if [ ! -f "$COMPOSE_PATH" ]; then
    echo "[ERROR] Compose file not found: $COMPOSE_PATH" >&2
    exit 1
fi

echo "=========================================="
echo "Smart Docker Services Startup"
echo "=========================================="
echo ""

if [ "$SKIP_CHECKS" = false ]; then
    # Step 1: Check for failed containers (Created but not running)
    echo "Step 1: Checking for failed containers..."
    FAILED_CONTAINERS=$(docker ps -a --filter "status=created" --filter "name=deepiri" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$FAILED_CONTAINERS" ]; then
        echo "Found failed containers (Created but not running):"
        echo "$FAILED_CONTAINERS" | while read -r container; do
            if [ -n "$container" ]; then
                echo "  - $container"
            fi
        done
        echo ""
        echo "Removing failed containers..."
        echo "$FAILED_CONTAINERS" | while read -r container; do
            if [ -n "$container" ]; then
                docker rm -f "$container" 2>/dev/null && echo "  [OK] Removed $container"
            fi
        done
        echo ""
    else
        echo "[OK] No failed containers found"
        echo ""
    fi

    # Step 2: Check for port conflicts
    echo "Step 2: Checking for port conflicts..."
    PORT_CHECK_SCRIPT="$SCRIPT_DIR/check-port-conflicts.sh"
    if [ -f "$PORT_CHECK_SCRIPT" ]; then
        if $PORT_CHECK_SCRIPT 2>&1; then
            echo "[OK] No port conflicts detected"
        else
            echo "[ERROR] Port conflicts detected!" >&2
            echo ""
            echo "Please resolve port conflicts before starting services."
            echo "Run: ./check-port-conflicts.sh --kill"
            exit 1
        fi
        echo ""
    else
        echo "[WARNING] Port conflict checker not found, skipping port check"
        echo ""
    fi
else
    echo "[SKIP] Pre-startup checks skipped (--skip-checks specified)"
    echo ""
fi

# Step 3: Start services
echo "Step 3: Starting Docker services..."
echo ""

cd "$REPO_ROOT"
docker compose -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Services started successfully!"
    echo "=========================================="
    echo ""
    echo "To view logs:"
    echo "  docker compose -f $COMPOSE_FILE logs -f"
    echo ""
    echo "To check status:"
    echo "  docker compose -f $COMPOSE_FILE ps"
else
    echo "[ERROR] Failed to start services" >&2
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check for port conflicts: ./check-port-conflicts.sh"
    echo "  2. Check Docker logs: docker compose -f $COMPOSE_FILE logs"
    echo "  3. Try starting individual services: docker compose -f $COMPOSE_FILE up -d <service-name>"
    exit 1
fi

