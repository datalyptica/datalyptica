#!/bin/bash
# PostgreSQL HA Database Initialization Script for Datalyptica
# This script creates databases and users with proper segregation
# Runs on Patroni primary node after cluster initialization

set -e

echo "=== Datalyptica Database Initialization (HA Mode) ==="

# Read passwords from Docker secrets
if [ -f /run/secrets/postgres_password ]; then
    POSTGRES_PASSWORD=$(cat /run/secrets/postgres_password)
else
    POSTGRES_PASSWORD="${POSTGRESQL_POSTGRES_PASSWORD:-postgres}"
fi

if [ -f /run/secrets/datalyptica_password ]; then
    DATALYPTICA_PASSWORD=$(cat /run/secrets/datalyptica_password)
else
    DATALYPTICA_PASSWORD="${DATALYPTICA_PASSWORD:-changeme}"
fi

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -U postgres; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

echo "PostgreSQL is ready. Creating databases and users..."

# Create users with proper segregation
psql -h localhost -U postgres -d postgres <<-EOSQL
    -- ==============================================
    -- APPLICATION USERS
    -- ==============================================
    
    -- 1. Create datalyptica user (general platform user)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'datalyptica') THEN
            CREATE USER datalyptica WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            COMMENT ON ROLE datalyptica IS 'General Datalyptica platform user';
        END IF;
    END
    \$\$;

    -- 2. Create nessie user (catalog management)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nessie') THEN
            CREATE USER nessie WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            COMMENT ON ROLE nessie IS 'Nessie catalog user for data versioning';
        END IF;
    END
    \$\$;

    -- 3. Create keycloak (if not exists)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'keycloak') THEN
            CREATE USER keycloak WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            COMMENT ON ROLE keycloak IS 'Keycloak IAM user';
        END IF;
    END
    \$\$;

    -- 4. Create airflow user (workflow orchestration)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'airflow') THEN
            CREATE USER airflow WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            COMMENT ON ROLE airflow IS 'Apache Airflow workflow user';
        END IF;
    END
    \$\$;

    -- 5. Create metastore user (Spark/Hive metastore)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'metastore') THEN
            CREATE USER metastore WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            COMMENT ON ROLE metastore IS 'Hive metastore user for Spark';
        END IF;
    END
    \$\$;

    -- ==============================================
    -- DATABASES
    -- ==============================================
    
    -- Create datalyptica database (general platform DB)
    SELECT 'CREATE DATABASE datalyptica OWNER datalyptica'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'datalyptica')\gexec
    
    -- Create nessie database (catalog backend)
    SELECT 'CREATE DATABASE nessie OWNER nessie'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nessie')\gexec
    
    -- Create keycloak database (if not exists)
    SELECT 'CREATE DATABASE keycloak OWNER keycloak'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec

    -- Create airflow database
    SELECT 'CREATE DATABASE airflow OWNER airflow'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\gexec

    -- Create metastore database
    SELECT 'CREATE DATABASE metastore OWNER metastore'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metastore')\gexec

    -- ==============================================
    -- GRANT PRIVILEGES
    -- ==============================================
    
    GRANT ALL PRIVILEGES ON DATABASE datalyptica TO datalyptica;
    GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
    GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
    GRANT ALL PRIVILEGES ON DATABASE metastore TO metastore;
EOSQL

# Create schemas in nessie database
psql -h localhost -U postgres -d nessie <<-EOSQL
    -- Create nessie schema for catalog tables
    CREATE SCHEMA IF NOT EXISTS nessie AUTHORIZATION nessie;
    
    -- Set search path
    ALTER DATABASE nessie SET search_path TO nessie, public;
    
    -- Grant schema privileges
    GRANT ALL ON SCHEMA nessie TO nessie;
    GRANT USAGE ON SCHEMA public TO nessie;
    
    -- If tables already exist in public schema, transfer ownership
    DO \$\$
    DECLARE
        r RECORD;
    BEGIN
        FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tableowner != 'nessie'
        LOOP
            EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO nessie';
        END LOOP;
    END
    \$\$;
EOSQL

# Create schemas in datalyptica database
psql -h localhost -U postgres -d datalyptica <<-EOSQL
    -- Create application schemas
    CREATE SCHEMA IF NOT EXISTS staging AUTHORIZATION datalyptica;
    CREATE SCHEMA IF NOT EXISTS analytics AUTHORIZATION datalyptica;
    CREATE SCHEMA IF NOT EXISTS monitoring AUTHORIZATION datalyptica;
    
    -- Set default search path
    ALTER DATABASE datalyptica SET search_path TO public, staging, analytics, monitoring;
    
    -- Grant schema privileges
    GRANT ALL ON SCHEMA staging TO datalyptica;
    GRANT ALL ON SCHEMA analytics TO datalyptica;
    GRANT ALL ON SCHEMA monitoring TO datalyptica;
EOSQL

# Enable extensions in databases
psql -h localhost -U postgres -d nessie <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOSQL

psql -h localhost -U postgres -d datalyptica <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOSQL

echo ""
echo "=== Database Initialization Summary ==="
echo ""
echo "✅ Users created:"
echo "   - datalyptica (general platform user)"
echo "   - nessie (catalog management)"
echo "   - keycloak (identity & access)"
echo "   - airflow (workflow orchestration)"
echo "   - metastore (Spark/Hive metastore)"
echo ""
echo "✅ Databases created:"
echo "   - datalyptica (owner: datalyptica)"
echo "   - nessie (owner: nessie)"
echo "   - keycloak (owner: keycloak)"
echo "   - airflow (owner: airflow)"
echo "   - metastore (owner: metastore)"
echo ""
echo "✅ Schemas in nessie database:"
echo "   - nessie (catalog tables)"
echo "   - public (default)"
echo ""
echo "✅ Schemas in datalyptica database:"
echo "   - staging (raw data ingestion)"
echo "   - analytics (transformed data)"
echo "   - monitoring (platform metrics)"
echo ""
echo "=== Database Initialization Complete ==="
