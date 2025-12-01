#!/bin/bash
# PostgreSQL Database Initialization Script for Datalyptica
# This script runs during PostgreSQL initialization via /docker-entrypoint-initdb.d/
# It creates the necessary databases and users for the Datalyptica platform

set -e

echo "=== Datalyptica Database Initialization ==="
echo "Creating Datalyptica-specific databases and users..."

# Default values (can be overridden by environment variables)
DATALYPTICA_DB=${DATALYPTICA_DB:-datalyptica}
DATALYPTICA_USER=${DATALYPTICA_USER:-datalyptica}
DATALYPTICA_PASSWORD=${DATALYPTICA_PASSWORD:-password123}
NESSIE_DB=${NESSIE_DB:-nessie}

# Create Datalyptica user if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create Datalyptica user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DATALYPTICA_USER') THEN
            CREATE USER $DATALYPTICA_USER WITH PASSWORD '$DATALYPTICA_PASSWORD';
            GRANT CREATE ON SCHEMA public TO $DATALYPTICA_USER;
        END IF;
    END
    \$\$;

    -- Create Datalyptica database
    SELECT 'CREATE DATABASE $DATALYPTICA_DB OWNER $DATALYPTICA_USER'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DATALYPTICA_DB')\gexec

    -- Create Nessie database for catalog backend
    SELECT 'CREATE DATABASE $NESSIE_DB OWNER $DATALYPTICA_USER'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$NESSIE_DB')\gexec
EOSQL

# Grant privileges on databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE $DATALYPTICA_DB TO $DATALYPTICA_USER;
    GRANT ALL PRIVILEGES ON DATABASE $NESSIE_DB TO $DATALYPTICA_USER;
EOSQL

echo "Datalyptica databases created successfully:"
echo "  - Database: $DATALYPTICA_DB (owner: $DATALYPTICA_USER)"
echo "  - Database: $NESSIE_DB (owner: $DATALYPTICA_USER)"
echo "=== Datalyptica Database Initialization Complete ==="
