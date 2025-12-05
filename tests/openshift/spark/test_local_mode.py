#!/usr/bin/env python3
"""
Simple Spark Local Mode Test - Write to Iceberg via Nessie
Tests: Spark Local → Nessie → Iceberg → MinIO
"""

import sys
from datetime import datetime, timedelta
from decimal import Decimal
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DecimalType, TimestampType

print("=" * 80)
print("SPARK LOCAL MODE TEST: Iceberg Write via Nessie")
print("=" * 80)

# Create Spark session in local mode
print("\n1. Creating Spark session in local mode...")
spark = SparkSession.builder \
    .appName("IcebergLocalTest") \
    .master("local[2]") \
    .getOrCreate()

print(f"   - Spark version: {spark.version}")
print(f"   - Master: {spark.sparkContext.master}")

# Generate simple test data
print("\n2. Generating test data...")
schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("value", DecimalType(10, 2), False),
    StructField("timestamp", TimestampType(), False)
])

data = [
    (1, "test1", Decimal("10.50"), datetime.now()),
    (2, "test2", Decimal("20.75"), datetime.now()),
    (3, "test3", Decimal("30.25"), datetime.now())
]

df = spark.createDataFrame(data, schema)
print(f"   - Generated {df.count()} records")
df.show()

# Try to create Iceberg table
print("\n3. Creating Iceberg namespace and table...")
try:
    spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.test_local")
    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.test_local.simple_test (
            id INT,
            name STRING,
            value DECIMAL(10,2),
            timestamp TIMESTAMP
        ) USING iceberg
    """)
    print("   ✓ Table created successfully")
    
    # Write data
    print("\n4. Writing data to Iceberg table...")
    df.writeTo("iceberg.test_local.simple_test").append()
    print("   ✓ Data written successfully")
    
    # Read back
    print("\n5. Reading data back...")
    result = spark.table("iceberg.test_local.simple_test")
    print(f"   - Read {result.count()} records")
    result.show()
    
    print("\n" + "=" * 80)
    print("✓ TEST PASSED")
    print("=" * 80)
    sys.exit(0)
    
except Exception as e:
    print(f"\n✗ TEST FAILED: {str(e)}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
finally:
    spark.stop()
