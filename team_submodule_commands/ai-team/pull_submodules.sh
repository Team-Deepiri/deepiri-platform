#!/bin/bash
# AI Team - Pull Submodules Script
# This script initializes and updates all submodules required by the AI Team

set -e

echo "🤖 AI Team - Pulling Submodules"
echo "================================"
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/ai-team/pull_submodules.sh
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

# AI Team required submodules
echo "🔧 Initializing AI Team submodules..."
echo ""

# diri-cyrex - AI/ML service
echo "  📦 diri-cyrex (AI/ML Service)..."
git submodule update --init --recursive diri-cyrex
echo "    ✅ diri-cyrex initialized"
echo ""

# Update to latest
echo "🔄 Updating submodules to latest..."
git submodule update --remote diri-cyrex
echo "    ✅ diri-cyrex updated"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status diri-cyrex
echo ""

echo "✅ AI Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status diri-cyrex"
echo "  - Update: git submodule update --remote diri-cyrex"
echo "  - Work in submodule: cd diri-cyrex"
echo ""

