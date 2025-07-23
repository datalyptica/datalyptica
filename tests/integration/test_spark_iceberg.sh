#!/bin/bash

# Test: Spark-Iceberg Integration
# Validates that Spark can properly interact with Iceberg tables

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Spark-Iceberg Integration Test"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Creating test namespace and table..."

# Create Spark script for Iceberg operations
cat > /tmp/spark_iceberg_test.py << 'EOF'
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType
import random

try:
    # Initialize Spark with Iceberg support
    spark = SparkSession.builder \
        .appName("Spark_Iceberg_Integration_Test") \
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
    
    print("✓ Spark session with Iceberg support created successfully")
    
    # Create namespace
    spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.test_integration")
    print("✓ Test namespace created")
    
    # Create test table
    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.test_integration.spark_test_table (
            id INT,
            name STRING,
            value DOUBLE,
            category STRING
        ) USING iceberg
    """)
    print("✓ Test table created")
    
    # Generate test data
    test_data = []
    for i in range(100):
        test_data.append((
            i,
            f"item_{i}",
            round(random.uniform(1.0, 100.0), 2),
            f"category_{i % 5}"
        ))
    
    schema = StructType([
        StructField("id", IntegerType(), False),
        StructField("name", StringType(), True),
        StructField("value", DoubleType(), True),
        StructField("category", StringType(), True)
    ])
    
    df = spark.createDataFrame(test_data, schema)
    
    # Insert data into Iceberg table
    df.write.mode("overwrite").insertInto("iceberg.test_integration.spark_test_table")
    print("✓ Test data inserted")
    
    # Read data back
    result_df = spark.sql("SELECT * FROM iceberg.test_integration.spark_test_table")
    row_count = result_df.count()
    
    if row_count == 100:
        print(f"✓ Data read successfully: {row_count} rows")
    else:
        print(f"✗ Expected 100 rows, got {row_count}")
        exit(1)
    
    # Test aggregations
    agg_result = spark.sql("""
        SELECT 
            category,
            COUNT(*) as count,
            ROUND(AVG(value), 2) as avg_value,
            ROUND(SUM(value), 2) as total_value
        FROM iceberg.test_integration.spark_test_table 
        GROUP BY category 
        ORDER BY category
    """)
    
    agg_count = agg_result.count()
    if agg_count == 5:
        print("✓ Aggregation queries working")
    else:
        print(f"✗ Expected 5 categories, got {agg_count}")
        exit(1)
    
    # Test schema evolution - add new column
    spark.sql("ALTER TABLE iceberg.test_integration.spark_test_table ADD COLUMN new_field STRING")
    print("✓ Schema evolution (add column) successful")
    
    # Insert data with new schema
    new_data = [(101, "new_item", 50.0, "new_category", "additional_info")]
    new_schema = StructType([
        StructField("id", IntegerType(), False),
        StructField("name", StringType(), True),
        StructField("value", DoubleType(), True),
        StructField("category", StringType(), True),
        StructField("new_field", StringType(), True)
    ])
    
    new_df = spark.createDataFrame(new_data, new_schema)
    new_df.write.mode("append").insertInto("iceberg.test_integration.spark_test_table")
    print("✓ Data inserted with evolved schema")
    
    # Verify mixed schema data
    final_result = spark.sql("SELECT * FROM iceberg.test_integration.spark_test_table WHERE id > 100")
    if final_result.count() == 1:
        print("✓ Schema evolution data verification successful")
    else:
        print("✗ Schema evolution data verification failed")
        exit(1)
    
    # Test table metadata
    table_info = spark.sql("DESCRIBE TABLE iceberg.test_integration.spark_test_table")
    if table_info.count() >= 5:  # Should have at least 5 columns now
        print("✓ Table metadata accessible")
    else:
        print("✗ Table metadata incomplete")
        exit(1)
    
    print("SUCCESS: All Spark-Iceberg integration tests passed")
    
except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
finally:
    # Cleanup
    try:
        spark.sql("DROP TABLE IF EXISTS iceberg.test_integration.spark_test_table")
        spark.sql("DROP NAMESPACE IF EXISTS iceberg.test_integration")
        print("✓ Cleanup completed")
    except:
        pass
    
    try:
        spark.stop()
    except:
        pass
EOF

test_step "Running Spark-Iceberg integration test..."
docker cp /tmp/spark_iceberg_test.py shudl-spark-master:/tmp/spark_iceberg_test.py

# Run the test and capture output
test_output=$(timeout 360 docker exec shudl-spark-master /opt/spark/bin/spark-submit /tmp/spark_iceberg_test.py 2>&1)
test_exit_code=$?

# Check for success message in output
if echo "$test_output" | grep -q "SUCCESS: All Spark-Iceberg integration tests passed"; then
    test_info "✓ Spark-Iceberg integration test completed successfully"
else
    test_error "Spark-Iceberg integration test failed"
    test_info "Exit code: $test_exit_code"
    test_info "Last 10 lines of output:"
    echo "$test_output" | tail -10
    test_info "First 5 lines of output:"  
    echo "$test_output" | head -5
    exit 1
fi

# Cleanup
docker exec shudl-spark-master rm -f /tmp/spark_iceberg_test.py 2>/dev/null || true
rm -f /tmp/spark_iceberg_test.py

test_success "Spark-Iceberg integration is working correctly" 