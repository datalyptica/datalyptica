#!/bin/bash

# Test Helper Functions
# Common utilities for all test scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test state
TEST_NAME=""
TEST_START_TIME=""
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
test_start() {
    TEST_NAME="$1"
    TEST_START_TIME=$(date +%s)
    echo -e "${PURPLE}==== $TEST_NAME ====${NC}"
}

test_step() {
    echo -e "${CYAN}🔄 $1${NC}"
}

test_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

test_success() {
    local end_time=$(date +%s)
    local duration=$((end_time - TEST_START_TIME))
    echo -e "${GREEN}✅ $1 (${duration}s)${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_error() {
    echo -e "${RED}❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if service is running
check_service_running() {
    local service_name="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${service_name}$"; then
        return 0
    else
        return 1
    fi
}

# Check if service is healthy
check_service_healthy() {
    local service_name="$1"
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$service_name" 2>/dev/null)
    if [[ "$health" == "healthy" ]]; then
        return 0
    else
        return 1
    fi
}

# Wait for service to be healthy
wait_for_service() {
    local service_name="$1"
    local timeout="${2:-120}"
    local elapsed=0
    
    test_step "Waiting for $service_name to be healthy..."
    
    while [[ $elapsed -lt $timeout ]]; do
        if check_service_healthy "$service_name"; then
            test_info "✓ $service_name is healthy"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    test_error "$service_name did not become healthy within ${timeout}s"
    return 1
}

# HTTP health check
http_health_check() {
    local url="$1"
    local expected_code="${2:-200}"
    local timeout="${3:-10}"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    
    if [[ "$response" == "$expected_code" ]]; then
        return 0
    else
        return 1
    fi
}

# Execute Trino query
execute_trino_query() {
    local query="$1"
    local timeout="${2:-30}"
    
    timeout "$timeout" docker exec shudl-trino trino --execute "$query" 2>/dev/null
    return $?
}

# Execute Spark SQL
execute_spark_sql() {
    local query="$1"
    local timeout="${2:-60}"
    
    local temp_script="/tmp/spark_query_$$.py"
    cat > "$temp_script" << EOF
from pyspark.sql import SparkSession
import sys

spark = SparkSession.builder \\
    .appName("QueryTest") \\
    .master("spark://shudl-spark-master:7077") \\
    .getOrCreate()

try:
    result = spark.sql("$query")
    result.show()
    spark.stop()
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}")
    spark.stop()
    sys.exit(1)
EOF
    
    docker cp "$temp_script" shudl-spark-master:/tmp/spark_query.py
    timeout "$timeout" docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/spark_query.py 2>/dev/null
    local result=$?
    
    rm -f "$temp_script"
    docker exec shudl-spark-master rm -f /tmp/spark_query.py 2>/dev/null || true
    
    return $result
}

# Execute ClickHouse query
execute_clickhouse_query() {
    local query="$1"
    
    docker exec shudl-clickhouse clickhouse-client --query "$query" 2>/dev/null
    return $?
}

# Check Kafka topic exists
check_kafka_topic() {
    local topic="$1"
    
    docker exec shudl-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | grep -q "^${topic}$"
    return $?
}

# Create Kafka topic
create_kafka_topic() {
    local topic="$1"
    local partitions="${2:-3}"
    local replication="${3:-1}"
    
    docker exec shudl-kafka kafka-topics --bootstrap-server localhost:9092 \
        --create --topic "$topic" \
        --partitions "$partitions" \
        --replication-factor "$replication" 2>/dev/null
    return $?
}

# Check Schema Registry schema
check_schema_exists() {
    local subject="$1"
    
    curl -s http://localhost:8085/subjects | grep -q "\"${subject}\""
    return $?
}

# Print test summary
print_test_summary() {
    echo ""
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}        Test Summary${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${GREEN}✅ Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}📊 Total:  $TESTS_TOTAL${NC}"
    echo -e "${PURPLE}========================================${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}💥 Some tests failed${NC}"
        return 1
    fi
}
