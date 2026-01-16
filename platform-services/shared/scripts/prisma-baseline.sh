#!/bin/sh
# Prisma Baseline Migration Script
# Handles baseline migration for existing databases with tables but no migration history
# This script checks if migrations exist, and if not, creates a baseline migration
# Designed to run automatically in Docker containers

PRISMA_DIR="${PRISMA_DIR:-./prisma}"
MIGRATIONS_DIR="${PRISMA_DIR}/migrations"

echo "[Prisma Baseline] Checking Prisma migration status..."

# Check if migrations directory exists
if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo "[Prisma Baseline] Creating migrations directory..."
    mkdir -p "$MIGRATIONS_DIR"
fi

# Check if there are any existing migrations (excluding migration_lock.toml)
HAS_MIGRATIONS=$(ls -A "$MIGRATIONS_DIR" 2>/dev/null | grep -v "migration_lock.toml" | wc -l | tr -d ' ')

if [ "$HAS_MIGRATIONS" -eq 0 ]; then
    echo "[Prisma Baseline] No migrations found. Checking database state..."
    
    # Try to create initial migration
    # This will fail if database has tables (P3005 error), which is expected
    echo "[Prisma Baseline] Attempting to create initial migration..."
    MIGRATE_OUTPUT=$(npx prisma migrate dev --create-only --name init 2>&1) || MIGRATE_EXIT=$?
    
    # Check if the error is P3005 (database not empty)
    if [ -n "$MIGRATE_EXIT" ] && echo "$MIGRATE_OUTPUT" | grep -q "P3005"; then
        echo "[Prisma Baseline] Database has tables but no migrations. Creating baseline migration..."
        
        # Get the migration directory that was created (if any)
        MIGRATION_DIR=$(ls -t "$MIGRATIONS_DIR" 2>/dev/null | grep -v "migration_lock.toml" | head -n 1)
        
        if [ -n "$MIGRATION_DIR" ] && [ -d "$MIGRATIONS_DIR/$MIGRATION_DIR" ]; then
            echo "[Prisma Baseline] Marking migration as applied (baseline): $MIGRATION_DIR"
            if npx prisma migrate resolve --applied "$MIGRATION_DIR" 2>/dev/null; then
                echo "[Prisma Baseline] Baseline migration created and marked as applied."
            else
                echo "[Prisma Baseline] Warning: Could not mark migration as applied automatically."
                echo "[Prisma Baseline] Migration directory exists: $MIGRATION_DIR"
            fi
        else
            echo "[Prisma Baseline] Warning: Could not find migration directory after creation attempt."
            echo "[Prisma Baseline] This may be normal if the database schema matches Prisma schema exactly."
        fi
    elif [ -z "$MIGRATE_EXIT" ] || [ "$MIGRATE_EXIT" -eq 0 ]; then
        echo "[Prisma Baseline] Initial migration created successfully (fresh database)."
    else
        echo "[Prisma Baseline] Migration creation failed with unexpected error. Continuing..."
        echo "[Prisma Baseline] Error output: $MIGRATE_OUTPUT"
    fi
else
    echo "[Prisma Baseline] Migrations already exist ($HAS_MIGRATIONS found). Proceeding with normal migration deployment..."
fi

# Always run migrate deploy to apply any pending migrations
# If _prisma_migrations table doesn't exist, this will create it
echo "[Prisma Baseline] Deploying migrations..."
MIGRATE_DEPLOY_OUTPUT=$(npx prisma migrate deploy 2>&1) || MIGRATE_DEPLOY_EXIT=$?

if [ -z "$MIGRATE_DEPLOY_EXIT" ] || [ "$MIGRATE_DEPLOY_EXIT" -eq 0 ]; then
    echo "[Prisma Baseline] Migrations deployed successfully."
else
    # Check if the error is about missing _prisma_migrations table
    if echo "$MIGRATE_DEPLOY_OUTPUT" | grep -q "_prisma_migrations.*does not exist"; then
        echo "[Prisma Baseline] _prisma_migrations table does not exist. Creating it..."
        
        # Create the migrations table by running migrate resolve on a dummy migration
        # First, ensure we have at least one migration file
        if [ "$HAS_MIGRATIONS" -eq 0 ]; then
            echo "[Prisma Baseline] Creating initial migration to establish migrations table..."
            # Try to create migration one more time
            npx prisma migrate dev --create-only --name init_baseline 2>&1 || true
            MIGRATION_DIR=$(ls -t "$MIGRATIONS_DIR" 2>/dev/null | grep -v "migration_lock.toml" | head -n 1)
            
            if [ -n "$MIGRATION_DIR" ]; then
                echo "[Prisma Baseline] Marking migration as applied to create migrations table..."
                npx prisma migrate resolve --applied "$MIGRATION_DIR" 2>&1 || {
                    echo "[Prisma Baseline] Using db push to sync schema and create migrations table..."
                    npx prisma db push --skip-generate --accept-data-loss 2>&1 || true
                }
            fi
        fi
        
        # Try migrate deploy again
        if npx prisma migrate deploy 2>&1; then
            echo "[Prisma Baseline] Migrations table created and migrations deployed."
        else
            echo "[Prisma Baseline] Warning: Could not deploy migrations. Database may need manual setup."
        fi
    else
        echo "[Prisma Baseline] Warning: migrate deploy failed. This may be normal if migrations are already applied."
    fi
fi

echo "[Prisma Baseline] Prisma migration check complete."

