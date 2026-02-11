#!/bin/sh

# Verify that all submodules have the updated hooks

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

echo "🔍 Verifying hooks in all submodules..."
echo ""

check_submodule() {
    local submodule_path=$1
    local submodule_name=$(basename "$submodule_path")
    
    if [ ! -d "$submodule_path/.git-hooks" ]; then
        echo "❌ $submodule_name: .git-hooks directory missing"
        return 1
    fi
    
    local missing=0
    for hook in pre-push post-checkout post-merge; do
        if [ ! -f "$submodule_path/.git-hooks/$hook" ]; then
            echo "❌ $submodule_name: Missing $hook"
            missing=1
        fi
    done
    
    if [ $missing -eq 0 ]; then
        # Check if pre-push has the updated content (contains "master")
        if grep -q "master" "$submodule_path/.git-hooks/pre-push" 2>/dev/null; then
            echo "✅ $submodule_name: All hooks present and updated"
        else
            echo "⚠️  $submodule_name: Hooks present but may not be updated"
    fi
    fi
}

# Check all submodules
if [ -f ".gitmodules" ]; then
    grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//' | while IFS= read -r submodule_path; do
        [ -z "$submodule_path" ] && continue
        check_submodule "$submodule_path"
    done
fi

echo ""
echo "✅ Verification complete!"
