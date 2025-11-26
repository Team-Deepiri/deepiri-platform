#!/bin/bash
# Frontend Team - Pull Submodules Script
# This script initializes and updates all submodules required by the Frontend Team

set -e

echo "🎨 Frontend Team - Pulling Submodules"
echo "====================================="
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/frontend-team/pull_submodules.sh
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

# Frontend Team required submodules
echo "🔧 Initializing Frontend Team submodules..."
echo ""

# deepiri-web-frontend
echo "  📦 deepiri-web-frontend (Web Frontend)..."
git submodule update --init --recursive deepiri-web-frontend
echo "    ✅ web-frontend initialized"
echo ""

# deepiri-auth-service
echo "  📦 deepiri-auth-service (Auth Service)..."
git submodule update --init --recursive platform-services/backend/deepiri-auth-service
echo "    ✅ auth-service initialized at: $(pwd)/platform-services/backend/deepiri-auth-service"
echo ""

# Update to latest
echo "🔄 Updating submodules to latest..."
git submodule update --remote deepiri-web-frontend
git submodule update --remote platform-services/backend/deepiri-auth-service
echo "    ✅ completed"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status deepiri-web-frontend
echo ""

echo "✅ Frontend Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status deepiri-web-frontend"
echo "  - Update: git submodule update --remote deepiri-web-frontend"
echo "  - Work in submodule: cd deepiri-web-frontend"
echo "  - Install deps: cd deepiri-web-frontend && npm install"
echo ""