#!/bin/bash
# Infrastructure Team - Pull Submodules Script
# This script initializes and updates all submodules required by the Infrastructure Team

set -e

echo "🏗️  Infrastructure Team - Pulling Submodules"
echo "============================================="
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/infrastructure-team/pull_submodules.sh
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

# Infrastructure Team required submodules
echo "🔧 Initializing Infrastructure Team submodules..."
echo ""

# Ensure platform-services/backend directory exists
mkdir -p platform-services/backend

# deepiri-api-gateway
echo "  📦 deepiri-api-gateway (API Gateway)..."
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
if [ ! -d "platform-services/backend/deepiri-api-gateway/.git" ]; then
    echo "    ❌ ERROR: deepiri-api-gateway not cloned correctly!"
    exit 1
fi
echo "    ✅ api-gateway initialized at: $(pwd)/platform-services/backend/deepiri-api-gateway"
echo ""

# deepiri-external-bridge-service
echo "  📦 deepiri-external-bridge-service (External Bridge)..."
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
if [ ! -d "platform-services/backend/deepiri-external-bridge-service/.git" ]; then
    echo "    ❌ ERROR: deepiri-external-bridge-service not cloned correctly!"
    exit 1
fi
echo "    ✅ external-bridge-service initialized at: $(pwd)/platform-services/backend/deepiri-external-bridge-service"
echo ""

# Update to latest
echo "🔄 Updating submodules to latest..."
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
echo "    ✅ All infrastructure submodules updated"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status platform-services/backend/deepiri-external-bridge-service
echo ""

echo "✅ Infrastructure Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update: git submodule update --remote platform-services/backend/deepiri-api-gateway"
echo "  - Work in API Gateway: cd platform-services/backend/deepiri-api-gateway"
echo ""

