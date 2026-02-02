#!/bin/bash
# All Submodules - Pull Submodules Script
# This script initializes and updates all submodules in the Deepiri platform

set -e

echo "⚙️  All Submodules - Pulling Submodules"
echo "======================================="
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/all_submodules/pull_submodules.sh
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

# All submodules from .gitmodules
echo "🔧 Initializing all submodules..."
echo ""

# Ensure platform-services/backend directory exists
mkdir -p platform-services/backend

# Helper function to check if submodule is valid (handles both .git directory and .git file)
check_submodule() {
    local submodule_path="$1"
    if [ ! -d "$submodule_path" ]; then
        return 1
    fi
    # Check if .git exists as either directory or file (newer Git uses gitfile)
    if [ ! -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
        return 1
    fi
    # Verify it's actually a git repo by checking git status
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

# Helper function to update submodule while preserving its current branch
update_submodule_preserve_branch() {
    local submodule_path="$1"
    if [ ! -d "$submodule_path" ]; then
        return 1
    fi
    
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
    return 0
}

# deepiri-core-api
echo "  📦 deepiri-core-api (Core API - Team-Deepiri/deepiri-core-api)..."
cleanup_invalid_submodule "deepiri-core-api"
git submodule update --init --recursive deepiri-core-api 2>&1 || true
if ! check_submodule "deepiri-core-api"; then
    echo "    ❌ ERROR: deepiri-core-api not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive deepiri-core-api"
    exit 1
fi
echo "    ✅ core-api initialized at: $(pwd)/deepiri-core-api"
echo ""

# diri-cyrex
echo "  📦 diri-cyrex (Cyrex - Team-Deepiri/diri-cyrex)..."
cleanup_invalid_submodule "diri-cyrex"
git submodule update --init --recursive diri-cyrex 2>&1 || true
if ! check_submodule "diri-cyrex"; then
    echo "    ❌ ERROR: diri-cyrex not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive diri-cyrex"
    exit 1
fi
echo "    ✅ cyrex initialized at: $(pwd)/diri-cyrex"
echo ""

# deepiri-api-gateway
echo "  📦 deepiri-api-gateway (API Gateway - Team-Deepiri/deepiri-api-gateway)..."
cleanup_invalid_submodule "platform-services/backend/deepiri-api-gateway"
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-api-gateway"; then
    echo "    ❌ ERROR: deepiri-api-gateway not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/backend/deepiri-api-gateway"
    exit 1
fi
echo "    ✅ api-gateway initialized at: $(pwd)/platform-services/backend/deepiri-api-gateway"
echo ""

# deepiri-web-frontend
echo "  📦 deepiri-web-frontend (Web Frontend - Team-Deepiri/deepiri-web-frontend)..."
cleanup_invalid_submodule "deepiri-web-frontend"
git submodule update --init --recursive deepiri-web-frontend 2>&1 || true
if ! check_submodule "deepiri-web-frontend"; then
    echo "    ❌ ERROR: deepiri-web-frontend not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive deepiri-web-frontend"
    exit 1
fi
echo "    ✅ web-frontend initialized at: $(pwd)/deepiri-web-frontend"
echo ""

# deepiri-external-bridge-service
echo "  📦 deepiri-external-bridge-service (External Bridge - Team-Deepiri/deepiri-external-bridge-service)..."
cleanup_invalid_submodule "platform-services/backend/deepiri-external-bridge-service"
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-external-bridge-service"; then
    echo "    ❌ ERROR: deepiri-external-bridge-service not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service"
    exit 1
fi
echo "    ✅ external-bridge-service initialized at: $(pwd)/platform-services/backend/deepiri-external-bridge-service"
echo ""

# deepiri-auth-service
echo "  📦 deepiri-auth-service (Auth Service - Team-Deepiri/deepiri-auth-service)..."
cleanup_invalid_submodule "platform-services/backend/deepiri-auth-service"
git submodule update --init --recursive platform-services/backend/deepiri-auth-service 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-auth-service"; then
    echo "    ❌ ERROR: deepiri-auth-service not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/backend/deepiri-auth-service"
    exit 1
fi
echo "    ✅ auth-service initialized at: $(pwd)/platform-services/backend/deepiri-auth-service"
echo ""

# diri-helox
echo "  📦 diri-helox (Helox - Team-Deepiri/diri-helox)..."
cleanup_invalid_submodule "diri-helox"
git submodule update --init --recursive diri-helox 2>&1 || true
if ! check_submodule "diri-helox"; then
    echo "    ❌ ERROR: diri-helox not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive diri-helox"
    exit 1
fi
echo "    ✅ helox initialized at: $(pwd)/diri-helox"
echo ""

# deepiri-modelkit
echo "  📦 deepiri-modelkit (Model Kit - Team-Deepiri/deepiri-modelkit)..."
cleanup_invalid_submodule "deepiri-modelkit"
git submodule update --init --recursive deepiri-modelkit 2>&1 || true
if ! check_submodule "deepiri-modelkit"; then
    echo "    ❌ ERROR: deepiri-modelkit not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive deepiri-modelkit"
    exit 1
fi
echo "    ✅ modelkit initialized at: $(pwd)/deepiri-modelkit"
echo ""

# deepiri-language-intelligence-service
echo "  📦 deepiri-language-intelligence-service (Language Intelligence - Team-Deepiri/deepiri-language-intelligence-service)..."
cleanup_invalid_submodule "platform-services/backend/deepiri-language-intelligence-service"
git submodule update --init --recursive platform-services/backend/deepiri-language-intelligence-service 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-language-intelligence-service"; then
    echo "    ❌ ERROR: deepiri-language-intelligence-service not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/backend/deepiri-language-intelligence-service"
    exit 1
fi
echo "    ✅ language-intelligence-service initialized at: $(pwd)/platform-services/backend/deepiri-language-intelligence-service"
echo ""

# Update to latest while preserving current branches
echo "🔄 Updating submodules while preserving their current branches..."
update_submodule_preserve_branch "deepiri-core-api"
update_submodule_preserve_branch "diri-cyrex"
update_submodule_preserve_branch "platform-services/backend/deepiri-api-gateway"
update_submodule_preserve_branch "deepiri-web-frontend"
update_submodule_preserve_branch "platform-services/backend/deepiri-external-bridge-service"
update_submodule_preserve_branch "platform-services/backend/deepiri-auth-service"
update_submodule_preserve_branch "diri-helox"
update_submodule_preserve_branch "deepiri-modelkit"
update_submodule_preserve_branch "platform-services/backend/deepiri-language-intelligence-service"
echo "    ✅ All submodules updated (branches preserved)"
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

echo "✅ All submodules ready!"
echo ""
echo "📋 All Submodules:"
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
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update all: git submodule update --remote"
echo "  - Work in Core API: cd deepiri-core-api"
echo "  - Work in Cyrex: cd diri-cyrex"
echo "  - Work in API Gateway: cd platform-services/backend/deepiri-api-gateway"
echo "  - Work in Frontend: cd deepiri-web-frontend"
echo "  - Work in External Bridge: cd platform-services/backend/deepiri-external-bridge-service"
echo "  - Work in Auth Service: cd platform-services/backend/deepiri-auth-service"
echo "  - Work in Helox: cd diri-helox"
echo "  - Work in Model Kit: cd deepiri-modelkit"
echo "  - Work in Language Intelligence: cd platform-services/backend/deepiri-language-intelligence-service"
echo ""

