#!/bin/sh

# Script to manually sync hooks to all submodules NOW
# This ensures all submodules have the latest hooks immediately

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

if [ ! -d ".git-hooks" ]; then
    echo "❌ Error: .git-hooks directory not found in root"
    exit 1
fi

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
            echo "   ✓ Copied $hook_name"
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
    
    # Copy .gitconfig to submodule if it exists in main repo
    if [ -f "$REPO_ROOT/.gitconfig" ]; then
        cp "$REPO_ROOT/.gitconfig" "$submodule_path/.gitconfig"
        echo "   ✓ Copied .gitconfig"
    fi
    
    echo "   ✅ $submodule_name hooks configured"
    
    cd "$REPO_ROOT" || return
}

# Sync hooks to all submodules listed in .gitmodules
if [ -f ".gitmodules" ]; then
    echo "🔄 Syncing hooks to all submodules..."
    echo ""
    
    # Extract submodule paths from .gitmodules (handles tabs and spaces)
    grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//' | while IFS= read -r submodule_path; do
        # Skip empty lines
        [ -z "$submodule_path" ] && continue
        
        submodule_name=$(basename "$submodule_path")
        sync_hooks_to_submodule "$submodule_path" "$submodule_name"
    done
    
    echo ""
    echo "✅ All submodules now have updated hooks!"
    echo "   Protected branches: main, dev, master, and team-dev branches"
else
    echo "⚠️  No .gitmodules file found"
    exit 1
fi

