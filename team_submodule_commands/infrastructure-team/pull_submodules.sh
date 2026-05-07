#!/bin/bash
# Infrastructure Team - Pull Submodules Script
# This script initializes and updates all submodules required by the Infrastructure Team

set -e

echo "🏗️  Infrastructure Team - Pulling Submodules"
echo "============================================="
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/infrastructure-team/pull_submodules.sh
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

# Infrastructure Team required submodules (all except frontend)
echo "🔧 Initializing Infrastructure Team submodules..."
echo ""

# Ensure platform-services/backend directory exists
mkdir -p platform-services/backend

# Helper function to check if submodule is valid
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

# deepiri-core-api
echo "  📦 deepiri-core-api (Core API)..."
git submodule update --init --recursive deepiri-core-api 2>&1 || true
if ! check_submodule "deepiri-core-api"; then
    echo "    ❌ ERROR: deepiri-core-api not cloned correctly!"
    exit 1
fi
echo "    ✅ core-api initialized at: $(pwd)/deepiri-core-api"
echo ""

# deepiri-api-gateway
echo "  📦 deepiri-api-gateway (API Gateway)..."
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-api-gateway"; then
    echo "    ❌ ERROR: deepiri-api-gateway not cloned correctly!"
    exit 1
fi
echo "    ✅ api-gateway initialized at: $(pwd)/platform-services/backend/deepiri-api-gateway"
echo ""

# deepiri-auth-service
echo "  📦 deepiri-auth-service (Auth Service)..."
git submodule update --init --recursive platform-services/backend/deepiri-auth-service 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-auth-service"; then
    echo "    ❌ ERROR: deepiri-auth-service not cloned correctly!"
    exit 1
fi
echo "    ✅ auth-service initialized at: $(pwd)/platform-services/backend/deepiri-auth-service"
echo ""

# deepiri-external-bridge-service
echo "  📦 deepiri-external-bridge-service (External Bridge)..."
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-external-bridge-service"; then
    echo "    ❌ ERROR: deepiri-external-bridge-service not cloned correctly!"
    exit 1
fi
echo "    ✅ external-bridge-service initialized at: $(pwd)/platform-services/backend/deepiri-external-bridge-service"
echo ""

# deepiri-language-intelligence-service
echo "  📦 deepiri-language-intelligence-service (Language Intelligence)..."
git submodule update --init --recursive platform-services/backend/deepiri-language-intelligence-service 2>&1 || true
if ! check_submodule "platform-services/backend/deepiri-language-intelligence-service"; then
    echo "    ❌ ERROR: deepiri-language-intelligence-service not cloned correctly!"
    exit 1
fi
echo "    ✅ language-intelligence-service initialized at: $(pwd)/platform-services/backend/deepiri-language-intelligence-service"
echo ""

# deepiri-prismpipe - PrismPipe (Capability-Routed API Pipeline)
echo "  📦 deepiri-prismpipe (PrismPipe - Capability-Routed API Pipeline)..."
mkdir -p platform-services/shared/deepiri-prismpipe
git submodule update --init --recursive platform-services/shared/deepiri-prismpipe 2>&1 || true
if ! check_submodule "platform-services/shared/deepiri-prismpipe"; then
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
git submodule update --remote deepiri-core-api
ensure_submodule_on_main "deepiri-core-api"
git submodule update --remote diri-cyrex
ensure_submodule_on_main "diri-cyrex"
git submodule update --remote platform-services/backend/deepiri-api-gateway
ensure_submodule_on_main "platform-services/backend/deepiri-api-gateway"
git submodule update --remote platform-services/backend/deepiri-auth-service
ensure_submodule_on_main "platform-services/backend/deepiri-auth-service"
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
ensure_submodule_on_main "platform-services/backend/deepiri-external-bridge-service"
git submodule update --remote platform-services/backend/deepiri-language-intelligence-service
ensure_submodule_on_main "platform-services/backend/deepiri-language-intelligence-service"
git submodule update --remote platform-services/shared/deepiri-prismpipe
ensure_submodule_on_main "platform-services/shared/deepiri-prismpipe"
git submodule update --remote platform-services/shared/deepiri-shared-utils
ensure_submodule_on_main "platform-services/shared/deepiri-shared-utils"
git submodule update --remote platform-services/shared/deepiri-synapse
ensure_submodule_on_main "platform-services/shared/deepiri-synapse"
git submodule update --remote platform-services/shared/deepiri-sugar-glider
ensure_submodule_on_main "platform-services/shared/deepiri-sugar-glider"
echo "    ✅ All infrastructure submodules updated and on main branch"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status deepiri-core-api
git submodule status diri-cyrex
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status platform-services/backend/deepiri-auth-service
git submodule status platform-services/backend/deepiri-external-bridge-service
git submodule status platform-services/backend/deepiri-language-intelligence-service
git submodule status platform-services/shared/deepiri-prismpipe 2>/dev/null || echo "  ⚠️  deepiri-prismpipe (not initialized)"
git submodule status platform-services/shared/deepiri-synapse 2>/dev/null || echo "  ⚠️  deepiri-synapse (not initialized)"
git submodule status platform-services/shared/deepiri-sugar-glider 2>/dev/null || echo "  ⚠️  deepiri-sugar-glider (not initialized)"
echo ""

echo "✅ Infrastructure Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update all: git submodule update --remote"
echo "  - Work in Core API: cd deepiri-core-api"
echo "  - Work in Cyrex: cd diri-cyrex"
echo "  - Work in API Gateway: cd platform-services/backend/deepiri-api-gateway"
echo "  - Work in Auth Service: cd platform-services/backend/deepiri-auth-service"
echo "  - Work in External Bridge: cd platform-services/backend/deepiri-external-bridge-service"
echo "  - Work in Language Intelligence: cd platform-services/backend/deepiri-language-intelligence-service"
echo "  - Work in PrismPipe: cd platform-services/shared/deepiri-prismpipe"
echo "  - Work in Synapse: cd platform-services/shared/deepiri-synapse"
echo "  - Work in Sugar Glider: cd platform-services/shared/deepiri-sugar-glider"
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
