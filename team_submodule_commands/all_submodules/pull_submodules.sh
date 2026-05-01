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

# Keep the platform checkout as the source of truth.
# Do not auto-pull the parent repo here; onboarding may be running from a feature branch.
echo "📌 Using current platform checkout: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
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

# Helper function retained for older script flow. Submodule checkout stays pinned to the platform commit.
ensure_submodule_on_main() {
    local submodule_path="$1"
    echo "    📌 Leaving $submodule_path at the platform-pinned commit"
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

# deepiri-prismpipe
echo "  📦 deepiri-prismpipe (PrismPipe - Capability-Routed API Pipeline - Team-Deepiri/deepiri-prismpipe)..."
cleanup_invalid_submodule "platform-services/shared/deepiri-prismpipe"
git submodule update --init --recursive platform-services/shared/deepiri-prismpipe 2>&1 || true
if ! check_submodule "platform-services/shared/deepiri-prismpipe"; then
    echo "    ❌ ERROR: deepiri-prismpipe not cloned correctly!"
    echo "    💡 Try: git submodule update --init --recursive platform-services/shared/deepiri-prismpipe"
    exit 1
fi
echo "    ✅ prismpipe initialized at: $(pwd)/platform-services/shared/deepiri-prismpipe"
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

# Verify submodules at platform-pinned commits
echo "🔄 Verifying submodules at platform-pinned commits..."
ensure_submodule_on_main "deepiri-core-api"
ensure_submodule_on_main "diri-cyrex"
ensure_submodule_on_main "platform-services/backend/deepiri-api-gateway"
ensure_submodule_on_main "deepiri-web-frontend"
ensure_submodule_on_main "platform-services/backend/deepiri-external-bridge-service"
ensure_submodule_on_main "platform-services/backend/deepiri-auth-service"
ensure_submodule_on_main "diri-helox"
ensure_submodule_on_main "deepiri-modelkit"
ensure_submodule_on_main "platform-services/backend/deepiri-language-intelligence-service"
ensure_submodule_on_main "platform-services/shared/deepiri-prismpipe"
ensure_submodule_on_main "platform-services/shared/deepiri-shared-utils"
echo "    ✅ All submodules initialized at platform-pinned commits"
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
git submodule status platform-services/shared/deepiri-prismpipe
git submodule status platform-services/shared/deepiri-shared-utils
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
echo "  ✅ deepiri-prismpipe (PrismPipe)"
echo "  ✅ deepiri-shared-utils"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update all: git submodule update --init"
echo "  - Work in Core API: cd deepiri-core-api"
echo "  - Work in Cyrex: cd diri-cyrex"
echo "  - Work in API Gateway: cd platform-services/backend/deepiri-api-gateway"
echo "  - Work in Frontend: cd deepiri-web-frontend"
echo "  - Work in External Bridge: cd platform-services/backend/deepiri-external-bridge-service"
echo "  - Work in Auth Service: cd platform-services/backend/deepiri-auth-service"
echo "  - Work in Helox: cd diri-helox"
echo "  - Work in Model Kit: cd deepiri-modelkit"
echo "  - Work in Language Intelligence: cd platform-services/backend/deepiri-language-intelligence-service"
echo "  - Work in PrismPipe: cd platform-services/shared/deepiri-prismpipe"
echo ""
