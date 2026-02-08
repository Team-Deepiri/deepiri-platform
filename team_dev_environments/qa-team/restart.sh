#!/bin/bash
# QA Team - Restart script
# Restarts QA services by stopping then starting them

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔄 Restarting QA Team services..."
echo ""

# Stop services first
echo "Step 1: Stopping services..."
"$SCRIPT_DIR/stop.sh"

echo ""
echo "Step 2: Starting services..."
"$SCRIPT_DIR/start.sh"

echo ""
echo "✅ QA Team services restarted!"

