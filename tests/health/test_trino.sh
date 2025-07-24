#!/bin/bash

# Test: Trino Health Check
# Validates Trino service health and query engine functionality

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Trino Health Check"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Checking Trino container status..."
if ! docker compose ps trino 2>/dev/null | grep -q "healthy"; then
    test_error "Trino container is not healthy"
    docker compose ps trino
    exit 1
fi

test_step "Testing Trino port connectivity..."
if ! check_port "localhost" "$TRINO_PORT" 10; then
    test_error "Cannot connect to Trino port $TRINO_PORT"
    exit 1
fi

test_step "Testing Trino REST API..."
if ! check_http_endpoint "http://localhost:$TRINO_PORT/v1/status" 200 30; then
    test_error "Trino REST API is not responding"
    exit 1
fi

test_step "Checking Trino cluster info..."
cluster_info=$(curl -s "http://localhost:$TRINO_PORT/v1/info" 2>/dev/null || echo "{}")
if echo "$cluster_info" | grep -q "nodeVersion"; then
    test_info "✓ Trino cluster info accessible"
    version=$(echo "$cluster_info" | jq -r '.nodeVersion.version' 2>/dev/null || echo "unknown")
    test_info "✓ Trino version: $version"
else
    test_error "Cannot retrieve Trino cluster information"
    exit 1
fi

test_step "Testing basic SQL queries..."
if ! execute_trino_query "SELECT 1;" 30; then
    test_error "Cannot execute basic SQL query"
    exit 1
fi

test_step "Checking available catalogs..."
# Retry mechanism for catalog availability check (timing issues during full test suite)
max_attempts=5
attempt=1
catalog_available=false

while [[ $attempt -le $max_attempts ]]; do
    if [[ $attempt -gt 1 ]]; then
        test_info "Retrying catalog check (attempt $attempt/$max_attempts)..."
        sleep 2
    fi
    
    catalog_result=$(execute_trino_query "SHOW CATALOGS;" 30 2>/dev/null || echo "")
    if echo "$catalog_result" | grep -q "iceberg"; then
        catalog_available=true
        break
    fi
    
    attempt=$((attempt + 1))
done

if [[ "$catalog_available" != "true" ]]; then
    test_error "Iceberg catalog is not available after $max_attempts attempts"
    exit 1
fi

test_step "Testing Iceberg catalog connectivity..."
# Retry mechanism for Iceberg catalog connectivity (timing issues during full test suite)
max_attempts=3
attempt=1
iceberg_available=false

while [[ $attempt -le $max_attempts ]]; do
    if [[ $attempt -gt 1 ]]; then
        test_info "Retrying Iceberg connectivity check (attempt $attempt/$max_attempts)..."
        sleep 2
    fi
    
    if execute_trino_query "SHOW SCHEMAS IN iceberg;" 30 >/dev/null 2>&1; then
        iceberg_available=true
        break
    fi
    
    attempt=$((attempt + 1))
done

if [[ "$iceberg_available" != "true" ]]; then
    test_error "Cannot access Iceberg catalog schemas after $max_attempts attempts"
    exit 1
fi

test_step "Checking system information..."
# Check if coordinator is running
coordinator_info=$(curl -s "http://localhost:$TRINO_PORT/v1/node" 2>/dev/null || echo "[]")
if echo "$coordinator_info" | grep -q "coordinator"; then
    test_info "✓ Coordinator node found"
else
    test_warning "Coordinator node information not found"
fi

# Check active queries
active_queries=$(curl -s "http://localhost:$TRINO_PORT/v1/query" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
test_info "Active queries: $active_queries"

test_step "Testing Trino memory and performance..."
# Check memory usage
memory_info=$(curl -s "http://localhost:$TRINO_PORT/v1/cluster/memory" 2>/dev/null || echo "{}")
if echo "$memory_info" | grep -q "totalDistributedBytes"; then
    total_memory=$(echo "$memory_info" | jq -r '.totalDistributedBytes' 2>/dev/null || echo "0")
    test_info "✓ Total distributed memory: $total_memory bytes"
else
    test_warning "Memory information not available"
fi

test_step "Validating Iceberg configuration..."
# Check if Iceberg properties are correctly set
iceberg_config=$(docker exec shudl-trino cat /opt/trino/etc/catalog/iceberg.properties 2>/dev/null || echo "")
if echo "$iceberg_config" | grep -q "iceberg.catalog.type=nessie"; then
    test_info "✓ Iceberg catalog type is correctly set to nessie"
else
    test_error "Iceberg catalog type is not set to nessie"
    exit 1
fi

if echo "$iceberg_config" | grep -q "iceberg.nessie-catalog.uri=http://nessie:19120/api/v2"; then
    test_info "✓ Nessie URI is correctly configured"
else
    test_error "Nessie URI is not correctly configured"
    exit 1
fi

test_success "Trino is healthy and operational" 