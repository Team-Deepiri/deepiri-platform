#!/bin/bash

# ===========================
# DEEPIRI POSTGRESQL RESTORE SCRIPT
# ===========================

set -e  # Exit on error

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups/postgres}"

# Database connection (from environment or defaults)
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-deepiri}"
POSTGRES_USER="${POSTGRES_USER:-deepiri}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Deepiri PostgreSQL Restore Script    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

# List available backups
echo -e "${YELLOW}📂 Available backups:${NC}"
echo ""

BACKUPS=($(ls -t "$BACKUP_DIR"/deepiri_backup_*.sql.gz 2>/dev/null || true))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No backups found in $BACKUP_DIR${NC}"
    exit 1
fi

# Display backups with numbers
for i in "${!BACKUPS[@]}"; do
    BACKUP_FILE="${BACKUPS[$i]}"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    BACKUP_DATE=$(stat -c %y "$BACKUP_FILE" 2>/dev/null || stat -f "%Sm" "$BACKUP_FILE" 2>/dev/null)
    echo -e "  ${BLUE}[$((i+1))]${NC} $(basename "$BACKUP_FILE") (${BACKUP_SIZE}) - ${BACKUP_DATE}"
done

echo ""

# Choose backup file
if [ -n "$1" ]; then
    # Backup file specified as argument
    if [ -f "$1" ]; then
        RESTORE_FILE="$1"
    elif [ -f "${BACKUP_DIR}/$1" ]; then
        RESTORE_FILE="${BACKUP_DIR}/$1"
    else
        echo -e "${RED}❌ Backup file not found: $1${NC}"
        exit 1
    fi
else
    # Interactive selection
    read -p "Select backup to restore (1-${#BACKUPS[@]}) or 'q' to quit: " selection
    
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        exit 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#BACKUPS[@]} ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi
    
    RESTORE_FILE="${BACKUPS[$((selection-1))]}"
fi

echo ""
echo -e "${YELLOW}Selected backup:${NC} $(basename "$RESTORE_FILE")"
echo ""

# Warning
echo -e "${RED}⚠️  WARNING: This will COMPLETELY REPLACE the current database!${NC}"
echo -e "${RED}   Database: ${POSTGRES_DB}${NC}"
echo -e "${RED}   Host: ${POSTGRES_HOST}:${POSTGRES_PORT}${NC}"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

echo ""

# Check PostgreSQL connection
echo -e "${YELLOW}📡 Checking PostgreSQL connection...${NC}"
if ! PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "postgres" -c '\q' 2>/dev/null; then
    echo -e "${RED}❌ Cannot connect to PostgreSQL!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"
echo ""

# Create a safety backup before restore
SAFETY_BACKUP="${BACKUP_DIR}/pre_restore_safety_$(date +"%Y%m%d_%H%M%S").sql.gz"
echo -e "${YELLOW}💾 Creating safety backup before restore...${NC}"
echo -e "   Location: ${SAFETY_BACKUP}"

PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --clean \
    --if-exists \
    --format=plain \
    --no-owner \
    --no-privileges \
    2>/dev/null | gzip > "$SAFETY_BACKUP"

echo -e "${GREEN}✅ Safety backup created${NC}"
echo ""

# Drop existing database (if exists)
echo -e "${YELLOW}🗑️  Dropping existing database...${NC}"
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "postgres" \
    -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};" \
    2>&1 | grep -v "NOTICE" || true

# Create fresh database
echo -e "${YELLOW}🆕 Creating fresh database...${NC}"
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "postgres" \
    -c "CREATE DATABASE ${POSTGRES_DB};" \
    2>&1 | grep -v "NOTICE" || true

echo -e "${GREEN}✅ Database recreated${NC}"
echo ""

# Restore from backup
echo -e "${YELLOW}📥 Restoring from backup...${NC}"
echo -e "   This may take a few minutes..."
echo ""

# Decompress and restore
gunzip -c "$RESTORE_FILE" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --set ON_ERROR_STOP=on \
    2>&1 | grep -E "(ERROR|FATAL|WARNING)" || true

echo ""
echo -e "${GREEN}✅ Restore completed successfully!${NC}"
echo ""

# Verify restore
echo -e "${YELLOW}🔍 Verifying restore...${NC}"
TABLE_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('public', 'analytics', 'audit');" \
    2>/dev/null | tr -d ' ')

USER_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -t -c "SELECT COUNT(*) FROM public.users;" \
    2>/dev/null | tr -d ' ')

echo -e "   Tables restored: ${TABLE_COUNT}"
echo -e "   Users restored: ${USER_COUNT}"
echo ""

# Run VACUUM ANALYZE for optimal performance
echo -e "${YELLOW}🔧 Running VACUUM ANALYZE...${NC}"
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "VACUUM ANALYZE;" \
    2>&1 | grep -v "NOTICE" || true

echo -e "${GREEN}✅ Optimization complete${NC}"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Restore Complete! 🎉                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}ℹ️  Safety backup saved at:${NC}"
echo -e "   ${SAFETY_BACKUP}"
echo ""

# Optional: Send notification (uncomment to enable)
# if [ -n "$SLACK_WEBHOOK_URL" ]; then
#     curl -X POST "$SLACK_WEBHOOK_URL" \
#         -H 'Content-Type: application/json' \
#         -d "{\"text\":\"✅ Deepiri PostgreSQL restore completed from: $(basename "$RESTORE_FILE")\"}"
# fi

exit 0

