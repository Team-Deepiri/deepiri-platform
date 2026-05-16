#!/bin/bash
# QA Team - pull/init submodules needed for docker-compose.dev.yml (synapse, frontend, etc.)

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

# Synapse/sugar-glider first — frontend-dev depends on synapse; a bad frontend pin must not block these.
declare -a SUBMODULES=(
  "platform-services/shared/deepiri-synapse"
  "platform-services/shared/deepiri-sugar-glider"
  "platform-services/shared/deepiri-shared-utils"
  "platform-services/shared/deepiri-prismpipe"
  "platform-services/backend/deepiri-auth-service"
  "platform-services/backend/deepiri-external-bridge-service"
  "platform-services/backend/deepiri-api-gateway"
  "platform-services/backend/deepiri-language-intelligence-service"
  "deepiri-core-api"
  "deepiri-web-frontend"
  "deepiri-suite"
)

FAILED=()

update_one_submodule() {
  local sm_path="$1"
  echo "🔄 Initializing and updating submodule: $sm_path"

  if git submodule update --init "$sm_path"; then
    echo "   📌 Left at platform-pinned commit"
    return 0
  fi

  # Pinned commit missing on remote (e.g. deepiri-web-frontend 6465a07 on docker_build_fixes branch)
  if [ ! -d "$sm_path/.git" ] && [ ! -f "$sm_path/.git" ]; then
    git submodule init "$sm_path" 2>/dev/null || true
  fi

  if [ -d "$sm_path" ] && { [ -d "$sm_path/.git" ] || [ -f "$sm_path/.git" ]; }; then
    echo "   ⚠️  Platform pin unavailable — falling back to origin/main"
    if (cd "$sm_path" && git fetch origin && git checkout -B main origin/main); then
      echo "   ✅ Checked out origin/main (update platform submodule SHA when you can)"
      return 0
    fi
  fi

  echo "   ❌ Failed to initialize $sm_path"
  return 1
}

for sm_path in "${SUBMODULES[@]}"; do
  if ! update_one_submodule "$sm_path"; then
    FAILED+=("$sm_path")
  fi
  echo ""
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "⚠️  Some submodules failed:"
  for f in "${FAILED[@]}"; do
    echo "   - $f"
  done
  echo ""
  echo "💡 deepiri-web-frontend: platform may point at a commit that was never pushed."
  echo "   Fix: cd deepiri-web-frontend && git fetch origin && git checkout main"
  echo "   Then bump the submodule pointer on your platform branch."
  echo ""
fi

# Quick sanity check for QA docker builds
if [ ! -f "$REPO_ROOT/platform-services/shared/deepiri-synapse/Dockerfile" ]; then
  echo "❌ Missing platform-services/shared/deepiri-synapse/Dockerfile"
  echo "   Run: git submodule update --init platform-services/shared/deepiri-synapse"
  exit 1
fi

echo "✅ QA submodule pull finished."
echo ""

echo "🔧 Setting up Git hooks for pulled submodules..."
echo ""
if [ -f "$SCRIPT_DIR/setup-hooks.sh" ]; then
    bash "$SCRIPT_DIR/setup-hooks.sh"
else
    echo "⚠️  Warning: setup-hooks.sh not found at $SCRIPT_DIR/setup-hooks.sh"
fi
echo ""

if [ ${#FAILED[@]} -gt 0 ]; then
  exit 1
fi
