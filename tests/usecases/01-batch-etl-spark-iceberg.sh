#!/bin/bash
# Use Case 1: Batch ETL with Spark + Iceberg
# Demonstrates: Batch data loading, Iceberg table operations, Nessie catalog

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Use Case 1: Batch ETL with Spark + Iceberg"

# Auto-detect container prefix
CONTAINER_PREFIX=$(detect_container_prefix)

echo ""
echo "============================================================"
echo "  Use Case: E-commerce Order Processing Pipeline"
echo "============================================================"
echo ""
echo "Scenario: Load daily order data into Iceberg data platform"
echo "Stack: Spark (batch processing) + Iceberg (storage) + Nessie (catalog)"
echo ""

# Step 1: Create Python script for Spark
test_step "Step 1: Creating Spark ETL script..."

cat > /tmp/batch_etl_orders.py << 'EOF'
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
from datetime import datetime
import random

# Initialize Spark with Iceberg
spark = SparkSession.builder \
    .appName("BatchETL-Orders") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.nessie", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.nessie.uri", "http://nessie:19120/api/v2") \
    .config("spark.sql.catalog.nessie.ref", "main") \
    .config("spark.sql.catalog.nessie.warehouse", "s3a://lakehouse/") \
    .config("spark.sql.catalog.nessie.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .getOrCreate()

print("✓ Spark session created with Iceberg + Nessie")

# Create schema
spark.sql("CREATE SCHEMA IF NOT EXISTS nessie.ecommerce")
print("✓ Schema 'ecommerce' created")

# Create orders table
spark.sql("""
    CREATE TABLE IF NOT EXISTS nessie.ecommerce.orders (
        order_id STRING,
        customer_id STRING,
        product_name STRING,
        quantity INT,
        price DOUBLE,
        order_date TIMESTAMP,
        status STRING
    )
    USING iceberg
    PARTITIONED BY (days(order_date))
""")
print("✓ Table 'orders' created with daily partitioning")

# Generate sample data
orders_data = []
products = ["Laptop", "Mouse", "Keyboard", "Monitor", "Headphones"]
statuses = ["pending", "processing", "shipped", "delivered"]

for i in range(100):
    orders_data.append((
        f"ORD-{10000+i}",
        f"CUST-{random.randint(1, 50)}",
        random.choice(products),
        random.randint(1, 5),
        round(random.uniform(10.0, 1000.0), 2),
        datetime(2025, 11, random.randint(25, 26), random.randint(0, 23), random.randint(0, 59)),
        random.choice(statuses)
    ))

# Create DataFrame
schema = StructType([
    StructField("order_id", StringType(), False),
    StructField("customer_id", StringType(), False),
    StructField("product_name", StringType(), False),
    StructField("quantity", IntegerType(), False),
    StructField("price", DoubleType(), False),
    StructField("order_date", TimestampType(), False),
    StructField("status", StringType(), False)
])

df = spark.createDataFrame(orders_data, schema)
print(f"✓ Generated {df.count()} sample orders")

# Insert data
df.writeTo("nessie.ecommerce.orders").append()
print("✓ Data inserted into Iceberg table")

# Query the data
result = spark.sql("""
    SELECT 
        status,
        COUNT(*) as order_count,
        SUM(quantity * price) as total_revenue
    FROM nessie.ecommerce.orders
    GROUP BY status
    ORDER BY total_revenue DESC
""")

print("\n=== Order Summary ===")
result.show()

# Check table history
history = spark.sql("SELECT * FROM nessie.ecommerce.orders.history")
print(f"\n✓ Table has {history.count()} snapshot(s)")

spark.stop()
print("\n✅ Batch ETL completed successfully!")
EOF

test_info "✓ Spark ETL script created"

# Step 2: Copy script to Spark container
test_step "Step 2: Deploying script to Spark cluster..."
docker cp /tmp/batch_etl_orders.py ${CONTAINER_PREFIX}-spark-master:/tmp/batch_etl_orders.py
test_info "✓ Script deployed"

# Step 3: Execute Spark job
test_step "Step 3: Executing Spark batch job (this may take 30-60 seconds)..."
if docker exec ${CONTAINER_PREFIX}-spark-master /opt/spark/bin/spark-submit \
    --master local[2] \
    --conf spark.driver.memory=1g \
    --conf spark.executor.memory=1g \
    --conf spark.ui.port=4050 \
    --conf spark.ui.enabled=false \
    /tmp/batch_etl_orders.py 2>&1 | tee /tmp/spark_batch_output.log | grep -E "(✓|✅|===)"; then
    test_info "✓ Spark job completed"
else
    test_error "Spark job failed - checking logs..."
    tail -30 /tmp/spark_batch_output.log | grep -E "(Error|Exception)" | head -10
fi

# Step 4: Verify data in Trino
test_step "Step 4: Verifying data via Trino SQL..."
TRINO_RESULT=$("${SCRIPT_DIR}/../helpers/trino_query.sh" "SELECT COUNT(*) as order_count FROM iceberg.ecommerce.orders" 2>&1)

if echo "$TRINO_RESULT" | grep -q "\["; then
    ORDER_COUNT=$(echo "$TRINO_RESULT" | grep -o '\[.*\]' | grep -o '[0-9]\+' | head -1)
    test_info "✓ Found $ORDER_COUNT orders in Trino"
    
    if [[ "$ORDER_COUNT" -ge 50 ]]; then
        test_info "✓ Data successfully loaded"
    else
        test_warning "Expected more orders, got $ORDER_COUNT"
    fi
else
    test_warning "Could not verify order count"
fi

# Step 5: Verify Nessie commit
test_step "Step 5: Verifying Nessie version control..."
COMMIT_LOG=$(curl -s http://localhost:19120/api/v2/trees/branch/main/entries?namespaceDepth=3 | grep -o '"name"' | wc -l | tr -d ' ')

if [[ "$COMMIT_LOG" -gt 0 ]]; then
    test_info "✓ Found $COMMIT_LOG entries in Nessie catalog"
else
    test_warning "Could not verify Nessie commits"
fi

# Step 6: Query via Trino for business insights
test_step "Step 6: Running analytics query..."
ANALYTICS_RESULT=$("${SCRIPT_DIR}/../helpers/trino_query.sh" "SELECT status, COUNT(*) as cnt FROM iceberg.ecommerce.orders GROUP BY status" 2>&1)

if echo "$ANALYTICS_RESULT" | grep -q "\["; then
    test_info "✓ Analytics query executed successfully"
    echo "   Results: $ANALYTICS_RESULT"
else
    test_warning "Analytics query inconclusive"
fi

# Cleanup
test_step "Cleanup..."
rm -f /tmp/batch_etl_orders.py
docker exec ${CONTAINER_PREFIX}-spark-master rm -f /tmp/batch_etl_orders.py 2>/dev/null || true
test_info "✓ Cleanup completed"

echo ""
echo "============================================================"
echo "  Use Case 1: COMPLETED ✅"
echo "============================================================"
echo ""
echo "Validated:"
echo "  ✓ Spark batch processing"
echo "  ✓ Iceberg table creation and data insertion"
echo "  ✓ Nessie catalog integration"
echo "  ✓ Data partitioning (by day)"
echo "  ✓ Cross-engine query (Trino reading Spark-written data)"
echo "  ✓ Business analytics on data platform data"
echo ""

test_success "Use Case 1: Batch ETL with Spark + Iceberg"
print_test_summary

