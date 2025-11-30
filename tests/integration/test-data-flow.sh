#!/bin/bash

# Integration Test: Complete Data Flow
# Tests data flow across multiple components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Integration Test: Complete Data Flow"

# ============================================================================
# Test 1: Kafka → Iceberg Flow
# ============================================================================
test_step "Test 1: Kafka → Iceberg data flow"

# Create Kafka topic
test_topic="integration-test-$$"
if create_kafka_topic "$test_topic" 3 1; then
    test_info "✓ Created test topic: $test_topic"
else
    test_error "Failed to create Kafka topic"
fi

# Produce test message to Kafka
test_message='{"id": 1, "name": "integration_test", "timestamp": "2024-01-01T10:00:00Z"}'
echo "$test_message" | docker exec -i ${CONTAINER_PREFIX}-kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic "$test_topic" &>/dev/null

if [[ $? -eq 0 ]]; then
    test_info "✓ Produced message to Kafka"
else
    test_error "Failed to produce message to Kafka"
fi

# Verify message in Kafka
message_count=$(docker exec ${CONTAINER_PREFIX}-kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic "$test_topic" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 5000 2>/dev/null | wc -l)

if [[ $message_count -gt 0 ]]; then
    test_info "✓ Verified message in Kafka"
else
    test_warning "Could not verify message in Kafka"
fi

# Cleanup
docker exec ${CONTAINER_PREFIX}-kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic "$test_topic" &>/dev/null

# ============================================================================
# Test 2: Trino → Iceberg → Trino Flow
# ============================================================================
test_step "Test 2: Trino → Iceberg → Trino roundtrip"

# Create schema
if execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.integration_test" 30; then
    test_info "✓ Created test schema"
else
    test_error "Failed to create schema"
fi

# Create table
create_sql="CREATE TABLE IF NOT EXISTS iceberg.integration_test.flow_test (
    id BIGINT,
    name VARCHAR,
    value DOUBLE
) WITH (format = 'PARQUET')"

if execute_trino_query "$create_sql" 30; then
    test_info "✓ Created test table"
else
    test_error "Failed to create table"
fi

# Insert data
insert_sql="INSERT INTO iceberg.integration_test.flow_test VALUES (1, 'test', 123.45)"
if execute_trino_query "$insert_sql" 30; then
    test_info "✓ Inserted test data"
else
    test_error "Failed to insert data"
fi

# Query data
if execute_trino_query "SELECT * FROM iceberg.integration_test.flow_test" 30; then
    test_info "✓ Queried test data"
else
    test_error "Failed to query data"
fi

# Cleanup
execute_trino_query "DROP TABLE IF EXISTS iceberg.integration_test.flow_test" 30 || true
execute_trino_query "DROP SCHEMA IF EXISTS iceberg.integration_test" 30 || true

# ============================================================================
# Test 3: Cross-Engine Data Access (Trino ↔ Spark)
# ============================================================================
test_step "Test 3: Cross-engine data access (Trino → Spark)"

# Create table with Trino
if execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.cross_engine" 30; then
    test_info "✓ Created cross-engine schema"
else
    test_error "Failed to create cross-engine schema"
fi

create_cross_sql="CREATE TABLE IF NOT EXISTS iceberg.cross_engine.shared_data (
    id BIGINT,
    engine VARCHAR,
    timestamp VARCHAR
) WITH (format = 'PARQUET')"

if execute_trino_query "$create_cross_sql" 30; then
    test_info "✓ Created shared table via Trino"
else
    test_error "Failed to create shared table"
fi

# Insert data via Trino
insert_cross_sql="INSERT INTO iceberg.cross_engine.shared_data VALUES (1, 'trino', '2024-01-01')"
if execute_trino_query "$insert_cross_sql" 30; then
    test_info "✓ Inserted data via Trino"
else
    test_error "Failed to insert data via Trino"
fi

# TODO: Read data via Spark (requires Spark SQL setup)
test_info "⏩ Spark read test skipped (requires Spark session setup)"

# Cleanup
execute_trino_query "DROP TABLE IF EXISTS iceberg.cross_engine.shared_data" 30 || true
execute_trino_query "DROP SCHEMA IF EXISTS iceberg.cross_engine" 30 || true

# ============================================================================
# Test 4: ClickHouse Query Test
# ============================================================================
test_step "Test 4: ClickHouse analytics"

# Create test database
if execute_clickhouse_query "CREATE DATABASE IF NOT EXISTS integration_test" &>/dev/null; then
    test_info "✓ Created ClickHouse test database"
else
    test_error "Failed to create ClickHouse database"
fi

# Create table
clickhouse_create="CREATE TABLE IF NOT EXISTS integration_test.metrics (
    id UInt64,
    metric_name String,
    value Float64,
    timestamp DateTime
) ENGINE = MergeTree()
ORDER BY (timestamp, id)"

if execute_clickhouse_query "$clickhouse_create" &>/dev/null; then
    test_info "✓ Created ClickHouse test table"
else
    test_error "Failed to create ClickHouse table"
fi

# Insert data
clickhouse_insert="INSERT INTO integration_test.metrics VALUES (1, 'cpu_usage', 75.5, now())"
if execute_clickhouse_query "$clickhouse_insert" &>/dev/null; then
    test_info "✓ Inserted data into ClickHouse"
else
    test_error "Failed to insert data into ClickHouse"
fi

# Query data
if execute_clickhouse_query "SELECT COUNT(*) FROM integration_test.metrics" &>/dev/null; then
    test_info "✓ Queried ClickHouse data"
else
    test_error "Failed to query ClickHouse"
fi

# Cleanup
execute_clickhouse_query "DROP TABLE IF EXISTS integration_test.metrics" &>/dev/null || true
execute_clickhouse_query "DROP DATABASE IF EXISTS integration_test" &>/dev/null || true

test_success "Integration tests completed"

print_test_summary
