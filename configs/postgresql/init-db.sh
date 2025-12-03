#!/bin/bash
# PostgreSQL Database Initialization Script for Datalyptica
# This script runs during PostgreSQL initialization via /docker-entrypoint-initdb.d/
# It creates the necessary databases and users for the Datalyptica platform

set -e

echo "=== Datalyptica Database Initialization ==="
echo "Creating Datalyptica-specific databases and users..."

# Read passwords from Docker secrets (files)
if [ -f "/run/secrets/datalyptica_password" ]; then
    DATALYPTICA_PASSWORD=$(cat /run/secrets/datalyptica_password)
else
    DATALYPTICA_PASSWORD=${DATALYPTICA_PASSWORD:-datalyptica123}
    echo "WARNING: Using default password for datalyptica user"
fi

if [ -f "/run/secrets/nessie_password" ]; then
    NESSIE_PASSWORD=$(cat /run/secrets/nessie_password)
else
    NESSIE_PASSWORD=${NESSIE_PASSWORD:-nessie123}
    echo "WARNING: Using default password for nessie user"
fi

if [ -f "/run/secrets/keycloak_db_password" ]; then
    KEYCLOAK_PASSWORD=$(cat /run/secrets/keycloak_db_password)
else
    KEYCLOAK_PASSWORD=${KEYCLOAK_DB_PASSWORD:-keycloak123}
    echo "WARNING: Using default password for keycloak user"
fi

if [ -f "/run/secrets/airflow_password" ]; then
    AIRFLOW_PASSWORD=$(cat /run/secrets/airflow_password)
else
    AIRFLOW_PASSWORD=${AIRFLOW_PASSWORD:-airflow123}
    echo "WARNING: Using default password for airflow user"
fi

# Database and user names
DATALYPTICA_DB=${DATALYPTICA_DB:-datalyptica}
DATALYPTICA_USER=${DATALYPTICA_USER:-datalyptica}
NESSIE_DB=${NESSIE_DB:-nessie}
NESSIE_USER=${NESSIE_USER:-nessie}
KEYCLOAK_DB=${KEYCLOAK_DB:-keycloak_db}
KEYCLOAK_USER=${KEYCLOAK_DB_USER:-keycloak}
AIRFLOW_DB=${AIRFLOW_DB:-airflow}
AIRFLOW_USER=${AIRFLOW_USER:-airflow}

# Create all users and databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
    -- ============================================
    -- Create Users
    -- ============================================
    
    -- Create datalyptica user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DATALYPTICA_USER}') THEN
            CREATE USER ${DATALYPTICA_USER} WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            RAISE NOTICE 'Created user: ${DATALYPTICA_USER}';
        ELSE
            RAISE NOTICE 'User already exists: ${DATALYPTICA_USER}';
        END IF;
    END
    \$\$;
    
    -- Create nessie user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${NESSIE_USER}') THEN
            CREATE USER ${NESSIE_USER} WITH PASSWORD '${NESSIE_PASSWORD}';
            RAISE NOTICE 'Created user: ${NESSIE_USER}';
        ELSE
            RAISE NOTICE 'User already exists: ${NESSIE_USER}';
        END IF;
    END
    \$\$;
    
    -- Create keycloak user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${KEYCLOAK_USER}') THEN
            CREATE USER ${KEYCLOAK_USER} WITH PASSWORD '${KEYCLOAK_PASSWORD}';
            RAISE NOTICE 'Created user: ${KEYCLOAK_USER}';
        ELSE
            RAISE NOTICE 'User already exists: ${KEYCLOAK_USER}';
        END IF;
    END
    \$\$;
    
    -- Create airflow user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${AIRFLOW_USER}') THEN
            CREATE USER ${AIRFLOW_USER} WITH PASSWORD '${AIRFLOW_PASSWORD}';
            RAISE NOTICE 'Created user: ${AIRFLOW_USER}';
        ELSE
            RAISE NOTICE 'User already exists: ${AIRFLOW_USER}';
        END IF;
    END
    \$\$;

    -- ============================================
    -- Create Databases
    -- ============================================
EOSQL

# Create databases (must be done outside transaction)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
    SELECT 'CREATE DATABASE ${DATALYPTICA_DB} OWNER ${DATALYPTICA_USER}' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DATALYPTICA_DB}')\gexec
    
    SELECT 'CREATE DATABASE ${NESSIE_DB} OWNER ${NESSIE_USER}' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${NESSIE_DB}')\gexec
    
    SELECT 'CREATE DATABASE ${KEYCLOAK_DB} OWNER ${KEYCLOAK_USER}' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KEYCLOAK_DB}')\gexec
    
    SELECT 'CREATE DATABASE ${AIRFLOW_DB} OWNER ${AIRFLOW_USER}' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${AIRFLOW_DB}')\gexec
EOSQL

# Grant comprehensive privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
    GRANT ALL PRIVILEGES ON DATABASE ${DATALYPTICA_DB} TO ${DATALYPTICA_USER};
    GRANT ALL PRIVILEGES ON DATABASE ${NESSIE_DB} TO ${NESSIE_USER};
    GRANT ALL PRIVILEGES ON DATABASE ${KEYCLOAK_DB} TO ${KEYCLOAK_USER};
    GRANT ALL PRIVILEGES ON DATABASE ${AIRFLOW_DB} TO ${AIRFLOW_USER};
EOSQL

# Grant schema privileges on each database
for DB_NAME in "${DATALYPTICA_DB}" "${NESSIE_DB}" "${KEYCLOAK_DB}" "${AIRFLOW_DB}"; do
    DB_OWNER=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database d WHERE d.datname = '${DB_NAME}'")
    if [ ! -z "$DB_OWNER" ]; then
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<EOSQL
            GRANT ALL ON SCHEMA public TO ${DB_OWNER};
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_OWNER};
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_OWNER};
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_OWNER};
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_OWNER};
EOSQL
    fi
done

echo "=== Database Initialization Summary ==="
echo "✓ Users created:"
echo "  - ${DATALYPTICA_USER}"
echo "  - ${NESSIE_USER}"
echo "  - ${KEYCLOAK_USER}"
echo "  - ${AIRFLOW_USER}"
echo ""
echo "✓ Databases created:"
echo "  - ${DATALYPTICA_DB} (owner: ${DATALYPTICA_USER})"
echo "  - ${NESSIE_DB} (owner: ${NESSIE_USER})"
echo "  - ${KEYCLOAK_DB} (owner: ${KEYCLOAK_USER})"
echo "  - ${AIRFLOW_DB} (owner: ${AIRFLOW_USER})"
echo ""
echo "=== Datalyptica Database Initialization Complete ==="
