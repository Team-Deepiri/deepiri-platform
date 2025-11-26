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

# Update to latest and ensure on main branch
echo "🔄 Updating submodules to latest and ensuring they're on main branch..."
git submodule update --remote deepiri-web-frontend
ensure_submodule_on_main "deepiri-web-frontend"
git submodule update --remote platform-services/backend/deepiri-auth-service
ensure_submodule_on_main "platform-services/backend/deepiri-auth-service"
echo "    ✅ All frontend submodules updated and on main branch"
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