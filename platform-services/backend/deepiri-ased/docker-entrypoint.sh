#!/bin/sh
set -e

echo "=== Deepiri ASED Initialization ==="

# Build shared-utils if it exists and isn't built yet
if [ -d "/app/../../shared/deepiri-shared-utils" ]; then
  echo "Building shared-utils..."
  cd /app/../../shared/deepiri-shared-utils
  if [ ! -d "dist" ] || [ "src" -nt "dist" ]; then
    npm install --legacy-peer-deps
    npm run build 2>/dev/null || echo "Shared-utils build skipped (may not have build script)"
  fi
  cd - > /dev/null
fi

# Install shared-utils as local dependency if not already installed
if [ -d "/app/../../shared/deepiri-shared-utils" ] && [ ! -d "/app/node_modules/@deepiri/shared-utils" ]; then
  echo "Linking shared-utils..."
  cd /app
  npm install --legacy-peer-deps file:/app/../../shared/deepiri-shared-utils || echo "Shared-utils install skipped"
fi

# Check if baseline exists
BASELINE_PATH="/app/data/baseline.json"
BASELINE_EXISTS=false

if [ -f "$BASELINE_PATH" ]; then
  echo "Baseline file found at $BASELINE_PATH"
  BASELINE_EXISTS=true
else
  echo "No baseline file found at $BASELINE_PATH"
fi

# Check if GitHub App is configured (preferred method)
if [ -n "$GITHUB_APP_ID" ] && [ -n "$GITHUB_INSTALLATION_ID" ] && [ -n "$GITHUB_APP_PRIVATE_KEY" ]; then
  echo "GitHub App configured:"
  echo "  GITHUB_APP_ID: ${GITHUB_APP_ID}"
  echo "  GITHUB_INSTALLATION_ID: ${GITHUB_INSTALLATION_ID}"
  echo "  GITHUB_APP_PRIVATE_KEY: ${#GITHUB_APP_PRIVATE_KEY} characters"
  GITHUB_AUTH_CONFIGURED=true
elif [ -n "$GITHUB_TOKEN_A" ] && [ -n "$GITHUB_TOKEN_B" ]; then
  echo "GitHub tokens configured (legacy method):"
  echo "  GITHUB_TOKEN_A: ${#GITHUB_TOKEN_A} characters"
  echo "  GITHUB_TOKEN_B: ${#GITHUB_TOKEN_B} characters"
  GITHUB_AUTH_CONFIGURED=true
else
  echo "WARNING: GitHub authentication not configured!"
  echo "  GITHUB_APP_ID: ${GITHUB_APP_ID:+SET}${GITHUB_APP_ID:-NOT SET}"
  echo "  GITHUB_INSTALLATION_ID: ${GITHUB_INSTALLATION_ID:+SET}${GITHUB_INSTALLATION_ID:-NOT SET}"
  echo "  GITHUB_APP_PRIVATE_KEY: ${GITHUB_APP_PRIVATE_KEY:+SET}${GITHUB_APP_PRIVATE_KEY:-NOT SET}"
  echo ""
  echo "The service will start but detection will fail until GitHub App is configured."
  echo "See GITHUB_APP_PERMISSIONS.md for instructions."
  GITHUB_AUTH_CONFIGURED=false
fi

# Check auto-discovery
if [ "$AUTO_DISCOVER_REPOS" = "true" ]; then
  echo "Auto-discovery enabled (pattern: ${REPO_PATTERN:-deepiri-.*})"
  echo "Repositories will be auto-discovered on first run."
else
  if [ -z "$CRITICAL_REPOS" ]; then
    echo "WARNING: CRITICAL_REPOS not configured and auto-discovery disabled!"
    echo "Using default: deepiri-platform"
  else
    echo "Critical repositories: $CRITICAL_REPOS"
  fi
fi

# Establish baseline if it doesn't exist and GitHub auth is configured
if [ "$BASELINE_EXISTS" = false ] && [ "$GITHUB_AUTH_CONFIGURED" = true ]; then
  echo ""
  echo "=== Establishing Baseline ==="
  echo "This will capture the current state of all repositories."
  echo "This may take a few minutes..."
  
  # Run baseline establishment
  if npm run establish-baseline 2>&1; then
    echo "Baseline established successfully!"
  else
    echo "WARNING: Baseline establishment failed!"
    echo "The service will start but state invariant detection will not work."
    echo "Baseline will be established automatically on first detection cycle."
  fi
elif [ "$BASELINE_EXISTS" = false ]; then
  echo ""
  echo "=== Skipping Baseline Establishment ==="
  echo "Baseline not found and GitHub authentication not configured."
  echo "Baseline will be established automatically once GitHub App is configured."
fi

# Create data directories
mkdir -p /app/data /app/logs

echo ""
echo "=== Starting Deepiri ASED Service ==="
echo "Service will start on port ${PORT:-5010}"
echo "Health check: http://localhost:${PORT:-5010}/health"
echo ""

# Start the service
exec node dist/server.js

