#!/bin/bash
# Initialize MinIO buckets for Datalyptica
# Single Responsibility: MinIO bucket creation only

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
echo "MinIO Bucket Initialization"
echo "======================================"
echo ""

# Read MinIO credentials
MINIO_ROOT_USER=$(grep MINIO_ROOT_USER "${PROJECT_ROOT}/docker/.env" | cut -d'=' -f2)
MINIO_ROOT_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/minio_root_password" 2>/dev/null || echo "")

if [ -z "$MINIO_ROOT_PASSWORD" ]; then
    echo -e "${RED}ERROR: MinIO root password not found${NC}"
    echo "Please run: ./scripts/generate-secrets.sh"
    exit 1
fi

# Check if MinIO container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${PREFIX}-minio$"; then
    echo -e "${RED}ERROR: ${PREFIX}-minio container is not running${NC}"
    echo "Please start the stack first: cd docker && docker compose up -d"
    exit 1
fi

echo "Creating buckets and directories..."

docker exec ${PREFIX}-minio sh -c "
    # Configure MinIO client
    mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null || true
    
    # Create lakehouse bucket
    if ! mc ls local/lakehouse >/dev/null 2>&1; then
        mc mb local/lakehouse
        echo 'Created bucket: lakehouse'
    else
        echo 'Bucket already exists: lakehouse'
    fi
    
    # Create warehouse directories
    mc mb -p local/lakehouse/warehouse 2>/dev/null || true
    mc mb -p local/lakehouse/staging 2>/dev/null || true
    mc mb -p local/lakehouse/raw 2>/dev/null || true
    
    echo ''
    echo 'Current buckets:'
    mc ls local/
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} MinIO buckets initialized successfully"
else
    echo -e "${RED}✗${NC} Failed to initialize buckets"
    exit 1
fi

echo ""
echo -e "${GREEN}Bucket initialization complete!${NC}"
echo ""
echo "Buckets created:"
echo "  - lakehouse"
echo "    - warehouse/"
echo "    - staging/"
echo "    - raw/"
echo ""
echo "Access MinIO Console: http://localhost:9001"
echo "  Username: ${MINIO_ROOT_USER}"
echo ""
