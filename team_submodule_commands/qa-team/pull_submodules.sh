#!/bin/bash
# QA Team - Pull Submodules Script
# This script initializes and updates ALL submodules required by the QA Team

set -e

echo "🧪 QA Team - Pulling Submodules"
echo "================================"
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/qa-team/pull_submodules.sh
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

# QA Team needs ALL submodules for comprehensive testing
echo "🔧 Initializing ALL submodules (QA needs everything)..."
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

# Update to latest and ensure on main branch
echo "🔄 Updating all submodules to latest and ensuring they're on main branch..."
git submodule update --remote --recursive
echo "    🔄 Ensuring all submodules are on main branch..."
git submodule foreach --recursive 'cd "$toplevel/$sm_path" && git fetch origin 2>/dev/null || true; branch="main"; if ! git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null && git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then branch="master"; fi; if ! git symbolic-ref -q HEAD > /dev/null 2>&1; then git checkout -B "$branch" "origin/$branch" 2>/dev/null || git checkout "$branch" 2>/dev/null || true; else current=$(git symbolic-ref --short HEAD 2>/dev/null || echo ""); if [ "$current" != "$branch" ]; then git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" 2>/dev/null || true; fi; fi; git branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true; git pull origin "$branch" 2>/dev/null || true' || true
echo "    ✅ All submodules updated and on main branch"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status
echo ""

echo "✅ QA Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update all: git submodule update --remote --recursive"
echo "  - Test Core API: cd deepiri-core-api && npm test"
echo "  - Test Frontend: cd deepiri-web-frontend && npm test"
echo ""

