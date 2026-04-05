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
)

# Initialize and update only those submodules
for sm_path in "${SUBMODULES[@]}"; do
  echo "🔄 Initializing and updating submodule: $sm_path"
  git submodule update --init "$sm_path"

  # Switch to main or master branch if needed
  (
    cd "$sm_path"
    git fetch origin || true
    branch="main"
    if ! git show-ref --verify --quiet refs/remotes/origin/main && git show-ref --verify --quiet refs/remotes/origin/master; then
      branch="master"
    elif ! git show-ref --verify --quiet refs/remotes/origin/main; then
      if git show-ref --verify --quiet refs/remotes/origin/master; then
        branch="master"
      else
        echo "   ⚠️  No main or master branch found, skipping"
        return 0
      fi
    fi

    # Check if we're in detached HEAD state
    if ! git symbolic-ref -q HEAD > /dev/null; then
      echo "   🔄 Detached HEAD detected, checking out $branch branch..."
      git checkout -B "$branch" "origin/$branch" 2>/dev/null || git checkout "$branch" 2>/dev/null || true
    else
      current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
      if [ "$current_branch" != "$branch" ]; then
        echo "   🔄 Currently on '$current_branch', switching to $branch branch..."
        git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" 2>/dev/null || true
      fi
    fi

    # Set up tracking if not already set
    if ! git config --get branch."$branch".remote > /dev/null 2>&1; then
      git branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true
    fi

    git pull origin "$branch" || true
  )
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
