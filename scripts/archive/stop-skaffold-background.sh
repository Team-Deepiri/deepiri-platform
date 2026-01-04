#!/bin/bash
# Stop Skaffold running in background

PID_FILE="skaffold.pid"
LOG_FILE="skaffold.log"

if [ ! -f "$PID_FILE" ]; then
    echo "⚠️  No PID file found. Skaffold may not be running in background."
    echo "   Trying to find and kill any running Skaffold processes..."
    pkill -f "skaffold dev" || echo "   No Skaffold processes found."
    exit 0
fi

SKAFFOLD_PID=$(cat "$PID_FILE")

if ! ps -p "$SKAFFOLD_PID" > /dev/null 2>&1; then
    echo "⚠️  Process $SKAFFOLD_PID is not running. Cleaning up PID file."
    rm -f "$PID_FILE"
    exit 0
fi

echo "🛑 Stopping Skaffold (PID: $SKAFFOLD_PID)..."

# Send SIGTERM first (graceful shutdown)
kill "$SKAFFOLD_PID" 2>/dev/null

# Wait a bit
sleep 2

# Check if still running
if ps -p "$SKAFFOLD_PID" > /dev/null 2>&1; then
    echo "⚠️  Process still running, sending SIGKILL..."
    kill -9 "$SKAFFOLD_PID" 2>/dev/null
    sleep 1
fi

# Cleanup
rm -f "$PID_FILE"

# Also kill any remaining skaffold processes
pkill -f "skaffold dev" 2>/dev/null || true

echo "✅ Skaffold stopped"
echo ""
echo "💡 Note: Kubernetes resources are still running."
echo "   To clean up: skaffold delete -f skaffold-local.yaml"
echo "   Or: ./scripts/stop-skaffold.sh"

