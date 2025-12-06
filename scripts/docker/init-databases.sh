#!/usr/bin/env bash
# Initialize PostgreSQL databases and users for Datalyptica
# Standardized Naming: Simple service names (e.g., datalyptica, nessie, airflow)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment variables
if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
    source "${PROJECT_ROOT}/docker/.env"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-datalyptica}
PREFIX=${COMPOSE_PROJECT_NAME}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Datalyptica Database Initialization"
echo "  Simple Naming: datalyptica, nessie, airflow, etc."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Read passwords from secrets
echo -e "${BLUE}ℹ${NC} Loading passwords from secrets..."
POSTGRES_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/postgres_password" 2>/dev/null || echo "")
DATALYPTICA_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/datalyptica_password" 2>/dev/null || echo "")
NESSIE_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/nessie_password" 2>/dev/null || echo "")
KEYCLOAK_DB_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/keycloak_db_password" 2>/dev/null || echo "")
AIRFLOW_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/airflow_password" 2>/dev/null || echo "")
JUPYTERHUB_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/jupyterhub_password" 2>/dev/null || echo "")
MLFLOW_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/mlflow_password" 2>/dev/null || echo "")
SUPERSET_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/superset_password" 2>/dev/null || echo "")

if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$DATALYPTICA_PASSWORD" ]; then
    echo -e "${RED}✗ ERROR: Required password files not found in secrets/passwords/${NC}"
    echo "Please run: ./scripts/generate-secrets.sh"
    exit 1
fi

echo -e "${GREEN}✓${NC} All password files loaded"
echo ""

# Check if PostgreSQL container is running
echo -e "${BLUE}ℹ${NC} Checking PostgreSQL container..."
if ! docker ps --format '{{.Names}}' | grep -q "^${PREFIX}-postgresql$"; then
    echo -e "${RED}✗ ERROR: ${PREFIX}-postgresql container is not running${NC}"
    echo "Please start the stack first: cd docker && docker compose up -d"
    exit 1
fi
echo -e "${GREEN}✓${NC} PostgreSQL container is running"
echo ""

echo -e "${BLUE}ℹ${NC} Creating databases and users..."

docker exec -i ${PREFIX}-postgresql psql -U postgres <<-EOSQL
    -- ============================================
    -- CORE PLATFORM SERVICES
    -- ============================================
    
    -- Create datalyptica user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'datalyptica') THEN
            CREATE USER datalyptica WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO datalyptica;
        END IF;
    END
    \$\$;
    
    -- Create nessie user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nessie') THEN
            CREATE USER nessie WITH PASSWORD '${NESSIE_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO nessie;
        END IF;
    END
    \$\$;
    
    -- Create keycloak user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'keycloak') THEN
            CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO keycloak;
        END IF;
    END
    \$\$;
    
    -- ============================================
    -- ANALYTICS & ML SERVICES
    -- ============================================
    
    -- Create airflow user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'airflow') THEN
            CREATE USER airflow WITH PASSWORD '${AIRFLOW_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO airflow;
        END IF;
    END
    \$\$;
    
    -- Create jupyterhub user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'jupyterhub') THEN
            CREATE USER jupyterhub WITH PASSWORD '${JUPYTERHUB_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO jupyterhub;
        END IF;
    END
    \$\$;
    
    -- Create mlflow user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mlflow') THEN
            CREATE USER mlflow WITH PASSWORD '${MLFLOW_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO mlflow;
        END IF;
    END
    \$\$;
    
    -- Create superset user
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'superset') THEN
            CREATE USER superset WITH PASSWORD '${SUPERSET_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO superset;
        END IF;
    END
    \$\$;
    
    -- ============================================
    -- CREATE DATABASES
    -- ============================================
    
    -- Core Platform
    SELECT 'CREATE DATABASE datalyptica OWNER datalyptica'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'datalyptica')\gexec
    
    SELECT 'CREATE DATABASE nessie OWNER nessie'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nessie')\gexec
    
    SELECT 'CREATE DATABASE keycloak OWNER keycloak'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec
    
    -- Analytics & ML
    SELECT 'CREATE DATABASE airflow OWNER airflow'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\gexec
    
    SELECT 'CREATE DATABASE jupyterhub OWNER jupyterhub'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'jupyterhub')\gexec
    
    SELECT 'CREATE DATABASE mlflow OWNER mlflow'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mlflow')\gexec
    
    SELECT 'CREATE DATABASE superset OWNER superset'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'superset')\gexec
    
    -- ============================================
    -- GRANT PRIVILEGES
    -- ============================================
    
    GRANT ALL PRIVILEGES ON DATABASE datalyptica TO datalyptica;
    GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
    GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
    GRANT ALL PRIVILEGES ON DATABASE jupyterhub TO jupyterhub;
    GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;
    GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
EOSQL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} PostgreSQL databases initialized successfully"
    echo ""
    echo -e "${BLUE}Current databases:${NC}"
    docker exec ${PREFIX}-postgresql psql -U postgres -c '\l' | grep -E "_db|Database"
else
    echo -e "${RED}✗${NC} Failed to initialize databases"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Database initialization complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Databases created:${NC}"
echo "  📦 Core Platform:"
echo "     • datalyptica (owner: datalyptica)"
echo "     • nessie (owner: nessie)"
echo "     • keycloak (owner: keycloak)"
echo ""
echo "  📊 Analytics & ML:"
echo "     • airflow (owner: airflow)"
echo "     • jupyterhub (owner: jupyterhub)"
echo "     • mlflow (owner: mlflow)"
echo "     • superset (owner: superset)"
echo ""
