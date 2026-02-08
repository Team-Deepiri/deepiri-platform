#!/bin/bash
# All Submodules - Update Submodules Script
# This script updates all submodules in the Deepiri platform to their latest versions

set -e

echo "⚙️  All Submodules - Updating Submodules"
echo "========================================="
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

# Helper function to update a submodule while preserving its current branch
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
    
    # Fetch latest changes from all remotes
    echo "    📥 Fetching latest changes..."
    git fetch origin 2>/dev/null || true
    git fetch --all 2>/dev/null || true
    
    # Get current branch or commit
    local current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    local is_detached=false
    
    if [ -z "$current_branch" ]; then
        is_detached=true
        current_branch=$(git rev-parse --short HEAD 2>/dev/null || echo "detached")
        echo "    📍 Currently in detached HEAD state at: $current_branch"
    else
        echo "    🌿 Current branch: $current_branch"
    fi
    
    # If we're on a branch, try to update it
    if [ "$is_detached" = false ] && [ -n "$current_branch" ]; then
        # Check if remote tracking branch exists
        local remote_branch="origin/$current_branch"
        if git show-ref --verify --quiet "refs/remotes/$remote_branch" 2>/dev/null; then
            echo "    🔄 Merging updates from $remote_branch..."
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo "    ⚠️  Uncommitted changes detected. Stashing..."
                git stash push -m "Auto-stash before merge $(date +%Y-%m-%d_%H:%M:%S)" 2>/dev/null || true
            fi
            
            # Try to merge
            if git merge "$remote_branch" --no-edit 2>/dev/null; then
                echo "    ✅ Successfully merged updates"
            else
                # Check if merge conflict occurred
                if [ -f ".git/MERGE_HEAD" ]; then
                    echo "    ⚠️  Merge conflicts detected!"
                    echo "    💡 Please resolve conflicts manually in: $submodule_path"
                    echo "    💡 After resolving, run: git add . && git commit"
                    echo "    💡 To check conflict files: git diff --name-only --diff-filter=U"
                else
                    echo "    ⚠️  Merge failed. Current state preserved."
                fi
            fi
            
            # Restore stashed changes if any
            if git stash list | grep -q "Auto-stash"; then
                echo "    🔄 Restoring stashed changes..."
                git stash pop 2>/dev/null || true
            fi
        else
            echo "    ℹ️  No remote tracking branch found for $current_branch"
            echo "    💡 Branch exists locally but not on remote"
        fi
        
        # Set up tracking if not already set and remote branch exists
        if git show-ref --verify --quiet "refs/remotes/$remote_branch" 2>/dev/null; then
            if ! git config --get branch."$current_branch".remote > /dev/null 2>&1; then
                git branch --set-upstream-to="$remote_branch" "$current_branch" 2>/dev/null || true
            fi
        fi
    else
        echo "    ℹ️  In detached HEAD state - preserving current commit"
        echo "    💡 To work on a branch, checkout a branch first"
    fi
    
    cd "$REPO_ROOT" || return 1
    echo "    ✅ $submodule_name updated (branch preserved)"
    return 0
}

# Update main repository first
echo "📥 Pulling latest main repository..."
git pull origin main || echo "⚠️  Could not pull main repo (may be on different branch)"
echo ""

# All submodules
echo "🔄 Updating all submodules..."
echo ""

# Update deepiri-core-api
update_submodule "deepiri-core-api" "deepiri-core-api (Core API)"
echo ""

# Update diri-cyrex
update_submodule "diri-cyrex" "diri-cyrex (Cyrex)"
echo ""

# Update deepiri-api-gateway
update_submodule "platform-services/backend/deepiri-api-gateway" "deepiri-api-gateway (API Gateway)"
echo ""

# Update deepiri-web-frontend
update_submodule "deepiri-web-frontend" "deepiri-web-frontend (Web Frontend)"
echo ""

# Update deepiri-external-bridge-service
update_submodule "platform-services/backend/deepiri-external-bridge-service" "deepiri-external-bridge-service (External Bridge)"
echo ""

# Update deepiri-auth-service
update_submodule "platform-services/backend/deepiri-auth-service" "deepiri-auth-service (Auth Service)"
echo ""

# Update diri-helox
update_submodule "diri-helox" "diri-helox (Helox)"
echo ""

# Update deepiri-modelkit
update_submodule "deepiri-modelkit" "deepiri-modelkit (Model Kit)"
echo ""

# Update deepiri-language-intelligence-service
update_submodule "platform-services/backend/deepiri-language-intelligence-service" "deepiri-language-intelligence-service (Language Intelligence)"
echo ""

# Note: We don't use 'git submodule update --remote' here because it would
# update to the remote branch's HEAD, potentially changing the branch.
# Instead, we preserve each submodule's current branch and merge updates.
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status deepiri-core-api
git submodule status diri-cyrex
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status deepiri-web-frontend
git submodule status platform-services/backend/deepiri-external-bridge-service
git submodule status platform-services/backend/deepiri-auth-service
git submodule status diri-helox
git submodule status deepiri-modelkit
git submodule status platform-services/backend/deepiri-language-intelligence-service
echo ""

echo "✅ All submodules updated!"
echo ""
echo "📋 Updated Submodules:"
echo "  ✅ deepiri-core-api"
echo "  ✅ diri-cyrex"
echo "  ✅ deepiri-api-gateway"
echo "  ✅ deepiri-web-frontend"
echo "  ✅ deepiri-external-bridge-service"
echo "  ✅ deepiri-auth-service"
echo "  ✅ diri-helox"
echo "  ✅ deepiri-modelkit"
echo "  ✅ deepiri-language-intelligence-service"
echo ""

