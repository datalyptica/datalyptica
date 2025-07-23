#!/bin/bash

# Test: PostgreSQL Health Check
# Validates PostgreSQL service health and connectivity

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "PostgreSQL Health Check"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Checking PostgreSQL container status..."
if ! docker compose ps postgresql 2>/dev/null | grep -q "healthy"; then
    test_error "PostgreSQL container is not healthy"
    docker compose ps postgresql
    exit 1
fi

test_step "Testing PostgreSQL port connectivity..."
if ! check_port "localhost" "$POSTGRES_PORT" 10; then
    test_error "Cannot connect to PostgreSQL port $POSTGRES_PORT"
    exit 1
fi

test_step "Testing PostgreSQL authentication..."
if ! execute_sql_query "SELECT 1;" "$POSTGRES_DB" "$POSTGRES_USER" 10; then
    test_error "Cannot authenticate to PostgreSQL database"
    exit 1
fi

test_step "Checking Nessie database exists..."
if ! execute_sql_query "SELECT 1 FROM pg_database WHERE datname='nessie';" "postgres" "$POSTGRES_USER" 10 | grep -q "1"; then
    test_error "Nessie database does not exist"
    exit 1
fi

test_step "Testing database operations..."
# Create test table
if ! execute_sql_query "CREATE TABLE IF NOT EXISTS test_health_check (id SERIAL PRIMARY KEY, test_data TEXT);" "$POSTGRES_DB" "$POSTGRES_USER" 10; then
    test_error "Cannot create test table"
    exit 1
fi

# Insert test data
if ! execute_sql_query "INSERT INTO test_health_check (test_data) VALUES ('health_check_$(date +%s)');" "$POSTGRES_DB" "$POSTGRES_USER" 10; then
    test_error "Cannot insert test data"
    exit 1
fi

# Query test data
if ! execute_sql_query "SELECT COUNT(*) FROM test_health_check;" "$POSTGRES_DB" "$POSTGRES_USER" 10 | grep -q "[0-9]"; then
    test_error "Cannot query test data"
    exit 1
fi

# Cleanup test table
execute_sql_query "DROP TABLE IF EXISTS test_health_check;" "$POSTGRES_DB" "$POSTGRES_USER" 10 || true

test_step "Checking PostgreSQL configuration..."
# Check max connections
max_conn=$(execute_sql_query "SHOW max_connections;" "$POSTGRES_DB" "$POSTGRES_USER" 10 | grep -o "[0-9]*" | head -1)
if [[ -n "$max_conn" && "$max_conn" -lt 10 ]]; then
    test_warning "max_connections is very low: $max_conn"
fi

test_step "Checking disk space..."
# Check if PostgreSQL data directory has sufficient space
available_space=$(docker exec shudl-postgresql df -h /var/lib/postgresql/data | tail -1 | awk '{print $4}' | sed 's/[^0-9.]//g')
if [[ -n "$available_space" ]] && (( $(echo "$available_space < 1" | bc -l) )); then
    test_warning "Low disk space available: ${available_space}GB"
fi

test_success "PostgreSQL is healthy and operational" 