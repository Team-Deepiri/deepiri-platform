#!/bin/bash
# Custom entrypoint for pgAdmin that auto-configures PostgreSQL server

# Function to configure server in background
configure_server() {
    PGADMIN_EMAIL="${PGADMIN_DEFAULT_EMAIL:-admin@deepiri.com}"
    STORAGE_DIR="/var/lib/pgadmin/storage/${PGADMIN_EMAIL}"
    MAX_WAIT=90
    WAITED=0
    
    echo "Waiting for pgAdmin to initialize..."
    while [ ! -d "${STORAGE_DIR}" ] && [ $WAITED -lt $MAX_WAIT ]; do
        sleep 3
        WAITED=$((WAITED + 3))
    done
    
    # Copy servers.json if pgAdmin has initialized
    if [ -d "${STORAGE_DIR}" ] && [ -f /pgadmin/servers.json ]; then
        if [ ! -f "${STORAGE_DIR}/servers.json" ]; then
            cp /pgadmin/servers.json "${STORAGE_DIR}/servers.json"
            chown pgadmin:pgadmin "${STORAGE_DIR}/servers.json"
            echo "✓ Auto-configured PostgreSQL server: Deepiri PostgreSQL"
        fi
    fi
}

# Start server configuration in background
configure_server &

# Call the original pgAdmin entrypoint
exec /entrypoint.sh "$@"

