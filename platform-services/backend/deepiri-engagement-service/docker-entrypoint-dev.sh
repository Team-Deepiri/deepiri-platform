#!/bin/sh
set -e

# Build shared-utils if it exists and isn't built yet
if [ -d "/app/../../shared/deepiri-shared-utils" ]; then
  echo "Building shared-utils..."
  cd /app/../../shared/deepiri-shared-utils
  if [ ! -d "dist" ] || [ "src" -nt "dist" ]; then
    npm install --legacy-peer-deps
    npm run build
  fi
  cd - > /dev/null
fi

# Install shared-utils as local dependency if not already installed
if [ -d "/app/../../shared/deepiri-shared-utils" ] && [ ! -d "/app/node_modules/@deepiri/shared-utils" ]; then
  echo "Linking shared-utils..."
  cd /app
  npm install --legacy-peer-deps file:/app/../../shared/deepiri-shared-utils
fi

# Run the dev command
exec npm run dev

