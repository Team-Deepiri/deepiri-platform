#!/usr/bin/env bash
set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
OUT=${1:-backups}/mongo-$TS
mkdir -p "$OUT"
echo "Backing up MongoDB to $OUT"
docker exec deepiri-mongodb mongodump --archive --gzip > "$OUT/mongo.archive.gz"
echo "Done"


