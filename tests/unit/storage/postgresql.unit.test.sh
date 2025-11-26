#!/bin/bash

# =============================================================================
# PostgreSQL Unit Tests
# Tests PostgreSQL database functionality
# =============================================================================

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Test configuration
TEST_DB="test_unit_db_$$"
TEST_TABLE="test_table"

# Setup
test_start "PostgreSQL Unit Tests"

setup_test() {
    test_step "Setting up test environment"
    
    # Create test database
    docker exec docker-postgresql psql -U admin -d lakehouse -c "CREATE DATABASE $TEST_DB;" >/dev/null 2>&1 || true
}

teardown_test() {
    test_step "Cleaning up test environment"
    
    # Drop test database
    docker exec docker-postgresql psql -U admin -d lakehouse -c "DROP DATABASE IF EXISTS $TEST_DB;" >/dev/null 2>&1 || true
}

# Trap to ensure cleanup
trap teardown_test EXIT

# Test Cases
test_postgresql_health() {
    test_step "Test 1: PostgreSQL health check"
    
    if docker exec docker-postgresql pg_isready -U admin >/dev/null 2>&1; then
        test_success "PostgreSQL is ready"
        return 0
    else
        test_error "PostgreSQL is not ready"
        return 1
    fi
}

test_postgresql_connection() {
    test_step "Test 2: Database connection"
    
    if docker exec docker-postgresql psql -U admin -d lakehouse -c "SELECT 1;" >/dev/null 2>&1; then
        test_success "Database connection successful"
        return 0
    else
        test_error "Database connection failed"
        return 1
    fi
}

test_postgresql_create_table() {
    test_step "Test 3: Create table"
    
    local query="CREATE TABLE $TEST_TABLE (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "$query" >/dev/null 2>&1; then
        test_success "Table created successfully"
        return 0
    else
        test_error "Failed to create table"
        return 1
    fi
}

test_postgresql_insert_data() {
    test_step "Test 4: Insert data"
    
    local query="INSERT INTO $TEST_TABLE (name) VALUES ('Test User 1'), ('Test User 2'), ('Test User 3');"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "$query" >/dev/null 2>&1; then
        test_success "Data inserted successfully"
        return 0
    else
        test_error "Failed to insert data"
        return 1
    fi
}

test_postgresql_select_data() {
    test_step "Test 5: Select data"
    
    local result
    result=$(docker exec docker-postgresql psql -U admin -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM $TEST_TABLE;")
    
    if [[ $(echo "$result" | tr -d ' ') -eq 3 ]]; then
        test_success "Data retrieved successfully (count: 3)"
        return 0
    else
        test_error "Failed to retrieve correct data count"
        return 1
    fi
}

test_postgresql_update_data() {
    test_step "Test 6: Update data"
    
    local query="UPDATE $TEST_TABLE SET name = 'Updated User' WHERE id = 1;"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "$query" >/dev/null 2>&1; then
        test_success "Data updated successfully"
        return 0
    else
        test_error "Failed to update data"
        return 1
    fi
}

test_postgresql_delete_data() {
    test_step "Test 7: Delete data"
    
    local query="DELETE FROM $TEST_TABLE WHERE id = 1;"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "$query" >/dev/null 2>&1; then
        local count
        count=$(docker exec docker-postgresql psql -U admin -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM $TEST_TABLE;")
        
        if [[ $(echo "$count" | tr -d ' ') -eq 2 ]]; then
            test_success "Data deleted successfully (remaining: 2)"
            return 0
        else
            test_error "Delete operation inconsistent"
            return 1
        fi
    else
        test_error "Failed to delete data"
        return 1
    fi
}

test_postgresql_transaction() {
    test_step "Test 8: Transaction (ROLLBACK)"
    
    # Start transaction and rollback
    docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "BEGIN; INSERT INTO $TEST_TABLE (name) VALUES ('Rollback User'); ROLLBACK;" >/dev/null 2>&1
    
    local count
    count=$(docker exec docker-postgresql psql -U admin -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM $TEST_TABLE;")
    
    if [[ $(echo "$count" | tr -d ' ') -eq 2 ]]; then
        test_success "Transaction rollback successful"
        return 0
    else
        test_error "Transaction rollback failed"
        return 1
    fi
}

test_postgresql_commit_transaction() {
    test_step "Test 9: Transaction (COMMIT)"
    
    # Start transaction and commit
    docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "BEGIN; INSERT INTO $TEST_TABLE (name) VALUES ('Commit User'); COMMIT;" >/dev/null 2>&1
    
    local count
    count=$(docker exec docker-postgresql psql -U admin -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM $TEST_TABLE;")
    
    if [[ $(echo "$count" | tr -d ' ') -eq 3 ]]; then
        test_success "Transaction commit successful"
        return 0
    else
        test_error "Transaction commit failed"
        return 1
    fi
}

test_postgresql_index() {
    test_step "Test 10: Create index"
    
    local query="CREATE INDEX idx_${TEST_TABLE}_name ON $TEST_TABLE(name);"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "$query" >/dev/null 2>&1; then
        test_success "Index created successfully"
        return 0
    else
        test_error "Failed to create index"
        return 1
    fi
}

test_postgresql_performance() {
    test_step "Test 11: Query performance stats"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "SELECT * FROM pg_stat_statements LIMIT 1;" >/dev/null 2>&1; then
        test_success "Performance stats accessible"
        return 0
    else
        test_warning "pg_stat_statements extension not enabled (non-critical)"
        return 0
    fi
}

test_postgresql_drop_table() {
    test_step "Test 12: Drop table"
    
    if docker exec docker-postgresql psql -U admin -d "$TEST_DB" -c "DROP TABLE $TEST_TABLE;" >/dev/null 2>&1; then
        test_success "Table dropped successfully"
        return 0
    else
        test_error "Failed to drop table"
        return 1
    fi
}

# Run all tests
setup_test

FAILED_TESTS=0

test_postgresql_health || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_connection || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_create_table || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_insert_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_select_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_update_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_delete_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_transaction || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_commit_transaction || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_index || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_performance || FAILED_TESTS=$((FAILED_TESTS + 1))
test_postgresql_drop_table || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test summary
echo ""
if [[ $FAILED_TESTS -eq 0 ]]; then
    test_success "All PostgreSQL unit tests passed! ✅"
    exit 0
else
    test_error "$FAILED_TESTS test(s) failed ❌"
    exit 1
fi
