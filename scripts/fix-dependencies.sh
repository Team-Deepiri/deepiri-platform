#!/bin/bash

# fix-dependencies.sh
# Script to install dependencies for all Deepiri services

set -e

echo "🔧 Fixing Deepiri Dependencies..."
echo "=================================="

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Fix Node.js services
echo ""
echo "📦 Installing Node.js service dependencies..."
for service in platform-services/backend/*; do
  if [ -f "$service/package.json" ]; then
    echo "  Installing dependencies for $(basename $service)..."
    cd "$service"
    if [ -f "package-lock.json" ]; then
      npm ci --legacy-peer-deps || npm install --legacy-peer-deps
    else
      npm install --legacy-peer-deps
    fi
    cd "$PROJECT_ROOT"
  fi
done

# Install shared utils
if [ -f "platform-services/shared/deepiri-shared-utils/package.json" ]; then
  echo "  Installing dependencies for deepiri-shared-utils..."
  cd "platform-services/shared/deepiri-shared-utils"
  npm install --legacy-peer-deps
  cd "$PROJECT_ROOT"
fi

# Fix API server
if [ -f "deepiri-core-api/package.json" ]; then
  echo "  Installing dependencies for deepiri-core-api..."
  cd "deepiri-core-api"
  if [ -f "package-lock.json" ]; then
    npm ci --legacy-peer-deps || npm install --legacy-peer-deps
  else
    npm install --legacy-peer-deps
  fi
  cd "$PROJECT_ROOT"
fi

# Fix Frontend
if [ -f "deepiri-web-frontend/package.json" ]; then
  echo "  Installing dependencies for deepiri-web-frontend..."
  cd "deepiri-web-frontend"
  if [ -f "package-lock.json" ]; then
    npm ci --legacy-peer-deps || npm install --legacy-peer-deps
  else
    npm install --legacy-peer-deps
  fi
  cd "$PROJECT_ROOT"
fi

# Fix Python backend
echo ""
echo "🐍 Installing Python backend dependencies..."
if [ -f "diri-cyrex/requirements.txt" ]; then
  cd "diri-cyrex"
  if command -v pip3 &> /dev/null; then
    pip3 install -r requirements.txt || echo "⚠️  pip3 install failed, trying pip..."
    pip install -r requirements.txt || echo "⚠️  pip install failed"
  elif command -v pip &> /dev/null; then
    pip install -r requirements.txt || echo "⚠️  pip install failed"
  else
    echo "⚠️  pip not found, skipping Python dependencies"
  fi
  cd "$PROJECT_ROOT"
fi

echo ""
echo "✅ Dependency installation complete!"
echo ""
echo "Next steps:"
echo "  1. Rebuild Docker images: docker-compose -f docker-compose.dev.yml build"
echo "  2. Start services: docker-compose -f docker-compose.dev.yml up -d"

