#!/bin/bash
# Setup development virtual environment one level above deepiri
# Creates .dev_venv in the parent directory

set -e

# Get the directory one level above deepiri
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(cd "$PROJECT_ROOT/.." && pwd)"
VENV_PATH="$PARENT_DIR/.dev_venv"

echo "🔧 Setting up development virtual environment..."
echo "📍 Location: $VENV_PATH"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found. Please install Python 3.11 or later." >&2
    exit 1
fi

# Create venv if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv "$VENV_PATH"
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Activate and upgrade pip
echo "⬆️  Upgrading pip..."
source "$VENV_PATH/bin/activate"
pip install --upgrade pip setuptools wheel

# Install development dependencies if requirements.txt exists
if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    echo "📥 Installing development dependencies..."
    pip install -r "$PROJECT_ROOT/requirements.txt"
    echo "✅ Dependencies installed"
fi

echo ""
echo "✅ Development environment ready!"
echo ""
echo "To activate the virtual environment, run:"
echo "  source $VENV_PATH/bin/activate"
echo ""
echo "Or use the activation script:"
echo "  source $PROJECT_ROOT/scripts/activate-dev-venv.sh"

