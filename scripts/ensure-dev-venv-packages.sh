#!/bin/bash
# Ensure .dev_venv_packages directory exists (even if empty) to prevent Docker COPY failures
# This script should be run before building if .dev_venv_packages doesn't exist

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$PROJECT_ROOT/diri-cyrex/.dev_venv_packages"

if [ ! -d "$PACKAGES_DIR" ]; then
    echo "Creating empty .dev_venv_packages directory..."
    mkdir -p "$PACKAGES_DIR"
    touch "$PACKAGES_DIR/.keep"
    echo "✓ Created empty .dev_venv_packages directory"
    echo "  Run: bash scripts/export-venv-packages.sh to populate it"
else
    echo "✓ .dev_venv_packages already exists"
fi

