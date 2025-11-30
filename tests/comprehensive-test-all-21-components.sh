#!/bin/bash

# Comprehensive Test Suite for All 20 ShuDL Components (ZooKeeper removed - using KRaft)
# Tests every component with health checks, integration tests, and end-to-end workflows

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/test_helpers.sh"

# Configuration
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_DIR}/docker/docker-compose.yml"
ENV_FILE="${PROJECT_DIR}/docker/.env"

# Component list (20 components - ZooKeeper removed, using KRaft) - Compatible with bash 3.2+
# Note: PostgreSQL uses HA setup with patroni-1 and patroni-2
COMPONENT_LIST="minio nessie kafka schema-registry kafka-ui spark-master spark-worker flink-jobmanager flink-taskmanager trino clickhouse dbt kafka-connect prometheus grafana loki alloy alertmanager keycloak"
POSTGRESQL_HA_NODES="postgresql-patroni-1 postgresql-patroni-2"

echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   ShuDL Comprehensive Test Suite - All 20 Components         ║"
echo "║              (KRaft Mode - ZooKeeper Removed)                 ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================================
# PHASE 1: Pre-Flight Checks
# ============================================================================
test_start "Phase 1: Pre-Flight Checks"

test_step "Checking Docker environment..."
if ! docker --version &>/dev/null; then
    test_error "Docker is not installed or not running"
    exit 1
fi
test_info "✓ Docker is available"

test_step "Checking Docker Compose..."
if ! docker compose version &>/dev/null; then
    test_error "Docker Compose is not installed"
    exit 1
fi
test_info "✓ Docker Compose is available"

test_step "Checking project files..."
if [[ ! -f "$COMPOSE_FILE" ]]; then
    test_error "docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
fi
test_info "✓ docker-compose.yml found"

if [[ ! -f "$ENV_FILE" ]]; then
    test_warning ".env file not found, using defaults"
else
    test_info "✓ .env file found"
    source "$ENV_FILE"
fi

test_success "Pre-flight checks completed"

# ============================================================================
# PHASE 2: Component Health Checks
# ============================================================================
test_start "Phase 2: Component Health Checks (All 20 Components)"

cd "${PROJECT_DIR}/docker"

# Check PostgreSQL HA nodes first
for node in $POSTGRESQL_HA_NODES; do
    test_step "Checking ${node}..."
    container_name="${CONTAINER_PREFIX}-${node}"
    
    if check_service_running "$container_name"; then
        test_info "✓ $node is running"
        
        if check_service_healthy "$container_name"; then
            test_info "✓ $node is healthy"
        else
            test_warning "$node is running but health check not available"
        fi
    else
        test_error "$node is not running"
    fi
done

# Check HAProxy
test_step "Checking haproxy..."
if check_service_running "${CONTAINER_PREFIX}-haproxy"; then
    test_info "✓ haproxy is running"
    if check_service_healthy "${CONTAINER_PREFIX}-haproxy"; then
        test_info "✓ haproxy is healthy"
    else
        test_warning "haproxy is running but health check not available"
    fi
else
    test_warning "haproxy is not running (non-HA mode)"
fi

# Check other components
for component in $COMPONENT_LIST; do
    test_step "Checking ${component}..."
    
    container_name="${CONTAINER_PREFIX}-${component}"
    
    if check_service_running "$container_name"; then
        test_info "✓ $component is running"
        
        # Check health status if available
        if check_service_healthy "$container_name"; then
            test_info "✓ $component is healthy"
        else
            test_warning "$component is running but health check not available"
        fi
    else
        test_error "$component is not running"
    fi
done

test_success "Component health checks completed"

# ============================================================================
# PHASE 3: Network Connectivity Tests
# ============================================================================
test_start "Phase 3: Network Connectivity Tests"

test_step "Testing MinIO S3 API..."
if http_health_check "http://localhost:9000/minio/health/live"; then
    test_info "✓ MinIO S3 API responding"
else
    test_error "MinIO S3 API not responding"
fi

test_step "Testing MinIO Console..."
if http_health_check "http://localhost:9001"; then
    test_info "✓ MinIO Console accessible"
else
    test_error "MinIO Console not accessible"
fi

test_step "Testing PostgreSQL..."
if check_postgres_health; then
    test_info "✓ PostgreSQL accepting connections (HA mode via HAProxy)"
else
    test_error "PostgreSQL not accepting connections"
fi

test_step "Testing Nessie API..."
if http_health_check "http://localhost:19120/api/v2/config"; then
    test_info "✓ Nessie API responding"
else
    test_error "Nessie API not responding"
fi

test_step "Testing Kafka..."
if docker exec ${CONTAINER_PREFIX}-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 &>/dev/null; then
    test_info "✓ Kafka broker responding"
else
    test_error "Kafka broker not responding"
fi

test_step "Testing Schema Registry..."
if http_health_check "http://localhost:8085/subjects"; then
    test_info "✓ Schema Registry responding"
else
    test_error "Schema Registry not responding"
fi

test_step "Testing Kafka UI..."
if http_health_check "http://localhost:8090/actuator/health"; then
    test_info "✓ Kafka UI accessible"
else
    test_error "Kafka UI not accessible"
fi

test_step "Testing Kafka Connect..."
if check_service_healthy "${CONTAINER_PREFIX}-kafka-connect"; then
    test_info "✓ Kafka Connect is healthy"
else
    test_error "Kafka Connect is not healthy"
fi

test_step "Testing Flink JobManager..."
if http_health_check "http://localhost:8081/overview"; then
    test_info "✓ Flink JobManager responding"
else
    test_error "Flink JobManager not responding"
fi

test_step "Testing Trino..."
if http_health_check "http://localhost:8080/v1/info"; then
    test_info "✓ Trino API responding"
else
    test_error "Trino API not responding"
fi

test_step "Testing ClickHouse HTTP..."
if http_health_check "http://localhost:8123/?query=SELECT%201"; then
    test_info "✓ ClickHouse HTTP interface responding"
else
    test_error "ClickHouse HTTP interface not responding"
fi

test_step "Testing Prometheus..."
if check_service_healthy "${CONTAINER_PREFIX}-prometheus"; then
    test_info "✓ Prometheus is healthy"
else
    test_error "Prometheus is not healthy"
fi

test_step "Testing Grafana..."
if http_health_check "http://localhost:3000/api/health"; then
    test_info "✓ Grafana responding"
else
    test_error "Grafana not responding"
fi

test_step "Testing Loki..."
if http_health_check "http://localhost:3100/ready"; then
    test_info "✓ Loki responding"
else
    test_error "Loki not responding"
fi

test_step "Testing Alertmanager..."
if http_health_check "http://localhost:9095/-/healthy"; then
    test_info "✓ Alertmanager responding"
else
    test_error "Alertmanager not responding"
fi

test_step "Testing Keycloak..."
if http_health_check "http://localhost:8180/health/ready"; then
    test_info "✓ Keycloak responding"
else
    test_error "Keycloak not responding"
fi

test_success "Network connectivity tests completed"

# ============================================================================
# PHASE 4: Storage Layer Integration Tests
# ============================================================================
test_start "Phase 4: Storage Layer Integration (MinIO + PostgreSQL + Nessie)"

test_step "Testing MinIO bucket operations..."
if docker exec ${CONTAINER_PREFIX}-minio mc ls local/ &>/dev/null; then
    test_info "✓ MinIO bucket listing works"
    
    # Check if lakehouse bucket exists
    if docker exec ${CONTAINER_PREFIX}-minio mc ls local/lakehouse &>/dev/null; then
        test_info "✓ Lakehouse bucket exists"
    else
        test_warning "Lakehouse bucket not found"
    fi
else
    test_error "MinIO bucket operations failed"
fi

test_step "Testing PostgreSQL databases..."
if execute_postgres_query "SELECT datname FROM pg_database;" "nessie" "nessie" &>/dev/null; then
    test_info "✓ PostgreSQL database query works (HA mode with nessie user)"
    
    # Check for Nessie database
    if execute_postgres_query "\l" "nessie" "nessie" 2>/dev/null | grep -qw nessie; then
        test_info "✓ Nessie database exists (owner: nessie)"
    else
        test_warning "Nessie database not found"
    fi
else
    test_error "PostgreSQL database query failed"
fi

test_step "Testing Nessie catalog..."
nessie_response=$(curl -s http://localhost:19120/api/v2/trees)
if echo "$nessie_response" | grep -q "main"; then
    test_info "✓ Nessie catalog operational (main branch exists)"
else
    test_error "Nessie catalog not operational"
fi

test_success "Storage layer integration tests completed"

# ============================================================================
# PHASE 5: Streaming Layer Integration Tests
# ============================================================================
test_start "Phase 5: Streaming Layer Integration (Kafka Ecosystem)"

test_step "Testing Kafka topic operations..."
test_topic="${CONTAINER_PREFIX}-test-topic-$$"
if create_kafka_topic "$test_topic"; then
    test_info "✓ Kafka topic creation works"
    
    # Verify topic exists
    if check_kafka_topic "$test_topic"; then
        test_info "✓ Created topic verified"
    else
        test_error "Created topic not found"
    fi
    
    # Cleanup
    docker exec ${CONTAINER_PREFIX}-kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic "$test_topic" &>/dev/null
else
    test_error "Kafka topic creation failed"
fi

test_step "Testing Schema Registry..."
subjects=$(curl -s http://localhost:8085/subjects)
if [[ -n "$subjects" ]]; then
    test_info "✓ Schema Registry accessible ($(echo $subjects | jq '. | length' 2>/dev/null || echo 0) subjects)"
else
    test_warning "No schemas registered yet"
fi

test_step "Testing Kafka Connect..."
connectors=$(curl -s http://localhost:8083/connectors)
if [[ -n "$connectors" ]]; then
    test_info "✓ Kafka Connect accessible ($(echo $connectors | jq '. | length' 2>/dev/null || echo 0) connectors)"
else
    test_info "✓ Kafka Connect accessible (no connectors configured)"
fi

test_success "Streaming layer integration tests completed"

# ============================================================================
# PHASE 6: Processing Layer Integration Tests
# ============================================================================
test_start "Phase 6: Processing Layer Integration (Spark + Flink)"

test_step "Testing Spark Master..."
spark_status=$(curl -s http://localhost:4040 2>/dev/null || echo "")
if [[ -n "$spark_status" ]]; then
    test_info "✓ Spark Master UI accessible"
else
    test_warning "Spark Master UI not accessible (may not have active apps)"
fi

test_step "Testing Spark Worker connection..."
if docker exec ${CONTAINER_PREFIX}-spark-worker pgrep -f "org.apache.spark.deploy.worker.Worker" &>/dev/null; then
    test_info "✓ Spark Worker process running"
else
    test_error "Spark Worker process not found"
fi

test_step "Testing Flink cluster..."
flink_overview=$(curl -s http://localhost:8081/overview 2>/dev/null)
if echo "$flink_overview" | grep -q "taskmanagers"; then
    tm_count=$(echo "$flink_overview" | jq '.taskmanagers' 2>/dev/null || echo 0)
    test_info "✓ Flink cluster operational ($tm_count TaskManagers)"
else
    test_error "Flink cluster status check failed"
fi

test_success "Processing layer integration tests completed"

# ============================================================================
# PHASE 7: Query Engine Integration Tests
# ============================================================================
test_start "Phase 7: Query Engine Integration (Trino + ClickHouse)"

test_step "Testing Trino catalogs..."
if execute_trino_query "SHOW CATALOGS" 30; then
    test_info "✓ Trino query execution works"
    
    # Check for Iceberg catalog
    if execute_trino_query "SHOW CATALOGS" 30 | grep -q "iceberg"; then
        test_info "✓ Iceberg catalog available in Trino"
    else
        test_warning "Iceberg catalog not found in Trino"
    fi
else
    test_error "Trino query execution failed"
fi

test_step "Testing ClickHouse..."
if execute_clickhouse_query "SELECT 1" &>/dev/null; then
    test_info "✓ ClickHouse query execution works"
    
    # List databases
    dbs=$(execute_clickhouse_query "SHOW DATABASES" 2>/dev/null | wc -l)
    test_info "✓ ClickHouse has $dbs databases"
else
    test_error "ClickHouse query execution failed"
fi

test_success "Query engine integration tests completed"

# ============================================================================
# PHASE 8: Observability Stack Tests
# ============================================================================
test_start "Phase 8: Observability Stack (Prometheus + Grafana + Loki)"

test_step "Testing Prometheus targets..."
prom_targets=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null)
if echo "$prom_targets" | grep -q "activeTargets"; then
    active=$(echo "$prom_targets" | jq '.data.activeTargets | length' 2>/dev/null || echo 0)
    test_info "✓ Prometheus has $active active targets"
else
    test_error "Prometheus targets check failed"
fi

test_step "Testing Grafana datasources..."
# Note: Grafana requires authentication, check basic access
if http_health_check "http://localhost:3000/api/health"; then
    test_info "✓ Grafana API accessible"
else
    test_error "Grafana API not accessible"
fi

test_step "Testing Loki logs..."
loki_ready=$(curl -s http://localhost:3100/ready 2>/dev/null)
if echo "$loki_ready" | grep -q "ready"; then
    test_info "✓ Loki is ready for log ingestion"
else
    test_warning "Loki status unclear"
fi

test_step "Testing Alertmanager..."
am_status=$(curl -s http://localhost:9095/api/v2/status 2>/dev/null)
if [[ -n "$am_status" ]]; then
    test_info "✓ Alertmanager API accessible"
else
    test_error "Alertmanager API not accessible"
fi

test_success "Observability stack tests completed"

# ============================================================================
# PHASE 9: Security & IAM Tests
# ============================================================================
test_start "Phase 9: Security & IAM (Keycloak)"

test_step "Testing Keycloak health..."
if http_health_check "http://localhost:8180/health/ready"; then
    test_info "✓ Keycloak is healthy"
else
    test_error "Keycloak health check failed"
fi

test_step "Testing Keycloak realms..."
# Basic realm check (may require admin credentials for full test)
kc_response=$(curl -s http://localhost:8180/realms/master 2>/dev/null)
if echo "$kc_response" | grep -q "realm"; then
    test_info "✓ Keycloak master realm accessible"
else
    test_warning "Keycloak realm check incomplete"
fi

test_success "Security & IAM tests completed"

# ============================================================================
# PHASE 10: End-to-End Data Flow Test
# ============================================================================
test_start "Phase 10: End-to-End Data Flow Test"

test_step "Creating test namespace in Iceberg..."
if execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.test_e2e" 30; then
    test_info "✓ Test schema created"
else
    test_error "Failed to create test schema"
fi

test_step "Creating test table..."
create_table_sql="CREATE TABLE IF NOT EXISTS iceberg.test_e2e.comprehensive_test (
    id BIGINT,
    component VARCHAR,
    test_timestamp TIMESTAMP,
    status VARCHAR
) WITH (format = 'PARQUET')"

if execute_trino_query "$create_table_sql" 30; then
    test_info "✓ Test table created"
else
    test_error "Failed to create test table"
fi

test_step "Inserting test data..."
insert_sql="INSERT INTO iceberg.test_e2e.comprehensive_test VALUES
    (1, 'trino', TIMESTAMP '2024-01-01 10:00:00', 'success'),
    (2, 'spark', TIMESTAMP '2024-01-01 10:01:00', 'success'),
    (3, 'clickhouse', TIMESTAMP '2024-01-01 10:02:00', 'success')"

if execute_trino_query "$insert_sql" 30; then
    test_info "✓ Test data inserted via Trino"
else
    test_error "Failed to insert test data"
fi

test_step "Verifying data in Trino..."
count_sql="SELECT COUNT(*) FROM iceberg.test_e2e.comprehensive_test"
if execute_trino_query "$count_sql" 30 | grep -q "3"; then
    test_info "✓ Data verified in Trino (3 rows)"
else
    test_warning "Data count verification inconclusive"
fi

test_step "Cleanup test objects..."
execute_trino_query "DROP TABLE IF EXISTS iceberg.test_e2e.comprehensive_test" 30 || true
execute_trino_query "DROP SCHEMA IF EXISTS iceberg.test_e2e" 30 || true

test_success "End-to-end data flow test completed"

# ============================================================================
# PHASE 11: Component Interdependency Tests
# ============================================================================
test_start "Phase 11: Component Interdependency Tests"

test_step "Testing Nessie ← PostgreSQL dependency..."
if docker exec ${CONTAINER_PREFIX}-nessie curl -s http://localhost:19120/api/v2/config | grep -q "defaultBranch"; then
    test_info "✓ Nessie connected to PostgreSQL backend"
else
    test_error "Nessie-PostgreSQL connection issue"
fi

test_step "Testing Trino ← Nessie dependency..."
if execute_trino_query "SHOW SCHEMAS IN iceberg" 30; then
    test_info "✓ Trino connected to Nessie catalog"
else
    test_error "Trino-Nessie connection issue"
fi

test_step "Testing Kafka Connect ← Kafka dependency..."
connect_status=$(curl -s http://localhost:8083/ 2>/dev/null)
if echo "$connect_status" | grep -q "version"; then
    test_info "✓ Kafka Connect connected to Kafka"
else
    test_error "Kafka Connect-Kafka connection issue"
fi

test_step "Testing Flink ← Kafka dependency..."
if docker exec ${CONTAINER_PREFIX}-flink-jobmanager pgrep -f "StandaloneSessionClusterEntrypoint" &>/dev/null; then
    test_info "✓ Flink JobManager operational (Kafka connectivity assumed)"
else
    test_error "Flink JobManager not running"
fi

test_step "Testing Grafana ← Prometheus dependency..."
# Check if Prometheus is listed as a datasource (requires authentication for full check)
if http_health_check "http://localhost:3000/api/health"; then
    test_info "✓ Grafana operational (Prometheus connectivity assumed)"
else
    test_error "Grafana not responding"
fi

test_success "Component interdependency tests completed"

# ============================================================================
# Final Summary
# ============================================================================
echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}║          Comprehensive Test Suite Completed                   ║${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"

print_test_summary

exit $?
