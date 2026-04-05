#!/bin/sh
# Setup script for Git hooks (backup/manual setup)
# Note: Hooks are automatically configured on clone, but you can run this if needed

echo "🔧 Setting up Git hooks..."
git config core.hooksPath .git-hooks

if [ -f .git-hooks/pre-push ]; then
    echo "✔ Git hooks enabled. You are now protected from pushing to 'main', 'master', and branches containing 'team-dev'."
else
    echo "⚠️  Warning: .git-hooks/pre-push not found. Make sure you're in the repository root."
    exit 1
fi

