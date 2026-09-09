#!/bin/sh
# Pushes local Postgres backups (see postgres-backup.sh) to off-box,
# S3-compatible storage (AWS S3, Cloudflare R2, Backblaze B2, DO Spaces,
# MinIO — anything speaking the S3 API) so a backup doesn't just live on
# the same disk as the database it's backing up.
#
# Disabled by default (BACKUP_OFFSITE_ENABLED must be explicitly "true") —
# picking/provisioning the actual bucket+account is an infra decision, not
# a code one, so this stays a safe no-op until someone opts in.
#
# Uses `rclone copy` (never `sync`), deliberately additive-only: local
# retention pruning old backups should never delete the off-box copies.
set -eu

if [ "${BACKUP_OFFSITE_ENABLED:-false}" != "true" ]; then
  echo "postgres-backup-offsite-sync: BACKUP_OFFSITE_ENABLED is not 'true', skipping (backups stay local-only)."
  exit 0
fi

: "${BACKUP_OFFSITE_BUCKET:?Set BACKUP_OFFSITE_BUCKET when BACKUP_OFFSITE_ENABLED=true}"
: "${BACKUP_OFFSITE_ACCESS_KEY_ID:?Set BACKUP_OFFSITE_ACCESS_KEY_ID when BACKUP_OFFSITE_ENABLED=true}"
: "${BACKUP_OFFSITE_SECRET_ACCESS_KEY:?Set BACKUP_OFFSITE_SECRET_ACCESS_KEY when BACKUP_OFFSITE_ENABLED=true}"

BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_OFFSITE_PREFIX="${BACKUP_OFFSITE_PREFIX:-postgres-backups}"
# "Other" is rclone's generic S3-compatible provider — works against any
# S3 API implementation. Override to AWS/Cloudflare/Minio/etc. for
# provider-specific quirks rclone knows how to handle.
BACKUP_OFFSITE_PROVIDER="${BACKUP_OFFSITE_PROVIDER:-Other}"

export RCLONE_CONFIG_OFFSITE_TYPE="s3"
export RCLONE_CONFIG_OFFSITE_PROVIDER="$BACKUP_OFFSITE_PROVIDER"
export RCLONE_CONFIG_OFFSITE_ACCESS_KEY_ID="$BACKUP_OFFSITE_ACCESS_KEY_ID"
export RCLONE_CONFIG_OFFSITE_SECRET_ACCESS_KEY="$BACKUP_OFFSITE_SECRET_ACCESS_KEY"
[ -n "${BACKUP_OFFSITE_ENDPOINT:-}" ] && export RCLONE_CONFIG_OFFSITE_ENDPOINT="$BACKUP_OFFSITE_ENDPOINT"
[ -n "${BACKUP_OFFSITE_REGION:-}" ] && export RCLONE_CONFIG_OFFSITE_REGION="$BACKUP_OFFSITE_REGION"

echo "postgres-backup-offsite-sync: copying ${BACKUP_DIR}/*.sql.gz -> offsite:${BACKUP_OFFSITE_BUCKET}/${BACKUP_OFFSITE_PREFIX}/"
rclone copy "$BACKUP_DIR" "offsite:${BACKUP_OFFSITE_BUCKET}/${BACKUP_OFFSITE_PREFIX}/" \
  --include "*.sql.gz" \
  --checksum \
  -v

echo "postgres-backup-offsite-sync: done."
