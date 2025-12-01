#!/bin/bash
# Verify Datalyptica services are healthy and accessible
# Single Responsibility: Service health verification only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
    source "${PROJECT_ROOT}/docker/.env"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-datalyptica}
PREFIX=${COMPOSE_PROJECT_NAME}

echo "======================================"
echo "Datalyptica Services Verification"
echo "======================================"
echo ""

# Function to check if container is running
check_container() {
    local container_name=$1
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0
    else
        return 1
    fi
}

# Function to wait for container to be healthy
wait_for_healthy() {
    local container_name=$1
    local max_attempts=60
    local attempt=0
    
    echo -n "Waiting for ${container_name} to be healthy..."
    while [ $attempt -lt $max_attempts ]; do
        if docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null | grep -q "healthy"; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e " ${RED}✗${NC}"
    echo -e "${RED}WARNING: ${container_name} did not become healthy within timeout${NC}"
    return 1
}

echo "Step 1: Checking container status..."
echo "--------------------------------------"

core_containers=("${PREFIX}-postgresql" "${PREFIX}-minio" "${PREFIX}-kafka")
optional_containers=("${PREFIX}-nessie" "${PREFIX}-trino" "${PREFIX}-spark-master" "${PREFIX}-flink-jobmanager")

for container in "${core_containers[@]}"; do
    if check_container "$container"; then
        echo -e "${GREEN}✓${NC} $container is running"
    else
        echo -e "${RED}✗${NC} $container is not running"
    fi
done

echo ""
for container in "${optional_containers[@]}"; do
    if check_container "$container"; then
        echo -e "${GREEN}✓${NC} $container is running"
    else
        echo -e "${YELLOW}○${NC} $container is not running (optional)"
    fi
done

echo ""
echo "Step 2: Waiting for core services health checks..."
echo "--------------------------------------"

for container in "${core_containers[@]}"; do
    if check_container "$container"; then
        wait_for_healthy "$container" || true
    fi
done

echo ""
echo "Step 3: Testing service connectivity..."
echo "--------------------------------------"

# Test PostgreSQL
if docker exec ${PREFIX}-postgresql pg_isready -U postgres >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PostgreSQL: Ready (localhost:5432)"
else
    echo -e "${RED}✗${NC} PostgreSQL: Not ready"
fi

# Test MinIO
if curl -s http://localhost:9000/minio/health/live >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} MinIO: Healthy (localhost:9000)"
else
    echo -e "${YELLOW}!${NC} MinIO: Not accessible on localhost:9000"
fi

# Test Nessie (if running)
if check_container "${PREFIX}-nessie"; then
    if curl -s http://localhost:19120/api/v2/config >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Nessie: Ready (localhost:19120)"
    else
        echo -e "${YELLOW}!${NC} Nessie: Not ready yet (may still be starting)"
    fi
fi

# Test Trino (if running)
if check_container "${PREFIX}-trino"; then
    if curl -s http://localhost:8080/v1/info >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Trino: Ready (localhost:8080)"
    else
        echo -e "${YELLOW}!${NC} Trino: Not ready yet (may still be starting)"
    fi
fi

# Test Spark (if running)
if check_container "${PREFIX}-spark-master"; then
    if curl -s http://localhost:4040 >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Spark Master: Ready (localhost:4040)"
    else
        echo -e "${YELLOW}!${NC} Spark Master: Not ready yet (may still be starting)"
    fi
fi

# Test Kafka
if docker exec ${PREFIX}-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Kafka: Ready (localhost:9092)"
else
    echo -e "${YELLOW}!${NC} Kafka: Not ready yet"
fi

echo ""
echo "======================================"
echo -e "${GREEN}Service Verification Complete!${NC}"
echo "======================================"
echo ""
echo "Access Points:"
echo "  - MinIO Console:    http://localhost:9001"
echo "  - Nessie API:       http://localhost:19120"
echo "  - Trino UI:         http://localhost:8080"
echo "  - Kafka UI:         http://localhost:8090"
echo "  - Grafana:          http://localhost:3000"
echo "  - Prometheus:       http://localhost:9090"
echo ""
echo "Database Details:"
echo "  - PostgreSQL:       localhost:5432"
echo "    - Databases:      datalyptica, nessie, keycloak"
echo "    - User:           datalyptica"
echo ""
echo "Next Steps:"
echo "  1. Test Iceberg table creation: ./tests/usecases/00-simple-trino-iceberg.sh"
echo "  2. Run integration tests: ./tests/run-tests.sh"
echo ""
