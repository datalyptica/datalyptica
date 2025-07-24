#!/bin/bash

# Test: Cross-Engine Data Access
# Validates data written by one engine can be read by another

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Cross-Engine Data Access Test"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Cleaning up any existing test data..."

# Cleanup any existing test data before starting
execute_trino_query "DROP TABLE IF EXISTS iceberg.cross_engine_test.shared_data" 60 || true
execute_trino_query "DROP SCHEMA IF EXISTS iceberg.cross_engine_test" 60 || true

test_step "Creating test data with Trino..."

# Create namespace and table with Trino
if ! execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.cross_engine_test" 60; then
    test_error "Cannot create test schema with Trino"
    exit 1
fi

# Create table with Trino
trino_create_table="CREATE TABLE IF NOT EXISTS iceberg.cross_engine_test.shared_data (
    id BIGINT,
    name VARCHAR,
    amount DECIMAL(10,2),
    created_date DATE,
    metadata VARCHAR
) WITH (format = 'PARQUET')"

if ! execute_trino_query "$trino_create_table" 60; then
    test_error "Cannot create table with Trino"
    exit 1
fi

# Insert data with Trino
trino_insert_data="INSERT INTO iceberg.cross_engine_test.shared_data VALUES
    (1, 'trino_record_1', 100.50, DATE '2024-01-01', 'created_by_trino'),
    (2, 'trino_record_2', 250.75, DATE '2024-01-02', 'created_by_trino'),
    (3, 'trino_record_3', 500.00, DATE '2024-01-03', 'created_by_trino')"

if ! execute_trino_query "$trino_insert_data" 60; then
    test_error "Cannot insert data with Trino"
    exit 1
fi

test_info "✓ Test data created with Trino"

test_step "Reading Trino data with Spark..."

# Create Spark script to read Trino data
cat > /tmp/spark_read_trino_data.py << 'EOF'
from pyspark.sql import SparkSession

try:
    spark = SparkSession.builder \
        .appName("Cross_Engine_Read_Test") \
        .master("spark://shudl-spark-master:7077") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.iceberg.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \
        .config("spark.sql.catalog.iceberg.uri", "http://nessie:19120/api/v2") \
        .config("spark.sql.catalog.iceberg.ref", "main") \
        .config("spark.sql.catalog.iceberg.warehouse", "s3://lakehouse/") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "admin") \
        .config("spark.hadoop.fs.s3a.secret.key", "password123") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider") \
        .config("spark.sql.catalog.iceberg.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
        .config("spark.sql.catalog.iceberg.s3.endpoint", "http://minio:9000") \
        .config("spark.sql.catalog.iceberg.s3.path-style-access", "true") \
        .config("spark.sql.catalog.iceberg.s3.access-key-id", "admin") \
        .config("spark.sql.catalog.iceberg.s3.secret-access-key", "password123") \
        .getOrCreate()
    
    # Read data created by Trino
    df = spark.sql("SELECT * FROM iceberg.cross_engine_test.shared_data WHERE metadata = 'created_by_trino'")
    trino_count = df.count()
    
    if trino_count == 3:
        print(f"✓ Successfully read {trino_count} records created by Trino")
    else:
        print(f"✗ Expected 3 records, got {trino_count}")
        exit(1)
    
    # Add data with Spark
    spark.sql("""
        INSERT INTO iceberg.cross_engine_test.shared_data VALUES
        (4, 'spark_record_1', 150.25, DATE '2024-01-04', 'created_by_spark'),
        (5, 'spark_record_2', 300.50, DATE '2024-01-05', 'created_by_spark'),
        (6, 'spark_record_3', 450.75, DATE '2024-01-06', 'created_by_spark')
    """)
    
    print("✓ Added data with Spark")
    
    # Verify total count
    total_df = spark.sql("SELECT * FROM iceberg.cross_engine_test.shared_data")
    total_count = total_df.count()
    
    if total_count == 6:
        print(f"✓ Total records after Spark insert: {total_count}")
    else:
        print(f"✗ Expected 6 total records, got {total_count}")
        exit(1)
    
    # Test aggregation across both datasets
    agg_df = spark.sql("""
        SELECT 
            metadata,
            COUNT(*) as count,
            ROUND(SUM(amount), 2) as total_amount
        FROM iceberg.cross_engine_test.shared_data 
        GROUP BY metadata 
        ORDER BY metadata
    """)
    
    agg_results = agg_df.collect()
    if len(agg_results) == 2:
        print("✓ Cross-engine aggregation successful")
        for row in agg_results:
            print(f"  {row.metadata}: {row.count} records, total: ${row.total_amount}")
    else:
        print(f"✗ Expected 2 aggregation groups, got {len(agg_results)}")
        exit(1)
    
    print("SUCCESS: Spark successfully read and modified Trino data")
    
except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
finally:
    try:
        spark.stop()
    except:
        pass
EOF

docker cp /tmp/spark_read_trino_data.py shudl-spark-master:/tmp/spark_read_trino_data.py

if timeout 180 docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/spark_read_trino_data.py 2>/dev/null | grep -q "SUCCESS: Spark successfully read and modified Trino data"; then
    test_info "✓ Spark successfully accessed Trino data"
else
    test_error "Spark failed to access Trino data"
    # Show error details
    docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/spark_read_trino_data.py || true
    exit 1
fi

test_step "Reading Spark data with Trino..."

# Verify Trino can read data added by Spark
spark_data_query="SELECT metadata, COUNT(*) as count, ROUND(SUM(amount), 2) as total 
                  FROM iceberg.cross_engine_test.shared_data 
                  WHERE metadata = 'created_by_spark' 
                  GROUP BY metadata"

if execute_trino_query "$spark_data_query" 60 | grep -q "created_by_spark.*3.*901.50"; then
    test_info "✓ Trino successfully read Spark data"
else
    test_error "Trino failed to read Spark data correctly"
    execute_trino_query "$spark_data_query" 60 || true
    exit 1
fi

test_step "Verifying final data integrity..."

# Check final state with both engines
total_query="SELECT COUNT(*) as total_records FROM iceberg.cross_engine_test.shared_data"

trino_total=$(execute_trino_query "$total_query" 60 | grep -o "[0-9]\+" | head -1)
if [[ "$trino_total" == "6" ]]; then
    test_info "✓ Trino sees correct total: $trino_total records"
else
    test_error "Trino total count incorrect: expected 6, got $trino_total"
    exit 1
fi

test_step "Testing schema consistency..."

# Verify schema is consistent between engines
trino_schema=$(execute_trino_query "DESCRIBE iceberg.cross_engine_test.shared_data" 60)
if echo "$trino_schema" | grep -q "id.*bigint\|name.*varchar\|amount.*decimal"; then
    test_info "✓ Schema consistency verified"
else
    test_warning "Schema information may be inconsistent"
fi

test_step "Cleanup..."

# Cleanup test data
execute_trino_query "DROP TABLE IF EXISTS iceberg.cross_engine_test.shared_data" 60 || true
execute_trino_query "DROP SCHEMA IF EXISTS iceberg.cross_engine_test" 60 || true

# Cleanup files
docker exec shudl-spark-master rm -f /tmp/spark_read_trino_data.py 2>/dev/null || true
rm -f /tmp/spark_read_trino_data.py

test_success "Cross-engine data access working perfectly" 