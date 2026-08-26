#!/bin/bash

# ===========================
# DEEPIRI POSTGRESQL RESTORE SCRIPT
# ===========================
#
# Restores a full-cluster pg_dumpall backup (see postgres-backup.sh) — not a
# single database. The dump itself contains DROP/CREATE ROLE and
# DROP/CREATE DATABASE statements plus \connect switches for
# platform_auth, platform_core, and platform_intelligence, so it's applied
# by piping the whole file into psql connected to the `postgres`
# maintenance database, not by dropping/recreating one target database.

set -e  # Exit on error

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups/postgres}"

# Database connection (from environment or defaults) — connects as the
# bootstrap superuser, since the restore recreates roles/databases.
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
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

BACKUPS=($(ls -t "$BACKUP_DIR"/deepiri_cluster_backup_*.sql.gz 2>/dev/null || true))

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
echo -e "${RED}⚠️  WARNING: This will COMPLETELY REPLACE every database and role in the cluster!${NC}"
echo -e "${RED}   (platform_auth, platform_core, platform_intelligence, and their roles)${NC}"
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

# Create a safety backup (full cluster) before restore
SAFETY_BACKUP="${BACKUP_DIR}/pre_restore_safety_$(date +"%Y%m%d_%H%M%S").sql.gz"
echo -e "${YELLOW}💾 Creating safety backup before restore...${NC}"
echo -e "   Location: ${SAFETY_BACKUP}"

PGPASSWORD="$POSTGRES_PASSWORD" pg_dumpall \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$POSTGRES_USER" \
    --clean \
    --if-exists \
    2>/dev/null | gzip > "$SAFETY_BACKUP"

echo -e "${GREEN}✅ Safety backup created${NC}"
echo ""

# Restore from backup — apply the whole cluster dump against the `postgres`
# maintenance database. The dump's own DROP/CREATE DATABASE and \connect
# statements handle platform_auth/platform_core/platform_intelligence.
echo -e "${YELLOW}📥 Restoring from backup...${NC}"
echo -e "   This may take a few minutes..."
echo ""

# pg_dumpall --clean emits `DROP ROLE IF EXISTS <role>;` / `CREATE ROLE <role>;`
# for every role, including whichever one we connect as to run the restore
# (POSTGRES_USER). Postgres refuses to let a role drop itself mid-session
# ("current user cannot be dropped"), so that one DROP always fails, and then
# CREATE ROLE fails too ("already exists") since the drop never happened.
# The role already exists with the right attributes either way — the
# following ALTER ROLE line (password, attributes) still runs and re-syncs
# it — so it's safe to just strip these two self-referential statements
# rather than let them hard-fail the whole restore under ON_ERROR_STOP.
# grep exits 1 on the happy path (no ERROR/FATAL/WARNING lines found) — under
# `set -e`, grep being last in the pipe and exiting 1 would kill the script
# right here on every *successful* restore. Appending `|| true` would dodge
# that, but it also collapses PIPESTATUS down to just `true`'s own trivial
# status, destroying the real gunzip/sed/psql exit codes we need below —
# confirmed empirically, not just in theory. Toggling `set -e` off for just
# this pipeline avoids the kill without touching PIPESTATUS at all.
set +e
gunzip -c "$RESTORE_FILE" \
    | sed -e "/^DROP ROLE IF EXISTS ${POSTGRES_USER};\$/d" -e "/^CREATE ROLE ${POSTGRES_USER};\$/d" \
    | PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "postgres" \
        -v ON_ERROR_STOP=1 \
        2>&1 | grep -E "(ERROR|FATAL|WARNING)"
# ON_ERROR_STOP=1 makes psql itself exit non-zero on the first real SQL error
# instead of just printing it and continuing (its default behavior with no
# flag at all) — gunzip/sed/psql's own exit codes are what actually matter
# here, not grep's. Must capture the whole array in one statement — it gets
# overwritten by the very next simple command, so reading each element on
# separate lines silently loses everything but the first.
pipe_status=("${PIPESTATUS[@]}")
set -e
gunzip_status=${pipe_status[0]}
psql_status=${pipe_status[2]}
if [ "$gunzip_status" -ne 0 ] || [ "$psql_status" -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Restore failed (gunzip exit ${gunzip_status}, psql exit ${psql_status})${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Restore completed successfully!${NC}"
echo ""

# Verify restore — spot-check each logical database, not just one
echo -e "${YELLOW}🔍 Verifying restore...${NC}"
for pair in "platform_auth:auth" "platform_core:core" "platform_intelligence:intelligence"; do
    db="${pair%%:*}"
    label="${pair##*:}"
    table_count=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$db" \
        -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema')" \
        2>/dev/null || echo "?")
    echo -e "   ${label} (${db}): ${table_count} tables"
done
echo ""

# Run VACUUM ANALYZE on each database for optimal performance
echo -e "${YELLOW}🔧 Running VACUUM ANALYZE...${NC}"
for db in platform_auth platform_core platform_intelligence; do
    PGPASSWORD="$POSTGRES_PASSWORD" psql \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$db" \
        -c "VACUUM ANALYZE;" \
        2>&1 | grep -v "NOTICE" || true
    # VACUUM ANALYZE output is almost entirely NOTICE lines on a clean run, so
    # grep -v exiting 1 (nothing left to print) is the normal case, not a
    # failure — but that also means it can't tell us whether psql itself
    # failed. Check psql's own exit code directly instead; non-fatal since
    # this is a post-restore optimization, not the restore itself.
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo -e "${YELLOW}⚠️  VACUUM ANALYZE failed on ${db} (non-fatal, restore data is unaffected)${NC}"
    fi
done

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
