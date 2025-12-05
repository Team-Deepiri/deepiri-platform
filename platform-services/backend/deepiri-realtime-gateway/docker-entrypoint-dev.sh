#!/bin/bash
set -euo pipefail

# Development entrypoint: ensures dependencies are installed and built

echo "[entrypoint-dev] Starting realtime-gateway in development mode..."

# Fix permissions for mounted volumes (run as root, then switch to nodejs user)
if [ "$(id -u)" = "0" ]; then
  echo "[entrypoint-dev] Fixing permissions for mounted volumes..."
  chown -R nodejs:nodejs /app /shared-utils 2>/dev/null || true
  
  # Re-execute this script as nodejs user
  exec su-exec nodejs "$0" "$@"
fi

# Now running as nodejs user

# Rebuild shared-utils if needed
if [ -d "/shared-utils" ] && [ -f "/shared-utils/package.json" ]; then
  echo "[entrypoint-dev] Installing shared-utils dependencies..."
  cd /shared-utils
  npm cache clean --force
  # Remove contents of node_modules instead of the directory itself (it might be a volume mount)
  rm -rf node_modules/* node_modules/.* 2>/dev/null || true
  npm install --legacy-peer-deps
  npm run build
fi

# Install app dependencies
echo "[entrypoint-dev] Installing app dependencies..."
cd /app
npm cache clean --force
rm -rf node_modules/* node_modules/.* dist 2>/dev/null || true
npm install --legacy-peer-deps
if [ -d "/shared-utils/dist" ]; then
  npm install --legacy-peer-deps file:/shared-utils
fi

# Rebuild TypeScript
if [ -d "/app/src" ]; then
  echo "[entrypoint-dev] Building TypeScript..."
  npm run build
fi

# Run the service
echo "[entrypoint-dev] Starting service..."
exec /usr/bin/dumb-init -- npm start
