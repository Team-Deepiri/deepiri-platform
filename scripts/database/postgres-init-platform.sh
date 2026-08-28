#!/bin/sh
# Bootstraps CLOUD postgres-platform for the portal direction.
# Creates role + database `platform`, then applies postgres-init-platform.sql.
#
# Env (compose):
#   POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB   — bootstrap superuser (default postgres image)
#   PLATFORM_DB_USER / PLATFORM_DB_PASSWORD / PLATFORM_DB_NAME
#     defaults: deepiri_platform / (required) / platform
#
# Mount this script + postgres-init-platform.sql into docker-entrypoint-initdb.d
# (or run once against a fresh volume).
# Must be LF line endings and /bin/sh — postgres:*-alpine has no bash.
set -eu

PLATFORM_DB_NAME="${PLATFORM_DB_NAME:-platform}"
PLATFORM_DB_USER="${PLATFORM_DB_USER:-deepiri_platform}"
PLATFORM_DB_PASSWORD="${PLATFORM_DB_PASSWORD:?PLATFORM_DB_PASSWORD must be set}"
SCHEMA_FILE="${PLATFORM_SCHEMA_FILE:-/docker-entrypoint-initdb.d/schemas/platform.sql}"

if [ ! -f "$SCHEMA_FILE" ]; then
  # Local/dev fallback when not running inside the official entrypoint layout
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  SCHEMA_FILE="${SCRIPT_DIR}/postgres-init-platform.sql"
fi

psql_admin() {
  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB:-postgres}" "$@"
}

echo "[postgres-platform] ensuring role ${PLATFORM_DB_USER}"
psql_admin -v role="$PLATFORM_DB_USER" -v password="$PLATFORM_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
SQL

echo "[postgres-platform] ensuring database ${PLATFORM_DB_NAME}"
psql_admin -v dbname="$PLATFORM_DB_NAME" -v role="$PLATFORM_DB_USER" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'dbname', :'role')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'dbname') \gexec
SQL

# Trusted extensions as DB owner
echo "[postgres-platform] applying schema ${SCHEMA_FILE}"
psql -v ON_ERROR_STOP=1 \
  --username "$PLATFORM_DB_USER" \
  --dbname "$PLATFORM_DB_NAME" \
  -f "$SCHEMA_FILE"

echo "[postgres-platform] init complete"
