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
}

test_error() {
    local end_time=$(date +%s)
    local duration=$((end_time - TEST_START_TIME))
    echo -e "${RED}❌ $1 (${duration}s)${NC}"
}

test_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Utility functions
wait_for_service() {
    local service_name="$1"
    local max_wait="${2:-300}"  # Default 5 minutes
    local check_interval="${3:-5}"  # Default 5 seconds
    
    test_info "Waiting for $service_name to be ready (max ${max_wait}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if docker compose ps "$service_name" 2>/dev/null | grep -q "healthy"; then
            test_info "✓ $service_name is ready"
            return 0
        fi
        
        sleep "$check_interval"
        elapsed=$((elapsed + check_interval))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            test_info "Still waiting for $service_name... (${elapsed}s elapsed)"
        fi
    done
    
    test_error "$service_name failed to become ready within ${max_wait} seconds"
    return 1
}

check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-10}"
    
    if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_http_endpoint() {
    local url="$1"
    local expected_status="${2:-200}"
    local timeout="${3:-10}"
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$response_code" == "$expected_status" ]]; then
        return 0
    else
        test_info "Expected HTTP $expected_status, got $response_code for $url"
        return 1
    fi
}

execute_sql_query() {
    local query="$1"
    local database="${2:-$POSTGRES_DB}"
    local user="${3:-$POSTGRES_USER}"
    local timeout="${4:-30}"
    
    timeout "$timeout" docker exec shudl-postgresql psql -U "$user" -d "$database" -c "$query" 2>/dev/null
}

execute_trino_query() {
    local query="$1"
    local timeout="${2:-60}"
    
    timeout "$timeout" docker exec shudl-trino /opt/trino/bin/trino --server http://localhost:8080 --execute "$query" 2>/dev/null
}

execute_spark_sql() {
    local query="$1"
    local timeout="${2:-120}"
    
    local temp_script="/tmp/spark_test_$$.py"
    cat > "$temp_script" << EOF
from pyspark.sql import SparkSession

spark = SparkSession.builder \\
    .appName("TestQuery") \\
    .master("spark://shudl-spark-master:7077") \\
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \\
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.iceberg.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \\
    .config("spark.sql.catalog.iceberg.uri", "http://nessie:19120/api/v2") \\
    .config("spark.sql.catalog.iceberg.ref", "main") \\
    .config("spark.sql.catalog.iceberg.warehouse", "s3://lakehouse/") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "admin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "password123") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider") \\
    .config("spark.sql.catalog.iceberg.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \\
    .config("spark.sql.catalog.iceberg.s3.endpoint", "http://minio:9000") \\
    .config("spark.sql.catalog.iceberg.s3.path-style-access", "true") \\
    .config("spark.sql.catalog.iceberg.s3.access-key-id", "admin") \\
    .config("spark.sql.catalog.iceberg.s3.secret-access-key", "password123") \\
    .getOrCreate()

result = spark.sql("$query")
result.show()
spark.stop()
EOF
    
    docker cp "$temp_script" shudl-spark-master:/tmp/spark_test.py
    timeout "$timeout" docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/spark_test.py 2>/dev/null
    local result=$?
    
    rm -f "$temp_script"
    docker exec shudl-spark-master rm -f /tmp/spark_test.py 2>/dev/null || true
    
    return $result
}

generate_test_data() {
    local table_name="$1"
    local num_rows="${2:-1000}"
    local schema="${3:-test_schema}"
    
    local temp_script="/tmp/generate_data_$$.py"
    cat > "$temp_script" << EOF
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, DateType
from pyspark.sql.functions import lit
import random
from datetime import datetime, timedelta

spark = SparkSession.builder \\
    .appName("DataGenerator") \\
    .master("spark://shudl-spark-master:7077") \\
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \\
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \\
    .config("spark.sql.catalog.iceberg.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \\
    .config("spark.sql.catalog.iceberg.uri", "http://nessie:19120/api/v2") \\
    .config("spark.sql.catalog.iceberg.ref", "main") \\
    .config("spark.sql.catalog.iceberg.warehouse", "s3://lakehouse/") \\
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \\
    .config("spark.hadoop.fs.s3a.access.key", "admin") \\
    .config("spark.hadoop.fs.s3a.secret.key", "password123") \\
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \\
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
    .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider") \\
    .config("spark.sql.catalog.iceberg.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \\
    .config("spark.sql.catalog.iceberg.s3.endpoint", "http://minio:9000") \\
    .config("spark.sql.catalog.iceberg.s3.path-style-access", "true") \\
    .config("spark.sql.catalog.iceberg.s3.access-key-id", "admin") \\
    .config("spark.sql.catalog.iceberg.s3.secret-access-key", "password123") \\
    .getOrCreate()

# Generate test data
data = []
for i in range($num_rows):
    data.append((
        i + 1,
        f"user_{i}",
        f"product_{random.randint(1, 100)}",
        random.randint(1, 10),
        round(random.uniform(10.0, 1000.0), 2),
        "2024-01-01"
    ))

schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("user_name", StringType(), True),
    StructField("product", StringType(), True),
    StructField("quantity", IntegerType(), True),
    StructField("price", DoubleType(), True),
    StructField("date", StringType(), True)
])

df = spark.createDataFrame(data, schema)

# Create namespace if not exists
spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.$schema")

# Create table and insert data
df.write.mode("overwrite").saveAsTable(f"iceberg.$schema.$table_name")

print(f"Generated $num_rows rows in iceberg.$schema.$table_name")
spark.stop()
EOF
    
    docker cp "$temp_script" shudl-spark-master:/tmp/generate_data.py
    docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/generate_data.py
    local result=$?
    
    rm -f "$temp_script"
    docker exec shudl-spark-master rm -f /tmp/generate_data.py 2>/dev/null || true
    
    return $result
}

cleanup_test_data() {
    local table_name="$1"
    local schema="${2:-test_schema}"
    
    execute_spark_sql "DROP TABLE IF EXISTS iceberg.$schema.$table_name" 30 || true
    execute_trino_query "DROP TABLE IF EXISTS iceberg.$schema.$table_name" 30 || true
} 