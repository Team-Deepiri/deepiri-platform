#!/bin/bash
# AI Team - Restart script
# Restarts AI/ML services by stopping then starting them

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔄 Restarting AI Team services..."
echo ""

# Stop services first
echo "Step 1: Stopping services..."
"$SCRIPT_DIR/stop.sh"

echo ""
echo "Step 2: Starting services..."
"$SCRIPT_DIR/start.sh"

echo ""
echo "✅ AI Team services restarted!"

