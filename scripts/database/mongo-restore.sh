#!/usr/bin/env bash
set -euo pipefail

ARCHIVE=${1:?"Usage: $0 <path-to-archive.gz>"}
echo "Restoring MongoDB from $ARCHIVE"
cat "$ARCHIVE" | docker exec -i deepiri-mongodb mongorestore --archive --gzip --drop
echo "Done"


