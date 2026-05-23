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

# Helper function to check if submodule is valid (handles both .git directory and .git file)
check_submodule() {
    local submodule_path="$1"
    if [ ! -d "$submodule_path" ]; then
        return 1
    fi
    if [ ! -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
        return 1
    fi
    if ! (cd "$submodule_path" && git rev-parse --git-dir > /dev/null 2>&1); then
        return 1
    fi
    return 0
}

# Helper function to clean up invalid submodule directory
cleanup_invalid_submodule() {
    local submodule_path="$1"
    if [ -d "$submodule_path" ] && ! check_submodule "$submodule_path"; then
        echo "    ⚠️  Directory exists but is not a valid submodule. Cleaning up..."
        rm -rf "$submodule_path"
        echo "    ✅ Cleaned up invalid directory"
    fi
}

# Helper function to ensure submodule is on main branch and tracking it
ensure_submodule_on_main() {
    local submodule_path="$1"
    if [ ! -d "$submodule_path" ]; then
        return 1
    fi
    
    cd "$submodule_path" || return 1
    
    # Fetch latest changes
    git fetch origin 2>/dev/null || true
    
    # Determine which branch to use (main or master)
    local branch="main"
    if ! git show-ref --verify --quiet refs/heads/main && git show-ref --verify --quiet refs/remotes/origin/master; then
        branch="master"
    elif ! git show-ref --verify --quiet refs/remotes/origin/main; then
        if git show-ref --verify --quiet refs/remotes/origin/master; then
            branch="master"
        else
            echo "    ⚠️  No main or master branch found, skipping branch checkout"
            cd "$REPO_ROOT" || return 1
            return 0
        fi
    fi
    
    # Check if we're in detached HEAD state
    if ! git symbolic-ref -q HEAD > /dev/null; then
        echo "    🔄 Detached HEAD detected, checking out $branch branch..."
        git checkout -B "$branch" "origin/$branch" 2>/dev/null || git checkout "$branch" 2>/dev/null || true
    else
        # Check current branch
        local current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
        if [ "$current_branch" != "$branch" ]; then
            echo "    🔄 Currently on '$current_branch', switching to $branch branch..."
            git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" 2>/dev/null || true
        fi
    fi
    
    # Set up tracking if not already set
    if ! git config --get branch."$branch".remote > /dev/null 2>&1; then
        git branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true
    fi
    
    # Pull latest changes
    git pull origin "$branch" 2>/dev/null || true
    
    cd "$REPO_ROOT" || return 1
    return 0
}

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

# deepiri-api-gateway
echo "  📦 deepiri-api-gateway (API Gateway)..."
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
# Check if submodule directory exists and has content
# Note: For submodules, .git can be a file (pointing to parent .git/modules) or a directory
# So we check for directory existence and content instead
if [ ! -d "platform-services/backend/deepiri-api-gateway" ]; then
    echo "    ❌ ERROR: deepiri-api-gateway directory not found!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/backend/deepiri-api-gateway"
    exit 1
fi
# Check if directory has content (at least one file/directory)
if [ -z "$(ls -A platform-services/backend/deepiri-api-gateway 2>/dev/null)" ]; then
    echo "    ❌ ERROR: deepiri-api-gateway directory is empty!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/backend/deepiri-api-gateway"
    exit 1
fi
echo "    ✅ api-gateway initialized at: $(pwd)/platform-services/backend/deepiri-api-gateway"
echo ""

# deepiri-shared-utils
echo "  📦 deepiri-shared-utils (Shared Utilities - Team-Deepiri/deepiri-shared-utils)..."
cleanup_invalid_submodule "platform-services/shared/deepiri-shared-utils"
git submodule update --init --recursive platform-services/shared/deepiri-shared-utils 2>&1 || true
if ! check_submodule "platform-services/shared/deepiri-shared-utils"; then
    echo "    ❌ ERROR: deepiri-shared-utils not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/shared/deepiri-shared-utils"
    exit 1
fi
echo "    ✅ shared-utils initialized at: $(pwd)/platform-services/shared/deepiri-shared-utils"
echo ""

# deepiri-synapse
echo "  📦 deepiri-synapse (Matrix server - Team-Deepiri/deepiri-synapse)..."
cleanup_invalid_submodule "platform-services/shared/deepiri-synapse"
git submodule update --init --recursive platform-services/shared/deepiri-synapse 2>&1 || true
if ! check_submodule "platform-services/shared/deepiri-synapse"; then
    echo "    ❌ ERROR: deepiri-synapse not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/shared/deepiri-synapse"
    exit 1
fi
echo "    ✅ synapse initialized at: $(pwd)/platform-services/shared/deepiri-synapse"
echo ""

# deepiri-sugar-glider
echo "  📦 deepiri-sugar-glider (Synapse stream bridge - Team-Deepiri/deepiri-sugar-glider)..."
cleanup_invalid_submodule "platform-services/shared/deepiri-sugar-glider"
git submodule update --init --recursive platform-services/shared/deepiri-sugar-glider 2>&1 || true
if ! check_submodule "platform-services/shared/deepiri-sugar-glider"; then
    echo "    ❌ ERROR: deepiri-sugar-glider not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/shared/deepiri-sugar-glider"
    exit 1
fi
echo "    ✅ sugar-glider initialized at: $(pwd)/platform-services/shared/deepiri-sugar-glider"
echo ""

# Update to latest and ensure on main branch
echo "🔄 Updating submodules to latest and ensuring they're on main branch..."
git submodule update --remote deepiri-web-frontend
ensure_submodule_on_main "deepiri-web-frontend"
git submodule update --remote platform-services/backend/deepiri-auth-service
ensure_submodule_on_main "platform-services/backend/deepiri-auth-service"
git submodule update --remote platform-services/backend/deepiri-api-gateway
ensure_submodule_on_main "platform-services/backend/deepiri-api-gateway"
git submodule update --remote platform-services/shared/deepiri-shared-utils
ensure_submodule_on_main "platform-services/shared/deepiri-shared-utils"
git submodule update --remote platform-services/shared/deepiri-synapse
ensure_submodule_on_main "platform-services/shared/deepiri-synapse"
git submodule update --remote platform-services/shared/deepiri-sugar-glider
ensure_submodule_on_main "platform-services/shared/deepiri-sugar-glider"
echo "    ✅ All frontend submodules updated and on main branch"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status deepiri-web-frontend
echo ""
git submodule status platform-services/backend/deepiri-auth-service
echo ""
git submodule status platform-services/backend/deepiri-api-gateway
echo ""
git submodule status platform-services/shared/deepiri-shared-utils
echo ""
git submodule status platform-services/shared/deepiri-synapse 2>/dev/null || echo "  ⚠️  deepiri-synapse (not initialized)"
echo ""
git submodule status platform-services/shared/deepiri-sugar-glider 2>/dev/null || echo "  ⚠️  deepiri-sugar-glider (not initialized)"
echo ""

echo "✅ Frontend Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status deepiri-web-frontend"
echo "  - Update: git submodule update --remote deepiri-web-frontend"
echo "  - Work in submodule: cd deepiri-web-frontend"
echo "  - Install deps: cd deepiri-web-frontend && npm install"
echo ""
echo "  - API Gateway status: git submodule status platform-services/backend/deepiri-api-gateway"
echo "  - Update API Gateway: git submodule update --remote platform-services/backend/deepiri-api-gateway"
echo "  - Work in API Gateway: cd platform-services/backend/deepiri-api-gateway"
echo "  - Synapse status: git submodule status platform-services/shared/deepiri-synapse"
echo "  - Update Synapse: git submodule update --remote platform-services/shared/deepiri-synapse"
echo "  - Work in Synapse: cd platform-services/shared/deepiri-synapse"
echo "  - Sugar Glider status: git submodule status platform-services/shared/deepiri-sugar-glider"
echo "  - Update Sugar Glider: git submodule update --remote platform-services/shared/deepiri-sugar-glider"
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
