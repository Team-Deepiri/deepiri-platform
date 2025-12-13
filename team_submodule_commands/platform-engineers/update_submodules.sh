#!/bin/bash
# Platform Engineers - Update Submodules Script
# This script updates ALL submodules to their latest versions (Platform Engineers need access to everything)

set -e

echo "🚀 Platform Engineers - Updating All Submodules"
echo "================================================="
echo ""

# Navigate to main repository root
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

# Helper function to update a submodule and ensure it's on main branch
update_submodule() {
    local submodule_path="$1"
    local submodule_name="$2"
    
    if [ ! -d "$submodule_path" ]; then
        echo "  ⚠️  $submodule_name not found at $submodule_path"
        echo "     Run pull_submodules.sh first to initialize it"
        return 1
    fi
    
    echo "  📦 Updating $submodule_name..."
    
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
    echo "    ✅ $submodule_name updated"
    return 0
}

# Update main repository first
echo "📥 Pulling latest main repository..."
git pull origin main || echo "⚠️  Could not pull main repo (may be on different branch)"
echo ""

# Platform Engineers - Update ALL submodules
echo "🔄 Updating all submodules..."
echo ""

# Update deepiri-core-api
update_submodule "deepiri-core-api" "deepiri-core-api (Core API)"
echo ""

# Update diri-cyrex
update_submodule "diri-cyrex" "diri-cyrex (AI/ML Service)"
echo ""

# Update deepiri-api-gateway
update_submodule "platform-services/backend/deepiri-api-gateway" "deepiri-api-gateway (API Gateway)"
echo ""

# Update deepiri-auth-service
update_submodule "platform-services/backend/deepiri-auth-service" "deepiri-auth-service (Auth Service)"
echo ""

# Update deepiri-external-bridge-service
update_submodule "platform-services/backend/deepiri-external-bridge-service" "deepiri-external-bridge-service (External Bridge)"
echo ""

# Update deepiri-web-frontend
update_submodule "deepiri-web-frontend" "deepiri-web-frontend (Web Frontend)"
echo ""

# Update diri-helox
update_submodule "diri-helox" "diri-helox (ML Training & Research)"
echo ""

# Update deepiri-modelkit
update_submodule "deepiri-modelkit" "deepiri-modelkit (Shared Contracts & Utilities)"
echo ""

# Also update via git submodule update --remote for consistency (recursive to get nested submodules)
echo "🔄 Syncing all submodule references (recursive)..."
git submodule update --remote --recursive 2>/dev/null || true
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status --recursive
echo ""

echo "✅ All Platform Engineers submodules updated!"
echo ""
echo "📋 Updated Submodules:"
echo "  ✅ deepiri-core-api"
echo "  ✅ diri-cyrex"
echo "  ✅ deepiri-api-gateway"
echo "  ✅ deepiri-auth-service"
echo "  ✅ deepiri-external-bridge-service"
echo "  ✅ deepiri-web-frontend"
echo "  ✅ diri-helox"
echo "  ✅ deepiri-modelkit"
echo "  ✅ All nested submodules (recursive)"
echo ""

