#!/bin/bash

# =============================================================================
# Trino Unit Tests
# Tests Trino distributed SQL query engine functionality
# =============================================================================

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Test configuration
TEST_SCHEMA="test_schema_$$"
TEST_TABLE="test_table"

# Setup
test_start "Trino Unit Tests"

teardown_test() {
    test_step "Cleaning up test environment"
    
    # Drop test schema
    execute_trino_query "DROP SCHEMA IF EXISTS iceberg.$TEST_SCHEMA CASCADE" >/dev/null 2>&1 || true
}

# Trap to ensure cleanup
trap teardown_test EXIT

# Test Cases
test_trino_health() {
    test_step "Test 1: Trino health check"
    
    if check_http_endpoint "http://localhost:8080/v1/info" 200 10; then
        test_success "Trino API responding"
        return 0
    else
        test_error "Trino API not responding"
        return 1
    fi
}

test_trino_cluster_info() {
    test_step "Test 2: Get cluster information"
    
    local response
    response=$(curl -s "http://localhost:8080/v1/info")
    
    if echo "$response" | grep -q "nodeVersion"; then
        test_success "Cluster information retrieved"
        return 0
    else
        test_error "Failed to retrieve cluster information"
        return 1
    fi
}

test_trino_show_catalogs() {
    test_step "Test 3: Show catalogs"
    
    local result
    result=$(execute_trino_query "SHOW CATALOGS")
    
    if echo "$result" | grep -q "iceberg"; then
        test_success "Catalogs listed successfully"
        return 0
    else
        test_error "Failed to list catalogs"
        return 1
    fi
}

test_trino_create_schema() {
    test_step "Test 4: Create schema"
    
    if execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.$TEST_SCHEMA" >/dev/null 2>&1; then
        test_success "Schema created successfully"
        return 0
    else
        test_error "Failed to create schema"
        return 1
    fi
}

test_trino_show_schemas() {
    test_step "Test 5: Show schemas"
    
    local result
    result=$(execute_trino_query "SHOW SCHEMAS FROM iceberg")
    
    if echo "$result" | grep -q "$TEST_SCHEMA"; then
        test_success "Schema listed successfully"
        return 0
    else
        test_error "Failed to list schema"
        return 1
    fi
}

test_trino_create_table() {
    test_step "Test 6: Create table"
    
    local query="CREATE TABLE iceberg.$TEST_SCHEMA.$TEST_TABLE (
        id INT,
        name VARCHAR,
        created_at TIMESTAMP
    )"
    
    if execute_trino_query "$query" >/dev/null 2>&1; then
        test_success "Table created successfully"
        return 0
    else
        test_error "Failed to create table"
        return 1
    fi
}

test_trino_insert_data() {
    test_step "Test 7: Insert data"
    
    local query="INSERT INTO iceberg.$TEST_SCHEMA.$TEST_TABLE VALUES 
        (1, 'User 1', CURRENT_TIMESTAMP),
        (2, 'User 2', CURRENT_TIMESTAMP),
        (3, 'User 3', CURRENT_TIMESTAMP)"
    
    if execute_trino_query "$query" >/dev/null 2>&1; then
        test_success "Data inserted successfully"
        return 0
    else
        test_error "Failed to insert data"
        return 1
    fi
}

test_trino_select_data() {
    test_step "Test 8: Select data"
    
    local result
    result=$(execute_trino_query "SELECT COUNT(*) FROM iceberg.$TEST_SCHEMA.$TEST_TABLE")
    
    if echo "$result" | grep -q "3"; then
        test_success "Data retrieved successfully (count: 3)"
        return 0
    else
        test_error "Failed to retrieve correct data count"
        return 1
    fi
}

test_trino_update_data() {
    test_step "Test 9: Update data"
    
    local query="UPDATE iceberg.$TEST_SCHEMA.$TEST_TABLE SET name = 'Updated User' WHERE id = 1"
    
    if execute_trino_query "$query" >/dev/null 2>&1; then
        test_success "Data updated successfully"
        return 0
    else
        test_error "Failed to update data"
        return 1
    fi
}

test_trino_delete_data() {
    test_step "Test 10: Delete data"
    
    local query="DELETE FROM iceberg.$TEST_SCHEMA.$TEST_TABLE WHERE id = 3"
    
    if execute_trino_query "$query" >/dev/null 2>&1; then
        local count
        count=$(execute_trino_query "SELECT COUNT(*) FROM iceberg.$TEST_SCHEMA.$TEST_TABLE")
        
        if echo "$count" | grep -q "2"; then
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

test_trino_show_tables() {
    test_step "Test 11: Show tables"
    
    local result
    result=$(execute_trino_query "SHOW TABLES FROM iceberg.$TEST_SCHEMA")
    
    if echo "$result" | grep -q "$TEST_TABLE"; then
        test_success "Tables listed successfully"
        return 0
    else
        test_error "Failed to list tables"
        return 1
    fi
}

test_trino_describe_table() {
    test_step "Test 12: Describe table"
    
    local result
    result=$(execute_trino_query "DESCRIBE iceberg.$TEST_SCHEMA.$TEST_TABLE")
    
    if echo "$result" | grep -q "id" && echo "$result" | grep -q "name"; then
        test_success "Table described successfully"
        return 0
    else
        test_error "Failed to describe table"
        return 1
    fi
}

test_trino_table_properties() {
    test_step "Test 13: Show table properties"
    
    local result
    result=$(execute_trino_query "SHOW CREATE TABLE iceberg.$TEST_SCHEMA.$TEST_TABLE")
    
    if echo "$result" | grep -q "CREATE TABLE"; then
        test_success "Table properties retrieved"
        return 0
    else
        test_error "Failed to retrieve table properties"
        return 1
    fi
}

test_trino_drop_table() {
    test_step "Test 14: Drop table"
    
    if execute_trino_query "DROP TABLE iceberg.$TEST_SCHEMA.$TEST_TABLE" >/dev/null 2>&1; then
        test_success "Table dropped successfully"
        return 0
    else
        test_error "Failed to drop table"
        return 1
    fi
}

test_trino_drop_schema() {
    test_step "Test 15: Drop schema"
    
    if execute_trino_query "DROP SCHEMA iceberg.$TEST_SCHEMA" >/dev/null 2>&1; then
        test_success "Schema dropped successfully"
        return 0
    else
        test_error "Failed to drop schema"
        return 1
    fi
}

# Run all tests
FAILED_TESTS=0

test_trino_health || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_cluster_info || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_show_catalogs || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_create_schema || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_show_schemas || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_create_table || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_insert_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_select_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_update_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_delete_data || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_show_tables || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_describe_table || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_table_properties || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_drop_table || FAILED_TESTS=$((FAILED_TESTS + 1))
test_trino_drop_schema || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test summary
echo ""
if [[ $FAILED_TESTS -eq 0 ]]; then
    test_success "All Trino unit tests passed! ✅"
    exit 0
else
    test_error "$FAILED_TESTS test(s) failed ❌"
    exit 1
fi
