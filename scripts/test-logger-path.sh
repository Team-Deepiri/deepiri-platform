#!/bin/bash
# Test script to check logger path resolution

SERVICE=$1

if [ -z "$SERVICE" ]; then
  echo "Usage: $0 <service-name>"
  exit 1
fi

echo "Testing logger path for $SERVICE..."
echo ""

# Check if utils directory exists
echo "1. Checking /app/utils directory:"
docker-compose -f docker-compose.dev.yml run --rm --entrypoint='' $SERVICE sh -c 'ls -la /app/utils/ 2>&1 || echo "Utils directory not found"'

echo ""
echo "2. Checking logger.js file:"
docker-compose -f docker-compose.dev.yml run --rm --entrypoint='' $SERVICE sh -c 'test -f /app/utils/logger.js && echo "✓ logger.js exists" || echo "✗ logger.js missing"'

echo ""
echo "3. Testing require from /app/src:"
docker-compose -f docker-compose.dev.yml run --rm --entrypoint='' $SERVICE sh -c 'cd /app/src && node -e "try { const logger = require(\"../../utils/logger\"); console.log(\"✓ SUCCESS: Logger loaded\"); } catch(e) { console.log(\"✗ ERROR:\", e.message); process.exit(1); }"'

echo ""
echo "4. Checking file structure:"
docker-compose -f docker-compose.dev.yml run --rm --entrypoint='' $SERVICE sh -c 'echo "Current dir structure:" && pwd && ls -la /app/ && echo "" && echo "Utils:" && ls -la /app/utils/ 2>&1'

