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

# AI Team required submodules
echo "🔧 Initializing AI Team submodules..."
echo ""

# Ensure platform-services/backend directory exists
mkdir -p platform-services/backend

# diri-cyrex - AI/ML service
echo "  📦 diri-cyrex (AI/ML Service)..."
git submodule update --init --recursive diri-cyrex
echo "    ✅ diri-cyrex initialized"
echo ""

# deepiri-ollama-utils - Shared Ollama runtime and CLI utilities
echo "  📦 deepiri-ollama-utils (Shared Ollama Utilities)..."
git submodule update --init --recursive deepiri-ollama-utils
echo "    ✅ deepiri-ollama-utils initialized"

git submodule update --remote deepiri-ollama-utils
ensure_submodule_on_main "deepiri-ollama-utils"
echo "    ✅ deepiri-ollama-utils updated and on main branch"

git submodule status deepiri-ollama-utils
echo "  - Check status: git submodule status deepiri-ollama-utils"
echo "  - Update: git submodule update --remote deepiri-ollama-utils"


# deepiri-modelkit - Shared contracts and utilities
echo "  📦 deepiri-modelkit (Shared Contracts & Utilities)..."
mkdir -p deepiri-modelkit
git submodule update --init --recursive deepiri-modelkit 2>&1 || true
if [ ! -d "deepiri-modelkit/.git" ] && [ ! -f "deepiri-modelkit/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-modelkit not cloned correctly!"
else
    echo "    ✅ modelkit initialized at: $(pwd)/deepiri-modelkit"
fi
echo ""

# deepiri-api-gateway - API Gateway (read-only access)
echo "  📦 deepiri-api-gateway (API Gateway)..."
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
if [ ! -f "platform-services/backend/deepiri-api-gateway/.git" ] && [ ! -d "platform-services/backend/deepiri-api-gateway/.git" ]; then
    echo "    ❌ ERROR: deepiri-api-gateway not cloned correctly!"
    exit 1
fi
echo "    ✅ api-gateway initialized at: $(pwd)/platform-services/backend/deepiri-api-gateway"
echo ""

# deepiri-prismpipe - PrismPipe (Capability-Routed API Pipeline)
echo "  📦 deepiri-prismpipe (PrismPipe - Capability-Routed API Pipeline)..."
mkdir -p platform-services/shared/deepiri-prismpipe
git submodule update --init --recursive platform-services/shared/deepiri-prismpipe 2>&1 || true
if [ ! -d "platform-services/shared/deepiri-prismpipe/.git" ] && [ ! -f "platform-services/shared/deepiri-prismpipe/.git" ]; then
    echo "    ⚠️  WARNING: deepiri-prismpipe not cloned correctly!"
else
    echo "    ✅ prismpipe initialized at: $(pwd)/platform-services/shared/deepiri-prismpipe"
fi
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
git submodule update --remote diri-cyrex
ensure_submodule_on_main "diri-cyrex"
echo "    ✅ diri-cyrex updated and on main branch"
git submodule update --remote platform-services/shared/deepiri-shared-utils 2>/dev/null || true
ensure_submodule_on_main "platform-services/shared/deepiri-shared-utils"
echo "    ✅ shared-utils updated and on main branch"
git submodule update --remote platform-services/backend/deepiri-api-gateway
ensure_submodule_on_main "platform-services/backend/deepiri-api-gateway"
echo "    ✅ api-gateway updated and on main branch"
git submodule update --remote deepiri-modelkit 2>/dev/null || true
ensure_submodule_on_main "deepiri-modelkit"
echo "    ✅ modelkit updated and on main branch"
git submodule update --remote platform-services/shared/deepiri-prismpipe 2>/dev/null || true
ensure_submodule_on_main "platform-services/shared/deepiri-prismpipe"
echo "    ✅ prismpipe updated and on main branch"
git submodule update --remote platform-services/shared/deepiri-synapse 2>/dev/null || true
ensure_submodule_on_main "platform-services/shared/deepiri-synapse"
echo "    ✅ synapse updated and on main branch"
git submodule update --remote platform-services/shared/deepiri-sugar-glider 2>/dev/null || true
ensure_submodule_on_main "platform-services/shared/deepiri-sugar-glider"
echo "    ✅ sugar-glider updated and on main branch"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status diri-cyrex
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status deepiri-modelkit 2>/dev/null || echo "  ⚠️  deepiri-modelkit (not initialized)"
git submodule status platform-services/shared/deepiri-prismpipe 2>/dev/null || echo "  ⚠️  deepiri-prismpipe (not initialized)"
git submodule status platform-services/shared/deepiri-shared-utils 2>/dev/null || echo "  ⚠️  deepiri-shared-utils (not initialized)"
git submodule status platform-services/shared/deepiri-synapse 2>/dev/null || echo "  ⚠️  deepiri-synapse (not initialized)"
git submodule status platform-services/shared/deepiri-sugar-glider 2>/dev/null || echo "  ⚠️  deepiri-sugar-glider (not initialized)"
echo ""

echo "✅ AI Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status diri-cyrex"
echo "  - Check status: git submodule status platform-services/backend/deepiri-api-gateway"
echo "  - Check status: git submodule status deepiri-modelkit"
echo "  - Check status: git submodule status platform-services/shared/deepiri-prismpipe"
echo "  - Check status: git submodule status platform-services/shared/deepiri-synapse"
echo "  - Check status: git submodule status platform-services/shared/deepiri-sugar-glider"
echo "  - Update: git submodule update --remote diri-cyrex"
echo "  - Update: git submodule update --remote platform-services/backend/deepiri-api-gateway"
echo "  - Update: git submodule update --remote deepiri-modelkit"
echo "  - Update: git submodule update --remote platform-services/shared/deepiri-prismpipe"
echo "  - Update: git submodule update --remote platform-services/shared/deepiri-synapse"
echo "  - Update: git submodule update --remote platform-services/shared/deepiri-sugar-glider"
echo "  - Work in cyrex: cd diri-cyrex"
echo "  - Work in api gateway: cd platform-services/backend/deepiri-api-gateway"
echo "  - Work in modelkit: cd deepiri-modelkit"
echo "  - Work in prismpipe: cd platform-services/shared/deepiri-prismpipe"
echo "  - Work in synapse: cd platform-services/shared/deepiri-synapse"
echo "  - Work in sugar-glider: cd platform-services/shared/deepiri-sugar-glider"
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
