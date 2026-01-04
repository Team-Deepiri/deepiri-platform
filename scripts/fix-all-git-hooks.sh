#!/bin/bash
# Fix all git hooks in main repo and all submodules

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

echo "🔧 Fixing git hooks in main repository and all submodules..."

# Fix main repository
echo "📦 Main repository: $REPO_ROOT"
if [ -d ".git-hooks" ]; then
    chmod +x .git-hooks/* 2>/dev/null || true
    git config core.hooksPath .git-hooks
    # Only copy to .git/hooks if .git is a directory (not a file/submodule)
    if [ -d ".git" ]; then
        mkdir -p .git/hooks
        cp .git-hooks/* .git/hooks/ 2>/dev/null || true
        chmod +x .git/hooks/* 2>/dev/null || true
    fi
    echo "  ✅ Main repo hooks fixed"
else
    echo "  ⚠️  .git-hooks directory not found in main repo"
fi

# Fix all submodules
if [ -f ".gitmodules" ]; then
    while IFS= read -r submodule_path; do
        [ -z "$submodule_path" ] && continue
        
        if [ ! -d "$submodule_path" ]; then
            echo "  ⏭️  Skipping $submodule_path (not found)"
            continue
        fi
        
        # Check if it's a git repository (submodule)
        if [ ! -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
            echo "  ⏭️  Skipping $submodule_path (not a git repo)"
            continue
        fi
        
        # Additional safety: verify git commands work in the submodule
        # If .git is a file but the submodule isn't properly initialized, git commands will fail
        if ! (cd "$submodule_path" && git rev-parse --git-dir >/dev/null 2>&1); then
            echo "  ⏭️  Skipping $submodule_path (git repository not properly initialized)"
            continue
        fi
        
        echo "📦 Submodule: $submodule_path"
        
        # Create .git-hooks directory if it doesn't exist
        mkdir -p "$submodule_path/.git-hooks" 2>/dev/null || true
        
        # Copy hooks from main repo
        if [ -d ".git-hooks" ]; then
            cp .git-hooks/* "$submodule_path/.git-hooks/" 2>/dev/null || true
            chmod +x "$submodule_path/.git-hooks/"* 2>/dev/null || true
        fi
        
        # Configure hooksPath for submodule
        # Note: For submodules, .git is usually a FILE (not a directory) pointing to parent's .git/modules
        # We should NOT try to create .git/hooks/ in submodules - just configure hooksPath
        (cd "$submodule_path" && \
            git config core.hooksPath .git-hooks) 2>/dev/null || true
        
        # Only try to install hooks in .git/hooks if .git is actually a directory (not a file)
        # This is rare for submodules, but can happen in some git configurations
        if [ -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
            (cd "$submodule_path" && \
                mkdir -p .git/hooks 2>/dev/null || true && \
                cp .git-hooks/* .git/hooks/ 2>/dev/null || true && \
                chmod +x .git/hooks/* 2>/dev/null || true)
        fi
        
        echo "  ✅ $submodule_path hooks fixed"
    done < <(grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//')
fi

echo ""
echo "✅ All git hooks fixed!"
echo "   Main repo: hooksPath = $(git config core.hooksPath)"
echo ""
echo "📋 Submodule hooks status:"
if [ -f ".gitmodules" ]; then
    while IFS= read -r submodule_path; do
        [ -z "$submodule_path" ] && continue
        if [ -d "$submodule_path" ] && ([ -d "$submodule_path/.git" ] || [ -f "$submodule_path/.git" ]); then
            hooks_path=$(cd "$submodule_path" && git config core.hooksPath 2>/dev/null || echo "not set")
            echo "   $submodule_path: $hooks_path"
        fi
    done < <(grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//')
fi

