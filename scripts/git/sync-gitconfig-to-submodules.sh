#!/bin/sh
# Sync .gitconfig from main repo to all submodules
# This ensures all submodules have the same git configuration

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

if [ ! -f ".gitconfig" ]; then
    echo "❌ Error: .gitconfig file not found in main repository"
    exit 1
fi

echo "🔄 Syncing .gitconfig to all submodules..."
echo ""

# Function to sync .gitconfig to a submodule
sync_gitconfig_to_submodule() {
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
    
    echo "📦 Syncing .gitconfig to $submodule_name..."
    cp "$REPO_ROOT/.gitconfig" "$submodule_path/.gitconfig"
    echo "   ✓ .gitconfig copied to $submodule_name"
}

# Sync .gitconfig to all submodules listed in .gitmodules
if [ -f ".gitmodules" ]; then
    echo "📋 Found submodules in .gitmodules:"
    # Extract submodule paths from .gitmodules (handles tabs and spaces)
    # This ensures we catch ALL submodules regardless of formatting
    submodule_count=0
    # Extract submodule paths from .gitmodules (handles tabs and spaces)
    # This ensures we catch ALL submodules regardless of formatting
    grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//' | sed 's/[[:space:]]*$//' | while IFS= read -r submodule_path; do
        # Skip empty lines
        [ -z "$submodule_path" ] && continue
        
        submodule_count=$((submodule_count + 1))
        submodule_name=$(basename "$submodule_path")
        echo "   $submodule_count. $submodule_name ($submodule_path)"
        sync_gitconfig_to_submodule "$submodule_path" "$submodule_name"
    done
    echo ""
else
    echo "⚠️  Warning: .gitmodules file not found"
fi

echo ""
echo "✅ .gitconfig sync complete for all submodules!"
echo ""

