#!/bin/bash
# Start Skaffold in the background

LOG_FILE="skaffold.log"
PID_FILE="skaffold.pid"

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "⚠️  Skaffold is already running (PID: $OLD_PID)"
        echo "   To stop it: ./scripts/stop-skaffold-background.sh"
        echo "   To view logs: tail -f $LOG_FILE"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

echo "🚀 Starting Skaffold in background..."
echo "   Logs will be written to: $LOG_FILE"
echo "   PID will be saved to: $PID_FILE"
echo ""

# Start Skaffold in background
nohup skaffold dev -f skaffold-local.yaml --port-forward > "$LOG_FILE" 2>&1 &
SKAFFOLD_PID=$!

# Save PID
echo $SKAFFOLD_PID > "$PID_FILE"

echo "✅ Skaffold started in background (PID: $SKAFFOLD_PID)"
echo ""
echo "📋 Useful commands:"
echo "   View logs:        tail -f $LOG_FILE"
echo "   Follow logs:      tail -f $LOG_FILE | grep -i error"
echo "   Check status:     ps aux | grep skaffold"
echo "   Stop Skaffold:    ./scripts/stop-skaffold-background.sh"
echo "   Or manually:      kill $SKAFFOLD_PID"
echo ""

