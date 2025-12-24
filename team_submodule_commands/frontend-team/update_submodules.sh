#!/bin/bash
# Frontend Team - Update Submodules Script
# This script updates all submodules required by the Frontend Team to their latest versions

set -e

echo "🎨 Frontend Team - Updating Submodules"
echo "======================================="
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

# Frontend Team submodules
echo "🔄 Updating Frontend Team submodules..."
echo ""

# Update deepiri-web-frontend
update_submodule "deepiri-web-frontend" "deepiri-web-frontend (Web Frontend)"
echo ""

# Update deepiri-auth-service
update_submodule "platform-services/backend/deepiri-auth-service" "deepiri-auth-service (Auth Service)"
echo ""

# Update deepiri-api-gateway
update_submodule "platform-services/backend/deepiri-api-gateway" "deepiri-api-gateway (API Gateway)"
echo ""

# Also update via git submodule update --remote for consistency
echo "🔄 Syncing submodule references..."
git submodule update --remote deepiri-web-frontend 2>/dev/null || true
git submodule update --remote platform-services/backend/deepiri-auth-service 2>/dev/null || true
git submodule update --remote platform-services/backend/deepiri-api-gateway 2>/dev/null || true
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status deepiri-web-frontend
git submodule status platform-services/backend/deepiri-auth-service
git submodule status platform-services/backend/deepiri-api-gateway
echo ""

echo "✅ Frontend Team submodules updated!"
echo ""
echo "📋 Updated Submodules:"
echo "  ✅ deepiri-web-frontend"
echo "  ✅ deepiri-auth-service"
echo "  ✅ deepiri-api-gateway"
echo ""

