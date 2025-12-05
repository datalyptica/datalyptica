#!/usr/bin/env python3
"""
Spark Integration Test - Write to Iceberg Table via Nessie Catalog
Tests: Spark → Nessie → Iceberg → MinIO
"""

import sys
from datetime import datetime, timedelta
from decimal import Decimal
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_timestamp
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DecimalType, TimestampType

def create_spark_session():
    """Get existing Spark session (inherits spark-defaults.conf)"""
    return SparkSession.builder \
        .appName("IcebergWriteTest") \
        .getOrCreate()

def test_iceberg_write():
    """Test writing data to Iceberg table via Nessie catalog"""
    
    print("=" * 80)
    print("SPARK INTEGRATION TEST: Iceberg Write via Nessie")
    print("=" * 80)
    
    # Create Spark session
    print("\n1. Creating Spark session...")
    spark = create_spark_session()
    
    # Display configuration
    print("\n2. Spark Configuration:")
    print(f"   - Catalog: {spark.conf.get('spark.sql.catalog.iceberg')}")
    print(f"   - Nessie URI: {spark.conf.get('spark.sql.catalog.iceberg.uri')}")
    print(f"   - Warehouse: {spark.conf.get('spark.sql.catalog.iceberg.warehouse')}")
    
    # Define schema
    schema = StructType([
        StructField("transaction_id", StringType(), False),
        StructField("customer_id", StringType(), False),
        StructField("product_id", StringType(), False),
        StructField("quantity", IntegerType(), False),
        StructField("price", DecimalType(10, 2), False),
        StructField("transaction_date", TimestampType(), False),
        StructField("region", StringType(), False)
    ])
    
    # Generate sample data
    print("\n3. Generating sample sales data...")
    base_date = datetime.now() - timedelta(days=7)
    
    data = []
    for i in range(1000):
        data.append((
            f"TXN-{i:06d}",
            f"CUST-{(i % 100):04d}",
            f"PROD-{(i % 50):03d}",
            (i % 10) + 1,
            Decimal(str(round((i % 100) + 10.0, 2))),
            base_date + timedelta(hours=i % 168),  # 7 days of data
            ["US-EAST", "US-WEST", "EU", "ASIA"][i % 4]
        ))
    
    df = spark.createDataFrame(data, schema)
    
    print(f"   - Generated {df.count()} transactions")
    print(f"   - Date range: {base_date.date()} to {datetime.now().date()}")
    
    # Show sample data
    print("\n4. Sample data (first 5 rows):")
    df.show(5, truncate=False)
    
    # Create database if not exists
    print("\n5. Creating Iceberg database...")
    spark.sql("CREATE DATABASE IF NOT EXISTS iceberg.test_db")
    spark.sql("USE iceberg.test_db")
    
    # Drop table if exists (for clean test)
    print("\n6. Dropping existing table (if any)...")
    spark.sql("DROP TABLE IF EXISTS iceberg.test_db.sales_transactions")
    
    # Write to Iceberg table partitioned by date
    print("\n7. Writing data to Iceberg table...")
    print("   - Table: iceberg.test_db.sales_transactions")
    print("   - Partitioning: By transaction_date (daily)")
    print("   - Format: Iceberg (Parquet)")
    
    df.writeTo("iceberg.test_db.sales_transactions") \
        .using("iceberg") \
        .partitionedBy("transaction_date") \
        .createOrReplace()
    
    # Verify write
    print("\n8. Verifying data write...")
    result_df = spark.table("iceberg.test_db.sales_transactions")
    record_count = result_df.count()
    
    print(f"   ✓ Records written: {record_count}")
    print(f"   ✓ Expected: {len(data)}")
    
    if record_count != len(data):
        print("   ✗ FAILED: Record count mismatch!")
        return False
    
    # Show statistics
    print("\n9. Table Statistics:")
    result_df.groupBy("region").count().show()
    
    # Show table metadata
    print("\n10. Table Metadata:")
    spark.sql("DESCRIBE EXTENDED iceberg.test_db.sales_transactions").show(truncate=False)
    
    # Test query with filter
    print("\n11. Testing query with filter (US-EAST region):")
    us_east_df = spark.sql("""
        SELECT region, COUNT(*) as transaction_count, SUM(price * quantity) as total_revenue
        FROM iceberg.test_db.sales_transactions
        WHERE region = 'US-EAST'
        GROUP BY region
    """)
    us_east_df.show()
    
    # Get Nessie commit info
    print("\n12. Nessie Catalog Info:")
    try:
        spark.sql("SHOW TABLES IN iceberg.test_db").show()
    except Exception as e:
        print(f"   Warning: Could not show tables: {e}")
    
    print("\n" + "=" * 80)
    print("✓ SPARK TEST COMPLETED SUCCESSFULLY")
    print("=" * 80)
    print("\nNext steps:")
    print("  1. Check MinIO bucket 'lakehouse' for Parquet files")
    print("  2. Verify Nessie catalog has table metadata")
    print("  3. Run Trino query test to read this data")
    
    spark.stop()
    return True

if __name__ == "__main__":
    try:
        success = test_iceberg_write()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
