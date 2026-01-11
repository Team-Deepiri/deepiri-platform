#!/bin/bash
# Setup script for Git hooks (backup/manual setup)
# Note: Hooks are automatically configured on clone, but you can run this if needed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

echo "🔧 Setting up Git hooks for AI Team..."
echo ""

# Setup hooks in main repo
echo "📦 Main repository: $REPO_ROOT"
git config core.hooksPath .git-hooks

if [ -f .git-hooks/pre-push ]; then
    echo "✔ Main repo hooks enabled. You are now protected from pushing to 'main' or 'dev'."
else
    echo "⚠️  Warning: .git-hooks/pre-push not found. Make sure you're in the repository root."
    exit 1
fi
echo ""

# Function to sync hooks to a submodule (with fixed logic)
sync_hooks_to_submodule() {
    local submodule_path=$1
    
    if [ ! -d "$submodule_path" ]; then
        echo "  ⏭️  Skipping $submodule_path (directory not found)"
        return
    fi
    
    # Check if it's actually a git repository (submodule)
    if [ ! -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
        echo "  ⏭️  Skipping $submodule_path (not a git repo)"
        return
    fi
    
    # Additional safety: verify git commands work in the submodule
    # If .git is a file but the submodule isn't properly initialized, git commands will fail
    if ! (cd "$submodule_path" && git rev-parse --git-dir >/dev/null 2>&1); then
        echo "  ⏭️  Skipping $submodule_path (git repository not properly initialized)"
        return
    fi
    
    echo "  📦 Syncing hooks to: $submodule_path"
    
    # Create .git-hooks directory in submodule
    mkdir -p "$submodule_path/.git-hooks" 2>/dev/null || true
    
    # Copy all hooks from main repo to submodule
    if [ -d ".git-hooks" ]; then
        cp .git-hooks/* "$submodule_path/.git-hooks/" 2>/dev/null || true
        chmod +x "$submodule_path/.git-hooks/"* 2>/dev/null || true
    fi
    
    # Configure hooksPath for submodule
    # Note: For submodules, .git is usually a FILE (not a directory) pointing to parent's .git/modules
    # We should NOT try to create .git/hooks/ in submodules - just configure hooksPath
    (cd "$submodule_path" && git config core.hooksPath .git-hooks) 2>/dev/null || true
    
    # Copy .gitconfig to submodule if it exists in main repo
    if [ -f "$REPO_ROOT/.gitconfig" ] && [ -d "$submodule_path" ]; then
        # Ensure the submodule directory exists and is writable
        if [ -w "$submodule_path" ] 2>/dev/null; then
        cp "$REPO_ROOT/.gitconfig" "$REPO_ROOT/$submodule_path/.gitconfig" 2>/dev/null || true
        fi
    fi
    
    echo "    ✅ Hooks synced to $submodule_path"
}

# AI Team submodules
echo "🔄 Syncing hooks to AI Team submodules..."
echo ""

# List of AI Team submodules
SUBMODULES=(
    "diri-cyrex"
    "deepiri-modelkit"
    "platform-services/backend/deepiri-external-bridge-service"
    "platform-services/backend/deepiri-language-intelligence-service"
)

for submodule in "${SUBMODULES[@]}"; do
    sync_hooks_to_submodule "$submodule"
done

echo ""
echo "✅ AI Team hooks setup complete!"
echo ""
