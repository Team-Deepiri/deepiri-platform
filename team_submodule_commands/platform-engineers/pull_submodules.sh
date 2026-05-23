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

# Helper function retained for older script flow. Submodule checkout stays pinned to the platform commit.
ensure_submodule_on_main() {
    local submodule_path="$1"
    echo "    📌 Leaving $submodule_path at the platform-pinned commit"
    return 0
}

# Keep the platform checkout as the source of truth.
# Do not auto-pull the parent repo here; onboarding may be running from a feature branch.
echo "📌 Using current platform checkout: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
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
if [ ! -d "platform-services/shared/deepiri-prismpipe/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-prismpipe not found at expected location"
fi
if [ ! -d "platform-services/shared/deepiri-synapse/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-synapse not found at expected location"
fi
if [ ! -d "platform-services/shared/deepiri-sugar-glider/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-sugar-glider not found at expected location"
fi
echo "    ✅ Verification complete"
echo ""

# Initialize submodules at platform-pinned commits
echo "🔄 Initializing all submodules at platform-pinned commits..."
git submodule update --init --recursive
echo "    🔄 Leaving all submodules at platform-pinned commits..."
echo "    📌 Submodules left at platform-pinned commits"
echo "    ✅ All submodules initialized at platform-pinned commits"
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
echo "  - Update all: git submodule update --init --recursive"
echo "  - Sync all: git submodule sync --recursive"
echo "  - Work in PrismPipe: cd platform-services/shared/deepiri-prismpipe"
echo "  - Work in Synapse: cd platform-services/shared/deepiri-synapse"
echo "  - Work in Sugar Glider: cd platform-services/shared/deepiri-sugar-glider"
echo ""

# deepiri-suite (base images for Docker builds)
echo "🔄 Initializing deepiri-suite submodule..."
git submodule update --init deepiri-suite 2>&1 && echo "   ✅ deepiri-suite ready" || echo "   ⚠️  deepiri-suite init failed — local Docker image builds may fall back to GHCR"
echo ""

# Automatically run setup-hooks.sh after pulling submodules
echo "🔧 Setting up Git hooks for pulled submodules..."
echo ""
if [ -f "$SCRIPT_DIR/setup-hooks.sh" ]; then
    bash "$SCRIPT_DIR/setup-hooks.sh"
else
    echo "⚠️  Warning: setup-hooks.sh not found at $SCRIPT_DIR/setup-hooks.sh"
    echo "   Hooks will not be automatically configured."
fi
echo ""
