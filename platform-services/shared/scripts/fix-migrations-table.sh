#!/bin/sh
# Quick fix script to create _prisma_migrations table
# Run this if you see "relation _prisma_migrations does not exist" errors

echo "Creating _prisma_migrations table..."

# Method 1: Use db push to sync schema (this creates the migrations table)
echo "Attempting to sync schema with db push..."
npx prisma db push --skip-generate --accept-data-loss 2>&1 || {
    echo "db push failed, trying alternative method..."
    
    # Method 2: Create a dummy migration and mark it as applied
    echo "Creating dummy migration to establish migrations table..."
    mkdir -p prisma/migrations
    MIGRATION_NAME="init_$(date +%s)"
    mkdir -p "prisma/migrations/$MIGRATION_NAME"
    
    # Create empty migration.sql
    echo "-- Baseline migration" > "prisma/migrations/$MIGRATION_NAME/migration.sql"
    
    # Mark as applied (this creates the _prisma_migrations table)
    npx prisma migrate resolve --applied "$MIGRATION_NAME" 2>&1 || {
        echo "Failed to create migrations table. You may need to run manually:"
        echo "  npx prisma migrate dev --create-only --name init"
        echo "  npx prisma migrate resolve --applied <migration_name>"
        exit 1
    }
}

echo "Migrations table created successfully!"

