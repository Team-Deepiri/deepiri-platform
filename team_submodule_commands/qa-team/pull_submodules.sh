#!/bin/bash
set -e

echo "🧪 QA Team - Initializing Specific Submodules"
echo "============================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ ! -d "$REPO_ROOT/.git" ]; then
    echo "❌ Not a git repo: $REPO_ROOT"
    exit 1
fi
cd "$REPO_ROOT"

# List of submodules you need:
declare -a SUBMODULES=(
  "platform-services/backend/deepiri-auth-service"
  "platform-services/backend/deepiri-external-bridge-service"
  "platform-services/backend/deepiri-api-gateway"
  "platform-services/backend/deepiri-language-intelligence-service"
  "deepiri-core-api"
  "deepiri-web-frontend"
  "platform-services/shared/deepiri-prismpipe"
  "platform-services/shared/deepiri-shared-utils"
  "platform-services/shared/deepiri-synapse"
  "platform-services/shared/deepiri-sugar-glider"
)

# Initialize and update only those submodules
for sm_path in "${SUBMODULES[@]}"; do
  echo "🔄 Initializing and updating submodule: $sm_path"
  git submodule update --init "$sm_path"
  echo "   📌 Left at platform-pinned commit"
done

echo ""
echo "✅ Specific QA submodules initialized and updated."
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
