#!/bin/sh
# Install Git hooks into .git/hooks so they run automatically
# This script should be run once per repository to set up automatic hook configuration

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

echo "🔧 Installing Git hooks for automatic setup..."

# Create .git/hooks directory if it doesn't exist
mkdir -p .git/hooks

# Install post-checkout hook (runs on checkout/clone)
if [ -f ".git-hooks/post-checkout" ]; then
    cp .git-hooks/post-checkout .git/hooks/post-checkout
    chmod +x .git/hooks/post-checkout
    echo "✔ Installed post-checkout hook"
fi

# Install post-merge hook (runs after pull)
if [ -f ".git-hooks/post-merge" ]; then
    cp .git-hooks/post-merge .git/hooks/post-merge
    chmod +x .git/hooks/post-merge
    echo "✔ Installed post-merge hook"
fi

# Configure hooksPath to use .git-hooks for all hooks
git config core.hooksPath .git-hooks

echo "✅ Git hooks installed and configured!"
echo "   Hooks will now automatically configure on checkout and pull."

