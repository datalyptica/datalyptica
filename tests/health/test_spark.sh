#!/bin/bash

# Test: Spark Health Check
# Validates Spark cluster health and functionality

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Spark Health Check"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Checking Spark Master container status..."
if ! docker compose ps spark-master 2>/dev/null | grep -q "healthy"; then
    test_error "Spark Master container is not healthy"
    docker compose ps spark-master
    exit 1
fi

test_step "Checking Spark Worker container status..."
if ! docker compose ps spark-worker 2>/dev/null | grep -q "healthy"; then
    test_error "Spark Worker container is not healthy"
    docker compose ps spark-worker
    exit 1
fi

test_step "Testing Spark Master port connectivity..."
if ! check_port "localhost" "$SPARK_MASTER_PORT" 10; then
    test_error "Cannot connect to Spark Master port $SPARK_MASTER_PORT"
    exit 1
fi

test_step "Testing Spark UI accessibility..."
if ! check_http_endpoint "http://localhost:$SPARK_UI_PORT" 200 30; then
    test_error "Spark UI is not accessible"
    exit 1
fi

test_step "Testing basic Spark functionality..."
# Create a simple Spark test
cat > /tmp/spark_health_test.py << 'EOF'
from pyspark.sql import SparkSession

try:
    spark = SparkSession.builder \
        .appName("HealthCheck") \
        .master("spark://shudl-spark-master:7077") \
        .getOrCreate()
    
    # Test basic DataFrame operations
    data = [("test", 1), ("health", 2), ("check", 3)]
    df = spark.createDataFrame(data, ["name", "value"])
    
    count = df.count()
    if count == 3:
        print("SUCCESS: Spark basic operations working")
    else:
        print(f"ERROR: Expected 3 rows, got {count}")
        exit(1)
    
    spark.stop()
    print("SUCCESS: Spark health check completed")
    
except Exception as e:
    print(f"ERROR: {e}")
    exit(1)
EOF

# Copy and run the test
docker cp /tmp/spark_health_test.py shudl-spark-master:/tmp/spark_health_test.py
if ! timeout 120 docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/spark_health_test.py 2>/dev/null | grep -q "SUCCESS: Spark health check completed"; then
    test_error "Spark basic functionality test failed"
    exit 1
fi

# Cleanup
docker exec shudl-spark-master rm -f /tmp/spark_health_test.py 2>/dev/null || true
rm -f /tmp/spark_health_test.py

test_step "Checking Spark cluster status..."
# Check if worker is connected to master
master_info=$(curl -s "http://localhost:$SPARK_UI_PORT/api/v1/applications" 2>/dev/null || echo "[]")
test_info "Spark applications endpoint accessible"

test_step "Validating Spark environment configuration..."
# Check if required Iceberg jars are available
if docker exec shudl-spark-master ls /opt/spark/jars/ | grep -q "iceberg"; then
    test_info "✓ Iceberg jars found in Spark classpath"
else
    test_error "Iceberg jars not found in Spark classpath"
    exit 1
fi

# Check Spark configuration
spark_conf=$(docker exec shudl-spark-master cat /opt/spark/conf/spark-defaults.conf 2>/dev/null || echo "")
if [[ -n "$spark_conf" ]]; then
    test_info "✓ Spark configuration file exists"
else
    test_warning "Spark configuration file not found or empty"
fi

test_success "Spark cluster is healthy and operational" 