#!/bin/bash
# Platform Engineers - Pull Submodules Script
# This script initializes and updates ALL submodules required by Platform Engineers

set -e

echo "🚀 Platform Engineers - Pulling Submodules"
echo "==========================================="
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/platform-engineers/pull_submodules.sh
# Need to go up 2 levels to reach repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Verify we're in a git repository
if [ ! -d "$REPO_ROOT/.git" ]; then
    echo "❌ Error: Not in a git repository!"
    echo "   Expected repo root: $REPO_ROOT"
    echo "   Please run this script from the Deepiri repository root"
    exit 1
fi

cd "$REPO_ROOT"

echo "📂 Repository root: $REPO_ROOT"
echo "   ✅ Confirmed: Git repository detected"
echo ""

# Pull latest main repo
echo "📥 Pulling latest main repository..."
git pull origin main || echo "⚠️  Could not pull main repo (may be on different branch)"
echo ""

# Platform Engineers need ALL submodules for platform management
echo "🔧 Initializing ALL submodules (Platform Engineers manage everything)..."
echo ""

# Ensure platform-services/backend directory exists
mkdir -p platform-services/backend

# Initialize all submodules
git submodule update --init --recursive
echo "    ✅ All submodules initialized"
echo ""

# Verify critical platform-services submodules are in correct locations
echo "🔍 Verifying submodule locations..."
if [ ! -d "platform-services/backend/deepiri-api-gateway/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-api-gateway not found at expected location"
fi
if [ ! -d "platform-services/backend/deepiri-auth-service/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-auth-service not found at expected location"
fi
if [ ! -d "platform-services/backend/deepiri-external-bridge-service/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-external-bridge-service not found at expected location"
fi
echo "    ✅ Verification complete"
echo ""

# Update to latest
echo "🔄 Updating all submodules to latest..."
git submodule update --remote --recursive
echo "    ✅ All submodules updated"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status
echo ""

echo "✅ Platform Engineers submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update all: git submodule update --remote --recursive"
echo "  - Sync all: git submodule foreach 'git checkout main && git pull'"
echo ""

