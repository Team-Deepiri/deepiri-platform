#!/bin/bash
# Activate the development virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_DIR="$(cd "$PROJECT_ROOT/.." && pwd)"
VENV_PATH="$PARENT_DIR/.dev_venv"

if [ ! -d "$VENV_PATH" ]; then
    echo "❌ Virtual environment not found at $VENV_PATH"
    echo "💡 Run ./scripts/setup-dev-venv.sh to create it"
    return 1 2>/dev/null || exit 1
fi

source "$VENV_PATH/bin/activate"
echo "✅ Activated virtual environment: $VENV_PATH"

