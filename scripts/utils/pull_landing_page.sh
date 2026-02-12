#!/bin/bash

# Landing Page Integration Script
# Clones the deepiri-landing repository

echo "🚀 Cloning deepiri-landing repository..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install Git first."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the parent directory (deepiri-platform)
PLATFORM_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
# Get the parent directory above deepiri-platform
PARENT_DIR="$( cd "$PLATFORM_DIR/.." && pwd )"

# Set the target directory for the landing page (in parent folder, not tracked by git)
LANDING_DIR="$PARENT_DIR/deepiri-landing"

# Check if the directory already exists
if [ -d "$LANDING_DIR" ]; then
    echo "⚠️  Directory $LANDING_DIR already exists."
    read -p "Do you want to remove it and clone fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing existing directory..."
        rm -rf "$LANDING_DIR"
    else
        echo "ℹ️  Keeping existing directory. Exiting."
        exit 0
    fi
fi

# Clone the repository
echo "📥 Cloning git@github.com:Team-Deepiri/deepiri-landing.git..."
echo "ℹ️  Note: This repository will NOT be tracked as a git submodule"
echo ""
if git clone git@github.com:Team-Deepiri/deepiri-landing.git "$LANDING_DIR"; then
    echo "✅ Successfully cloned deepiri-landing to $LANDING_DIR"
    echo ""
    echo "📁 Landing page is now available at:"
    echo "   $LANDING_DIR"
    echo ""
    echo "ℹ️  This repository is NOT tracked by deepiri-platform (not a submodule)"
else
    echo "❌ Failed to clone repository. Please check:"
    echo "   1. Your SSH key is set up with GitHub"
    echo "   2. You have access to the Team-Deepiri/deepiri-landing repository"
    echo "   3. Your network connection is working"
    exit 1
fi

