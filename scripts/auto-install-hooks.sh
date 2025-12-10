#!/bin/sh
# Auto-install Git hooks using template directory
# This script sets up Git to automatically install hooks on clone

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TEMPLATE_DIR="$REPO_ROOT/.githooks-template"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Error: .githooks-template directory not found"
    exit 1
fi

echo "🔧 Setting up automatic Git hook installation..."
echo ""

# Set template directory for this repository (local config)
git config init.templateDir "$TEMPLATE_DIR"
echo "✔ Template directory configured for this repository"

# Also set globally (optional, but recommended)
read -p "Set template directory globally for all new repos? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git config --global init.templateDir "$TEMPLATE_DIR"
    echo "✔ Template directory configured globally"
else
    echo "ℹ️  Skipping global configuration"
fi

# Install hooks now for this repository
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
    echo "✔ Hooks installed for current repository"
fi

echo ""
echo "✅ Automatic hook installation configured!"
echo ""
echo "📝 How it works:"
echo "   - New clones will automatically get hooks installed"
echo "   - Existing repos: hooks will install on next checkout/pull"
echo "   - Hooks protect main and dev branches automatically"

