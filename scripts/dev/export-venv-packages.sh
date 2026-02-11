#!/bin/bash
# Export packages from .dev_venv to a directory that can be used in Docker builds
# This allows Docker builds to use pre-installed packages from the host venv

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(cd "$PROJECT_ROOT/.." && pwd)"
VENV_PATH="$PARENT_DIR/.dev_venv"
EXPORT_DIR="$PROJECT_ROOT/diri-cyrex/.dev_venv_packages"

echo "📦 Exporting packages from .dev_venv..."

if [ ! -d "$VENV_PATH" ]; then
    echo "⚠️  Warning: .dev_venv not found at $VENV_PATH"
    echo "💡 Run ./scripts/setup-dev-venv.sh to create it"
    exit 0  # Not an error, just skip
fi

# Find Python version in venv
PYTHON_VERSION=$(find "$VENV_PATH/lib" -maxdepth 1 -type d -name "python*" | head -1 | xargs basename)
SITE_PACKAGES="$VENV_PATH/lib/$PYTHON_VERSION/site-packages"

if [ ! -d "$SITE_PACKAGES" ]; then
    echo "⚠️  Warning: site-packages not found at $SITE_PACKAGES"
    exit 0
fi

# Create export directory
mkdir -p "$EXPORT_DIR"

# Copy wheel files and package directories
echo "📋 Copying packages..."
rsync -av --include='*.whl' --include='*.egg' --include='*/' --exclude='*' \
    "$SITE_PACKAGES/" "$EXPORT_DIR/" 2>/dev/null || \
    cp -r "$SITE_PACKAGES"/* "$EXPORT_DIR/" 2>/dev/null || true

# Also create a pip download of key packages
echo "⬇️  Downloading key packages as wheels..."
if [ -f "$VENV_PATH/bin/pip" ]; then
    "$VENV_PATH/bin/pip" download --no-deps --dest "$EXPORT_DIR" \
        transformers datasets accelerate sentence-transformers \
        2>/dev/null || true
fi

echo "✅ Packages exported to $EXPORT_DIR"
echo "   This directory will be used by Docker builds"

