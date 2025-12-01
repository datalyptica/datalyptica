#!/bin/bash
# Initialize PostgreSQL databases and users for Datalyptica
# Single Responsibility: Database initialization only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
    source "${PROJECT_ROOT}/docker/.env"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-datalyptica}
PREFIX=${COMPOSE_PROJECT_NAME}

echo "======================================"
echo "PostgreSQL Database Initialization"
echo "======================================"
echo ""

# Read passwords from secrets
POSTGRES_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/postgres_password" 2>/dev/null || echo "")
DATALYPTICA_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/datalyptica_password" 2>/dev/null || echo "")
KEYCLOAK_DB_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/keycloak_db_password" 2>/dev/null || echo "")

if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$DATALYPTICA_PASSWORD" ] || [ -z "$KEYCLOAK_DB_PASSWORD" ]; then
    echo -e "${RED}ERROR: Password files not found in secrets/passwords/${NC}"
    echo "Please run: ./scripts/generate-secrets.sh"
    exit 1
fi

# Check if PostgreSQL container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${PREFIX}-postgresql$"; then
    echo -e "${RED}ERROR: ${PREFIX}-postgresql container is not running${NC}"
    echo "Please start the stack first: cd docker && docker compose up -d"
    exit 1
fi

echo "Creating databases and users..."

docker exec -i ${PREFIX}-postgresql psql -U postgres <<-EOSQL
    -- Create datalyptica user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'datalyptica') THEN
            CREATE USER datalyptica WITH PASSWORD '${DATALYPTICA_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO datalyptica;
        END IF;
    END
    \$\$;

    -- Create keycloak user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'keycloak') THEN
            CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
            GRANT CREATE ON SCHEMA public TO keycloak;
        END IF;
    END
    \$\$;

    -- Create datalyptica database
    SELECT 'CREATE DATABASE datalyptica OWNER datalyptica'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'datalyptica')\gexec

    -- Create nessie database
    SELECT 'CREATE DATABASE nessie OWNER datalyptica'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nessie')\gexec

    -- Create keycloak database
    SELECT 'CREATE DATABASE keycloak OWNER keycloak'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE datalyptica TO datalyptica;
    GRANT ALL PRIVILEGES ON DATABASE nessie TO datalyptica;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
EOSQL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} PostgreSQL databases initialized successfully"
    echo ""
    echo "Current databases:"
    docker exec ${PREFIX}-postgresql psql -U postgres -c '\l' | grep -E "datalyptica|nessie|keycloak"
else
    echo -e "${RED}✗${NC} Failed to initialize databases"
    exit 1
fi

echo ""
echo -e "${GREEN}Database initialization complete!${NC}"
echo ""
echo "Databases created:"
echo "  - datalyptica (owner: datalyptica)"
echo "  - nessie (owner: datalyptica)"
echo "  - keycloak (owner: keycloak)"
echo ""
