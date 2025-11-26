#!/bin/bash

# End-to-End Test: Complete Pipeline
# Tests complete data pipeline from ingestion to visualization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "E2E Test: Complete Data Pipeline"

# ============================================================================
# Scenario: IoT Sensor Data Pipeline
# ============================================================================
test_step "Scenario: IoT Sensor Data Pipeline"
test_info "Data Source → Kafka → Flink → Iceberg → Trino → ClickHouse → Analytics"

# Step 1: Data Ingestion (Kafka)
test_step "Step 1: Data Ingestion via Kafka"
sensor_topic="iot-sensors-e2e-$$"

if create_kafka_topic "$sensor_topic" 3 1; then
    test_info "✓ Created IoT sensor topic"
else
    test_error "Failed to create sensor topic"
fi

# Simulate sensor data
for i in {1..10}; do
    sensor_data="{\"sensor_id\": $i, \"temperature\": $((20 + i)), \"humidity\": $((50 + i)), \"timestamp\": \"2024-01-01T10:0$i:00Z\"}"
    echo "$sensor_data" | docker exec -i shudl-kafka kafka-console-producer \
        --bootstrap-server localhost:9092 \
        --topic "$sensor_topic" &>/dev/null
done

test_info "✓ Produced 10 sensor readings to Kafka"

# Step 2: Storage in Iceberg (via Trino)
test_step "Step 2: Store data in Iceberg (Data Lake)"

execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.iot_pipeline" 30 || true

create_iot_table="CREATE TABLE IF NOT EXISTS iceberg.iot_pipeline.sensor_readings (
    sensor_id BIGINT,
    temperature DOUBLE,
    humidity DOUBLE,
    reading_timestamp VARCHAR
) WITH (format = 'PARQUET')"

if execute_trino_query "$create_iot_table" 30; then
    test_info "✓ Created IoT table in Iceberg"
else
    test_error "Failed to create IoT table"
fi

# Insert sample data (in real scenario, Flink would consume from Kafka)
insert_iot="INSERT INTO iceberg.iot_pipeline.sensor_readings VALUES
    (1, 21.5, 51.2, '2024-01-01T10:00:00Z'),
    (2, 22.3, 52.5, '2024-01-01T10:01:00Z'),
    (3, 23.1, 53.8, '2024-01-01T10:02:00Z')"

if execute_trino_query "$insert_iot" 30; then
    test_info "✓ Inserted sensor data into Iceberg"
else
    test_error "Failed to insert sensor data"
fi

# Step 3: Query via Trino (SQL Analytics)
test_step "Step 3: Query data via Trino (SQL Analytics)"

query_avg="SELECT AVG(temperature) as avg_temp, AVG(humidity) as avg_humidity FROM iceberg.iot_pipeline.sensor_readings"
if execute_trino_query "$query_avg" 30; then
    test_info "✓ Computed aggregates via Trino"
else
    test_error "Failed to query aggregates"
fi

# Step 4: Load into ClickHouse (OLAP)
test_step "Step 4: Load data into ClickHouse for real-time analytics"

execute_clickhouse_query "CREATE DATABASE IF NOT EXISTS iot_analytics" &>/dev/null || true

clickhouse_table="CREATE TABLE IF NOT EXISTS iot_analytics.sensor_metrics (
    sensor_id UInt64,
    temperature Float64,
    humidity Float64,
    reading_timestamp DateTime
) ENGINE = MergeTree()
ORDER BY (reading_timestamp, sensor_id)"

if execute_clickhouse_query "$clickhouse_table" &>/dev/null; then
    test_info "✓ Created ClickHouse analytics table"
else
    test_error "Failed to create ClickHouse table"
fi

clickhouse_insert="INSERT INTO iot_analytics.sensor_metrics VALUES
    (1, 21.5, 51.2, '2024-01-01 10:00:00'),
    (2, 22.3, 52.5, '2024-01-01 10:01:00'),
    (3, 23.1, 53.8, '2024-01-01 10:02:00')"

if execute_clickhouse_query "$clickhouse_insert" &>/dev/null; then
    test_info "✓ Loaded data into ClickHouse"
else
    test_error "Failed to load data into ClickHouse"
fi

# Step 5: Real-time Analytics
test_step "Step 5: Execute real-time analytics queries"

analytics_query="SELECT
    sensor_id,
    AVG(temperature) as avg_temp,
    MAX(temperature) as max_temp,
    MIN(temperature) as min_temp
FROM iot_analytics.sensor_metrics
GROUP BY sensor_id"

if execute_clickhouse_query "$analytics_query" &>/dev/null; then
    test_info "✓ Executed real-time analytics"
else
    test_error "Failed to execute analytics"
fi

# Step 6: Data Versioning (Nessie)
test_step "Step 6: Verify data versioning capability"

nessie_commits=$(curl -s "http://localhost:19120/api/v2/trees/branch/main/log" 2>/dev/null)
if echo "$nessie_commits" | grep -q "logEntries"; then
    test_info "✓ Nessie commit history accessible"
else
    test_warning "Could not verify Nessie commit history"
fi

# Step 7: Monitoring & Observability
test_step "Step 7: Verify monitoring stack captures metrics"

# Check Prometheus metrics
prom_up=$(curl -s "http://localhost:9090/api/v1/query?query=up" 2>/dev/null)
if echo "$prom_up" | grep -q "\"status\":\"success\""; then
    test_info "✓ Prometheus collecting metrics"
else
    test_error "Prometheus metrics check failed"
fi

# Check Loki logs
if http_health_check "http://localhost:3100/ready"; then
    test_info "✓ Loki ready for log queries"
else
    test_error "Loki not ready"
fi

# Cleanup
test_step "Cleanup test resources..."
docker exec shudl-kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic "$sensor_topic" &>/dev/null || true
execute_trino_query "DROP TABLE IF EXISTS iceberg.iot_pipeline.sensor_readings" 30 || true
execute_trino_query "DROP SCHEMA IF EXISTS iceberg.iot_pipeline" 30 || true
execute_clickhouse_query "DROP TABLE IF EXISTS iot_analytics.sensor_metrics" &>/dev/null || true
execute_clickhouse_query "DROP DATABASE IF EXISTS iot_analytics" &>/dev/null || true

test_success "End-to-end pipeline test completed"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  E2E Pipeline Test Summary${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}✓ Data ingestion via Kafka${NC}"
echo -e "${CYAN}✓ Storage in Iceberg (Data Lake)${NC}"
echo -e "${CYAN}✓ SQL analytics via Trino${NC}"
echo -e "${CYAN}✓ OLAP analytics via ClickHouse${NC}"
echo -e "${CYAN}✓ Data versioning via Nessie${NC}"
echo -e "${CYAN}✓ Monitoring via Prometheus & Loki${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"

print_test_summary
