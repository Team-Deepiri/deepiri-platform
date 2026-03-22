#!/bin/bash

# ===========================
# DEEPIRI POSTGRESQL BACKUP SCRIPT
# ===========================

set -e  # Exit on error

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups/postgres}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="deepiri_backup_${TIMESTAMP}.sql"
BACKUP_FILE_COMPRESSED="deepiri_backup_${TIMESTAMP}.sql.gz"

# Database connection (from environment or defaults)
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-deepiri}"
POSTGRES_USER="${POSTGRES_USER:-deepiri}"

# Retention policy (keep backups for 30 days by default)
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Deepiri PostgreSQL Backup Script     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if PostgreSQL is accessible
echo -e "${YELLOW}📡 Checking PostgreSQL connection...${NC}"
if ! PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' 2>/dev/null; then
    echo -e "${RED}❌ Cannot connect to PostgreSQL!${NC}"
    echo -e "${RED}   Host: $POSTGRES_HOST:$POSTGRES_PORT${NC}"
    echo -e "${RED}   Database: $POSTGRES_DB${NC}"
    echo -e "${RED}   User: $POSTGRES_USER${NC}"
    exit 1
fi
echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"
echo ""

# Perform backup
echo -e "${YELLOW}💾 Creating backup...${NC}"
echo -e "   Backup file: ${BACKUP_DIR}/${BACKUP_FILE_COMPRESSED}"
echo ""

# Use pg_dump to create backup
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --verbose \
    --clean \
    --if-exists \
    --format=plain \
    --no-owner \
    --no-privileges \
    --file="${BACKUP_DIR}/${BACKUP_FILE}" \
    2>&1 | grep -v "NOTICE"

# Compress the backup
echo -e "${YELLOW}🗜️  Compressing backup...${NC}"
gzip -f "${BACKUP_DIR}/${BACKUP_FILE}"

# Get backup size
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE_COMPRESSED}" | cut -f1)

echo ""
echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo -e "   File: ${BACKUP_FILE_COMPRESSED}"
echo -e "   Size: ${BACKUP_SIZE}"
echo -e "   Location: ${BACKUP_DIR}/"
echo ""

# Create a 'latest' symlink
ln -sf "${BACKUP_FILE_COMPRESSED}" "${BACKUP_DIR}/latest.sql.gz"
echo -e "${GREEN}🔗 Created symlink: latest.sql.gz${NC}"
echo ""

# Clean up old backups based on retention policy
echo -e "${YELLOW}🧹 Cleaning up old backups (older than ${RETENTION_DAYS} days)...${NC}"
OLD_BACKUPS=$(find "$BACKUP_DIR" -name "deepiri_backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS})

if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | while read -r backup; do
        rm -f "$backup"
        echo -e "   ${RED}Deleted:${NC} $(basename "$backup")"
    done
else
    echo -e "   ${GREEN}No old backups to clean${NC}"
fi

echo ""

# List recent backups
echo -e "${YELLOW}📂 Recent backups:${NC}"
ls -lht "$BACKUP_DIR"/deepiri_backup_*.sql.gz 2>/dev/null | head -5 | awk '{print "   " $9 " (" $5 ") - " $6 " " $7 " " $8}'

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Backup Complete! 🎉                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

# Optional: Upload to cloud storage (uncomment to enable)
# if [ -n "$AWS_S3_BACKUP_BUCKET" ]; then
#     echo -e "${YELLOW}☁️  Uploading to S3...${NC}"
#     aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE_COMPRESSED}" "s3://${AWS_S3_BACKUP_BUCKET}/postgres/"
#     echo -e "${GREEN}✅ Uploaded to S3${NC}"
# fi

# Optional: Send notification (uncomment to enable)
# if [ -n "$SLACK_WEBHOOK_URL" ]; then
#     curl -X POST "$SLACK_WEBHOOK_URL" \
#         -H 'Content-Type: application/json' \
#         -d "{\"text\":\"✅ Deepiri PostgreSQL backup completed: ${BACKUP_FILE_COMPRESSED} (${BACKUP_SIZE})\"}"
# fi

exit 0

