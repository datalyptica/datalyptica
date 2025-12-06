#!/bin/bash
# Initialize Keycloak database in PostgreSQL

set -e

# Wait for PostgreSQL to be ready
until psql -h docker-postgresql -U ${POSTGRES_USER} -c '\q' 2>/dev/null; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "Creating Keycloak database..."

# Create database and user if they don't exist
psql -h docker-postgresql -U ${POSTGRES_USER} -d postgres <<-EOSQL
    SELECT 'CREATE DATABASE ${KEYCLOAK_DB}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KEYCLOAK_DB}')\gexec

    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${KEYCLOAK_DB_USER}') THEN
            CREATE USER ${KEYCLOAK_DB_USER} WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
        END IF;
    END
    \$\$;

    GRANT ALL PRIVILEGES ON DATABASE ${KEYCLOAK_DB} TO ${KEYCLOAK_DB_USER};
EOSQL

echo "Keycloak database initialized successfully!"
