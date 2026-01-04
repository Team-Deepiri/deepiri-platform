#!/bin/bash
# Verify that all submodules are protected with hooks

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

echo "🛡️  Verifying submodule protection..."
echo ""

if [ ! -f ".gitmodules" ]; then
    echo "ℹ️  No .gitmodules file found (this might be a submodule itself)"
    exit 0
fi

PROTECTED=0
UNPROTECTED=0
NOT_INITIALIZED=0
TOTAL=0

# Check each submodule
while IFS= read -r submodule_path; do
    [ -z "$submodule_path" ] && continue
    TOTAL=$((TOTAL + 1))
    
    submodule_name=$(basename "$submodule_path")
    
    # Check if submodule is initialized
    if [ ! -d "$submodule_path" ]; then
        echo "⏭️  $submodule_path - Not initialized (skipping)"
        NOT_INITIALIZED=$((NOT_INITIALIZED + 1))
        continue
    fi
    
    # Check if it's a git repository
    if [ ! -d "$submodule_path/.git" ] && [ ! -f "$submodule_path/.git" ]; then
        echo "⚠️  $submodule_path - Not a git repository"
        UNPROTECTED=$((UNPROTECTED + 1))
        continue
    fi
    
    # Check if hooks directory exists
    if [ ! -d "$submodule_path/.git-hooks" ]; then
        echo "❌ $submodule_path - No .git-hooks directory"
        UNPROTECTED=$((UNPROTECTED + 1))
        continue
    fi
    
    # Check if pre-push hook exists (critical for branch protection)
    if [ ! -f "$submodule_path/.git-hooks/pre-push" ]; then
        echo "❌ $submodule_path - Missing pre-push hook"
        UNPROTECTED=$((UNPROTECTED + 1))
        continue
    fi
    
    # Check if hooksPath is configured
    cd "$submodule_path" || continue
    hooks_path="$(git config core.hooksPath 2>/dev/null || echo "")"
    cd "$REPO_ROOT" || exit 1
    
    if [ "$hooks_path" != ".git-hooks" ]; then
        echo "❌ $submodule_path - hooksPath not configured (current: '$hooks_path')"
        UNPROTECTED=$((UNPROTECTED + 1))
        continue
    fi
    
    # Check if hooks are executable
    if [ ! -x "$submodule_path/.git-hooks/pre-push" ]; then
        echo "⚠️  $submodule_path - pre-push hook not executable"
        UNPROTECTED=$((UNPROTECTED + 1))
        continue
    fi
    
    echo "✅ $submodule_path - Protected"
    PROTECTED=$((PROTECTED + 1))
    
done < <(grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//')

echo ""
echo "📊 Protection Summary:"
echo "   Total submodules: $TOTAL"
echo "   ✅ Protected: $PROTECTED"
echo "   ❌ Unprotected: $UNPROTECTED"
echo "   ⏭️  Not initialized: $NOT_INITIALIZED"
echo ""

if [ $UNPROTECTED -gt 0 ]; then
    echo "⚠️  Some submodules are not protected!"
    echo "   Run: ./scripts/fix-all-git-hooks.sh"
    echo "   Or: git checkout <branch> (triggers post-checkout hook)"
    exit 1
elif [ $PROTECTED -eq $TOTAL ] && [ $TOTAL -gt 0 ]; then
    echo "✅ All initialized submodules are protected!"
    exit 0
else
    echo "ℹ️  No submodules to protect"
    exit 0
fi

