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
    
    # Additional safety: verify git commands work in the submodule
    # If .git is a file but the submodule isn't properly initialized, git commands will fail
    if ! (cd "$submodule_path" && git rev-parse --git-dir >/dev/null 2>&1); then
        echo "⚠️  Skipping $submodule_name (git repository not properly initialized)"
        return
    fi
    
    echo "📦 Syncing hooks to $submodule_name..."
    
    # Create .git-hooks directory in submodule
    mkdir -p "$submodule_path/.git-hooks" 2>/dev/null || true
    
    # Copy all hooks from main repo to submodule
    for hook in .git-hooks/*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            cp "$hook" "$submodule_path/.git-hooks/$hook_name" 2>/dev/null || true
            chmod +x "$submodule_path/.git-hooks/$hook_name" 2>/dev/null || true
            echo "   ✓ Copied $hook_name"
        fi
    done
    
    # Install hooks in submodule's .git/hooks ONLY if .git is a directory
    # For submodules, .git is usually a FILE pointing to parent's .git/modules
    # In that case, we only configure hooksPath, not .git/hooks
    cd "$submodule_path" || return
    
    # Only create .git/hooks if .git is actually a directory (not a file)
    if [ -d ".git" ] && [ ! -f ".git" ]; then
        mkdir -p .git/hooks 2>/dev/null || true
        for hook in .git-hooks/*; do
            if [ -f "$hook" ]; then
                hook_name=$(basename "$hook")
                cp "$hook" ".git/hooks/$hook_name" 2>/dev/null || true
                chmod +x ".git/hooks/$hook_name" 2>/dev/null || true
            fi
        done
    fi
    
    # Configure hooksPath for submodule (this works even if .git is a file)
    git config core.hooksPath .git-hooks 2>/dev/null || true
    
    # Copy .gitconfig to submodule if it exists in main repo
    cd "$REPO_ROOT" || return
    if [ -f "$REPO_ROOT/.gitconfig" ] && [ -d "$submodule_path" ]; then
        # Ensure the submodule directory exists and is writable
        if [ -w "$submodule_path" ] 2>/dev/null; then
            cp "$REPO_ROOT/.gitconfig" "$REPO_ROOT/$submodule_path/.gitconfig" 2>/dev/null || true
        echo "   ✓ Copied .gitconfig"
        fi
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
    echo "   Protected branches: main, dev (exact), master, and any branch containing 'team-dev'"
else
    echo "⚠️  No .gitmodules file found"
    exit 1
fi

