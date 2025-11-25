#!/bin/bash
# Backend Team - Pull Submodules Script
# This script initializes and updates all submodules required by the Backend Team

set -e

echo "⚙️  Backend Team - Pulling Submodules"
echo "======================================"
echo ""

# Navigate to main repository root
# Script is at: team_submodule_commands/backend-team/pull_submodules.sh
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

# Backend Team required submodules
echo "🔧 Initializing Backend Team submodules..."
echo ""

# Ensure platform-services/backend directory exists
mkdir -p platform-services/backend

# deepiri-core-api
echo "  📦 deepiri-core-api (Core API)..."
git submodule update --init --recursive deepiri-core-api
if [ ! -d "deepiri-core-api/.git" ]; then
    echo "    ❌ ERROR: deepiri-core-api not cloned correctly!"
    exit 1
fi
echo "    ✅ core-api initialized at: $(pwd)/deepiri-core-api"
echo ""

# deepiri-api-gateway
echo "  📦 deepiri-api-gateway (API Gateway)..."
git submodule update --init --recursive platform-services/backend/deepiri-api-gateway
if [ ! -d "platform-services/backend/deepiri-api-gateway/.git" ]; then
    echo "    ❌ ERROR: deepiri-api-gateway not cloned correctly!"
    exit 1
fi
echo "    ✅ api-gateway initialized at: $(pwd)/platform-services/backend/deepiri-api-gateway"
echo ""

# deepiri-auth-service
echo "  📦 deepiri-auth-service (Auth Service)..."
git submodule update --init --recursive platform-services/backend/deepiri-auth-service
if [ ! -d "platform-services/backend/deepiri-auth-service/.git" ]; then
    echo "    ❌ ERROR: deepiri-auth-service not cloned correctly!"
    exit 1
fi
echo "    ✅ auth-service initialized at: $(pwd)/platform-services/backend/deepiri-auth-service"
echo ""

# deepiri-external-bridge-service
echo "  📦 deepiri-external-bridge-service (External Bridge)..."
git submodule update --init --recursive platform-services/backend/deepiri-external-bridge-service
if [ ! -d "platform-services/backend/deepiri-external-bridge-service/.git" ]; then
    echo "    ❌ ERROR: deepiri-external-bridge-service not cloned correctly!"
    exit 1
fi
echo "    ✅ external-bridge-service initialized at: $(pwd)/platform-services/backend/deepiri-external-bridge-service"
echo ""

# deepiri-web-frontend
echo "  📦 deepiri-web-frontend (Web Frontend)..."
git submodule update --init --recursive deepiri-web-frontend
if [ ! -d "deepiri-web-frontend/.git" ]; then
    echo "    ❌ ERROR: deepiri-web-frontend not cloned correctly!"
    exit 1
fi
echo "    ✅ web-frontend initialized at: $(pwd)/deepiri-web-frontend"
echo ""

# Update to latest
echo "🔄 Updating submodules to latest..."
git submodule update --remote deepiri-core-api
git submodule update --remote platform-services/backend/deepiri-api-gateway
git submodule update --remote platform-services/backend/deepiri-auth-service
git submodule update --remote platform-services/backend/deepiri-external-bridge-service
git submodule update --remote deepiri-web-frontend
echo "    ✅ All backend submodules updated"
echo ""

# Show status
echo "📊 Submodule Status:"
echo ""
git submodule status deepiri-core-api
git submodule status platform-services/backend/deepiri-api-gateway
git submodule status platform-services/backend/deepiri-auth-service
git submodule status platform-services/backend/deepiri-external-bridge-service
git submodule status deepiri-web-frontend
echo ""

echo "✅ Backend Team submodules ready!"
echo ""
echo "📋 Quick Commands:"
echo "  - Check status: git submodule status"
echo "  - Update all: git submodule update --remote"
echo "  - Work in Core API: cd deepiri-core-api"
echo ""

