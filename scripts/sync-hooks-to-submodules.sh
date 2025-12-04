#!/bin/sh
# Sync git hooks from main repo to all submodules
# This ensures all submodules have the same branch protection hooks

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

if [ ! -d ".git-hooks" ]; then
    echo "❌ Error: .git-hooks directory not found in main repository"
    exit 1
fi

echo "🔄 Syncing git hooks to all submodules..."
echo ""

# Function to sync hooks to a submodule
sync_hooks_to_submodule() {
    local submodule_path=$1
    local submodule_name=$2
    
    if [ ! -d "$submodule_path" ]; then
        echo "⚠️  Skipping $submodule_name (directory not found)"
        return
    fi
    
    # Check if it's actually a git repository (submodule)
    if [ ! -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
        echo "⚠️  Skipping $submodule_name (not a git repository)"
        return
    fi
    
    echo "📦 Syncing hooks to $submodule_name..."
    
    # Create .git-hooks directory in submodule
    mkdir -p "$submodule_path/.git-hooks"
    
    # Copy all hooks from main repo to submodule
    for hook in .git-hooks/*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            cp "$hook" "$submodule_path/.git-hooks/$hook_name"
            chmod +x "$submodule_path/.git-hooks/$hook_name"
        fi
    done
    
    # Install hooks in submodule's .git/hooks
    cd "$submodule_path" || return
    
    mkdir -p .git/hooks
    for hook in .git-hooks/*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            cp "$hook" ".git/hooks/$hook_name"
            chmod +x ".git/hooks/$hook_name"
        fi
    done
    
    # Configure hooksPath for submodule
    git config core.hooksPath .git-hooks
    
    echo "✔ Hooks synced and installed for $submodule_name"
    cd "$REPO_ROOT" || return
}

# Sync hooks to all submodules listed in .gitmodules
if [ -f ".gitmodules" ]; then
    echo "📋 Found submodules in .gitmodules:"
    # Extract submodule paths from .gitmodules (handles tabs and spaces)
    # This ensures we catch ALL submodules regardless of formatting
    submodule_count=0
    grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//' | while IFS= read -r submodule_path; do
        # Skip empty lines
        [ -z "$submodule_path" ] && continue
        
        submodule_count=$((submodule_count + 1))
        submodule_name=$(basename "$submodule_path")
        echo "   $submodule_count. $submodule_name ($submodule_path)"
        sync_hooks_to_submodule "$submodule_path" "$submodule_name"
    done
    echo ""
else
    echo "⚠️  Warning: .gitmodules file not found"
fi

echo ""
echo "✅ Git hooks sync complete for all submodules!"
echo ""
echo "📝 All submodules are now protected from pushes to 'main', 'dev', 'master', or team-dev branches."

