#!/bin/sh

# This script sets up Git to use our hook template directory
# Run this once to enable automatic hook installation for all future clones

echo "🔧 Setting up Git hook template directory..."

# Get the absolute path to the repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
TEMPLATE_DIR="$REPO_ROOT/.githooks-template"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Error: .githooks-template directory not found"
    exit 1
fi

# Configure Git to use our template directory
git config --global init.templateDir "$TEMPLATE_DIR"

echo "✔ Git hook template configured globally"
echo "   All new Git repositories will automatically get protected hooks"
echo ""
echo "Note: Existing repos need to run: git config core.hooksPath .git-hooks"

