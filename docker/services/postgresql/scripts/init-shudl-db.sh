#!/bin/bash
# PostgreSQL Database Initialization Script for ShuDL
# This script runs during PostgreSQL initialization via /docker-entrypoint-initdb.d/
# It creates the necessary databases and users for the ShuDL platform

set -e

echo "=== ShuDL Database Initialization ==="
echo "Creating ShuDL-specific databases and users..."

# Default values (can be overridden by environment variables)
SHUDL_DB=${SHUDL_DB:-shudl}
SHUDL_USER=${SHUDL_USER:-shudl}
SHUDL_PASSWORD=${SHUDL_PASSWORD:-password123}
NESSIE_DB=${NESSIE_DB:-nessie}

# Create ShuDL user if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create ShuDL user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$SHUDL_USER') THEN
            CREATE USER $SHUDL_USER WITH PASSWORD '$SHUDL_PASSWORD';
            GRANT CREATE ON SCHEMA public TO $SHUDL_USER;
        END IF;
    END
    \$\$;

    -- Create ShuDL database
    SELECT 'CREATE DATABASE $SHUDL_DB OWNER $SHUDL_USER'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$SHUDL_DB')\gexec

    -- Create Nessie database for catalog backend
    SELECT 'CREATE DATABASE $NESSIE_DB OWNER $SHUDL_USER'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$NESSIE_DB')\gexec
EOSQL

# Grant privileges on databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE $SHUDL_DB TO $SHUDL_USER;
    GRANT ALL PRIVILEGES ON DATABASE $NESSIE_DB TO $SHUDL_USER;
EOSQL

echo "ShuDL databases created successfully:"
echo "  - Database: $SHUDL_DB (owner: $SHUDL_USER)"
echo "  - Database: $NESSIE_DB (owner: $SHUDL_USER)"
echo "=== ShuDL Database Initialization Complete ==="
