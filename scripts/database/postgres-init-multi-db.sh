#!/bin/bash
# Bootstraps the consolidated single-container Postgres instance used by the
# cheap one-box prod compose (docker-compose.yml / docker-compose.local-prod.yml).
#
# Previously auth/core/intelligence each got their own postgres:16-alpine
# container with its own default database. This script creates one role +
# one logical database per tenant instead, then applies that tenant's
# existing schema file (originally written to run as the container's sole
# default database) inside its own database. Idempotent, though the
# official postgres image only invokes docker-entrypoint-initdb.d scripts
# on a first-ever init of the data directory.
set -euo pipefail

psql_admin() {
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" "$@"
}

create_tenant() {
  local role="$1" password="$2" db="$3" schema_file="$4"

  psql_admin -v role="$role" -v password="$password" <<-'SQL'
		SELECT format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'role', :'password')
		WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
	SQL

  psql_admin -v dbname="$db" -v role="$role" <<-'SQL'
		SELECT format('CREATE DATABASE %I OWNER %I', :'dbname', :'role')
		WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'dbname') \gexec
	SQL

  # Runs as the tenant role itself so tables/extensions it creates are owned
  # by that role, not the bootstrap superuser. uuid-ossp/pg_trgm/btree_gin
  # are all "trusted" extensions (PG13+), so the database owner can create
  # them without needing superuser.
  psql -v ON_ERROR_STOP=1 --username "$role" --dbname "$db" -f "$schema_file"
}

create_tenant "$POSTGRES_AUTH_USER" "$POSTGRES_AUTH_PASSWORD" "$POSTGRES_AUTH_DB" \
  /docker-entrypoint-initdb.d/schemas/auth.sql
create_tenant "$POSTGRES_CORE_USER" "$POSTGRES_CORE_PASSWORD" "$POSTGRES_CORE_DB" \
  /docker-entrypoint-initdb.d/schemas/core.sql
create_tenant "$POSTGRES_INTELLIGENCE_USER" "$POSTGRES_INTELLIGENCE_PASSWORD" "$POSTGRES_INTELLIGENCE_DB" \
  /docker-entrypoint-initdb.d/schemas/intelligence.sql
