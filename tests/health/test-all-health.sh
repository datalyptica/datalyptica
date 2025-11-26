#!/bin/bash

# Health Check Tests for All 21 Components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Health Check: All 21 Components"

# Storage Layer (3)
test_step "1. MinIO (Object Storage)"
if http_health_check "http://localhost:9000/minio/health/live"; then
    test_info "✅ MinIO is healthy"
else
    test_error "❌ MinIO health check failed"
fi

test_step "2. PostgreSQL (Metadata Store)"
if docker exec shudl-postgresql pg_isready -U postgres &>/dev/null; then
    test_info "✅ PostgreSQL is healthy"
else
    test_error "❌ PostgreSQL health check failed"
fi

test_step "3. Nessie (Data Catalog)"
if http_health_check "http://localhost:19120/api/v2/config"; then
    test_info "✅ Nessie is healthy"
else
    test_error "❌ Nessie health check failed"
fi

# Streaming Layer (4)
test_step "4. Zookeeper (Coordination Service)"
if docker exec shudl-zookeeper nc -z localhost 2181 &>/dev/null; then
    test_info "✅ Zookeeper is healthy"
else
    test_error "❌ Zookeeper health check failed"
fi

test_step "5. Kafka (Message Broker)"
if docker exec shudl-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 &>/dev/null; then
    test_info "✅ Kafka is healthy"
else
    test_error "❌ Kafka health check failed"
fi

test_step "6. Schema Registry (Schema Management)"
if http_health_check "http://localhost:8085/subjects"; then
    test_info "✅ Schema Registry is healthy"
else
    test_error "❌ Schema Registry health check failed"
fi

test_step "7. Kafka UI (Management Console)"
if http_health_check "http://localhost:8090/actuator/health"; then
    test_info "✅ Kafka UI is healthy"
else
    test_error "❌ Kafka UI health check failed"
fi

# Processing Layer (4)
test_step "8. Spark Master (Batch Processing)"
if docker exec shudl-spark-master pgrep -f "org.apache.spark.deploy.master.Master" &>/dev/null; then
    test_info "✅ Spark Master is healthy"
else
    test_error "❌ Spark Master health check failed"
fi

test_step "9. Spark Worker (Batch Execution)"
if docker exec shudl-spark-worker pgrep -f "org.apache.spark.deploy.worker.Worker" &>/dev/null; then
    test_info "✅ Spark Worker is healthy"
else
    test_error "❌ Spark Worker health check failed"
fi

test_step "10. Flink JobManager (Stream Processing Coordinator)"
if http_health_check "http://localhost:8081/overview"; then
    test_info "✅ Flink JobManager is healthy"
else
    test_error "❌ Flink JobManager health check failed"
fi

test_step "11. Flink TaskManager (Stream Processing Executor)"
if docker exec shudl-flink-taskmanager pgrep -f "org.apache.flink.runtime.taskexecutor.TaskManagerRunner" &>/dev/null; then
    test_info "✅ Flink TaskManager is healthy"
else
    test_error "❌ Flink TaskManager health check failed"
fi

# Query/Analytics Layer (4)
test_step "12. Trino (SQL Query Engine)"
if http_health_check "http://localhost:8080/v1/info"; then
    test_info "✅ Trino is healthy"
else
    test_error "❌ Trino health check failed"
fi

test_step "13. ClickHouse (OLAP Database)"
if http_health_check "http://localhost:8123/?query=SELECT%201"; then
    test_info "✅ ClickHouse is healthy"
else
    test_error "❌ ClickHouse health check failed"
fi

test_step "14. dbt (Data Transformation)"
if docker exec shudl-dbt which dbt &>/dev/null; then
    test_info "✅ dbt is healthy"
else
    test_error "❌ dbt health check failed"
fi

test_step "15. Kafka Connect (CDC/Integration)"
if http_health_check "http://localhost:8083/"; then
    test_info "✅ Kafka Connect is healthy"
else
    test_error "❌ Kafka Connect health check failed"
fi

# Observability Layer (6)
test_step "16. Prometheus (Metrics Collection)"
if http_health_check "http://localhost:9090/-/healthy"; then
    test_info "✅ Prometheus is healthy"
else
    test_error "❌ Prometheus health check failed"
fi

test_step "17. Grafana (Visualization)"
if http_health_check "http://localhost:3000/api/health"; then
    test_info "✅ Grafana is healthy"
else
    test_error "❌ Grafana health check failed"
fi

test_step "18. Loki (Log Aggregation)"
if http_health_check "http://localhost:3100/ready"; then
    test_info "✅ Loki is healthy"
else
    test_error "❌ Loki health check failed"
fi

test_step "19. Alloy (Log Collection)"
if docker exec shudl-alloy pgrep -f "alloy" &>/dev/null; then
    test_info "✅ Alloy is healthy"
else
    test_error "❌ Alloy health check failed"
fi

test_step "20. Alertmanager (Alert Routing)"
if http_health_check "http://localhost:9095/-/healthy"; then
    test_info "✅ Alertmanager is healthy"
else
    test_error "❌ Alertmanager health check failed"
fi

test_step "21. Keycloak (Identity & Access Management)"
if http_health_check "http://localhost:8180/health/ready"; then
    test_info "✅ Keycloak is healthy"
else
    test_error "❌ Keycloak health check failed"
fi

test_success "Health check completed for all 21 components"

print_test_summary
