#!/bin/sh
# Automated Git Hooks Installation Service
# This script installs hooks for the main repo and all submodules
# Can be run manually or as part of CI/CD

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

echo "🚀 Git Hooks Installation Service"
echo "=================================="
echo ""

# Step 1: Install hooks for main repository
echo "📦 Step 1: Installing hooks for main repository..."
if [ -d ".git-hooks" ]; then
    mkdir -p .git/hooks
    for hook in .git-hooks/*; do
        if [ -f "$hook" ] && [ -x "$hook" ]; then
            hook_name=$(basename "$hook")
            cp "$hook" ".git/hooks/$hook_name"
            chmod +x ".git/hooks/$hook_name"
        fi
    done
    git config core.hooksPath .git-hooks
    echo "✔ Main repository hooks installed"
else
    echo "❌ Error: .git-hooks directory not found"
    exit 1
fi
echo ""

# Step 2: Sync hooks to all submodules
echo "📦 Step 2: Syncing hooks to all submodules..."
if [ -f "scripts/sync-hooks-to-submodules.sh" ]; then
    chmod +x scripts/sync-hooks-to-submodules.sh
    ./scripts/sync-hooks-to-submodules.sh
else
    echo "❌ Error: sync-hooks-to-submodules.sh not found"
    exit 1
fi

echo ""
echo "✅ Git Hooks Installation Service Complete!"
echo ""
echo "🛡️  Protection Status:"
echo "   - Main repository: Protected (main, dev, master, team-dev branches)"
echo "   - All submodules: Protected (main, dev, master, team-dev branches)"
echo ""
echo "📝 Next steps:"
echo "   - Hooks will automatically install on checkout (post-checkout)"
echo "   - Hooks will automatically update on pull (post-merge)"
echo "   - All pushes to protected branches (main, dev, master, team-dev) will be rejected"

