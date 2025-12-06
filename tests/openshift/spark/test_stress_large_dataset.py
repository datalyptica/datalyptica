#!/usr/bin/env python3
"""
Spark Stress Test - Large Dataset Processing
Generates and processes millions of records to test cluster performance
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, rand, randn, expr, lit, 
    sum as _sum, avg, count, max as _max, min as _min,
    window, row_number, dense_rank
)
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, TimestampType
import time

def main():
    print("="*80)
    print("SPARK STRESS TEST - LARGE DATASET PROCESSING")
    print("="*80)
    
    # Create Spark session
    spark = SparkSession.builder \
        .appName("Spark-Stress-Test-Large-Dataset") \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    
    # Configuration
    NUM_RECORDS = 10_000_000  # 10 million records
    NUM_PARTITIONS = 100
    
    print(f"\n1. Dataset Configuration:")
    print(f"   - Total Records: {NUM_RECORDS:,}")
    print(f"   - Partitions: {NUM_PARTITIONS}")
    print(f"   - Estimated Size: ~{NUM_RECORDS * 100 / 1024 / 1024:.1f} MB")
    
    # Generate large dataset
    print(f"\n2. Generating {NUM_RECORDS:,} records...")
    start_time = time.time()
    
    df = spark.range(0, NUM_RECORDS, numPartitions=NUM_PARTITIONS) \
        .withColumn("transaction_id", expr("concat('TXN-', lpad(id, 10, '0'))")) \
        .withColumn("customer_id", expr("concat('CUST-', lpad(cast(rand() * 1000000 as int), 8, '0'))")) \
        .withColumn("product_id", expr("concat('PROD-', lpad(cast(rand() * 50000 as int), 6, '0'))")) \
        .withColumn("category", expr("case when rand() < 0.2 then 'Electronics' " +
                                      "when rand() < 0.4 then 'Clothing' " +
                                      "when rand() < 0.6 then 'Food' " +
                                      "when rand() < 0.8 then 'Home' " +
                                      "else 'Sports' end")) \
        .withColumn("quantity", expr("cast(rand() * 10 + 1 as int)")) \
        .withColumn("unit_price", expr("round(rand() * 1000 + 10, 2)")) \
        .withColumn("total_amount", col("quantity") * col("unit_price")) \
        .withColumn("discount_pct", expr("round(rand() * 30, 2)")) \
        .withColumn("final_amount", col("total_amount") * (1 - col("discount_pct") / 100)) \
        .withColumn("region", expr("case when rand() < 0.25 then 'US-EAST' " +
                                    "when rand() < 0.5 then 'US-WEST' " +
                                    "when rand() < 0.75 then 'EU-CENTRAL' " +
                                    "else 'ASIA-PACIFIC' end")) \
        .withColumn("payment_method", expr("case when rand() < 0.4 then 'Credit Card' " +
                                            "when rand() < 0.7 then 'Debit Card' " +
                                            "when rand() < 0.9 then 'PayPal' " +
                                            "else 'Bank Transfer' end")) \
        .withColumn("timestamp", expr("timestamp(date_sub(current_date(), cast(rand() * 365 as int)))")) \
        .withColumn("customer_age", expr("cast(rand() * 60 + 18 as int)")) \
        .withColumn("customer_segment", expr("case when customer_age < 25 then 'Young Adult' " +
                                              "when customer_age < 40 then 'Adult' " +
                                              "when customer_age < 60 then 'Middle Age' " +
                                              "else 'Senior' end")) \
        .drop("id")
    
    # Force execution and count
    record_count = df.count()
    generation_time = time.time() - start_time
    
    print(f"   ✓ Generated {record_count:,} records in {generation_time:.2f}s")
    print(f"   ✓ Throughput: {record_count / generation_time:,.0f} records/sec")
    
    # Cache for reuse in multiple operations
    df.cache()
    
    # Test 1: Aggregation by multiple dimensions
    print(f"\n3. Test 1: Multi-dimensional Aggregation")
    start_time = time.time()
    
    agg_result = df.groupBy("region", "category", "payment_method") \
        .agg(
            count("*").alias("transaction_count"),
            _sum("final_amount").alias("total_revenue"),
            avg("final_amount").alias("avg_transaction"),
            _max("final_amount").alias("max_transaction"),
            _min("final_amount").alias("min_transaction"),
            avg("discount_pct").alias("avg_discount")
        ) \
        .orderBy(col("total_revenue").desc())
    
    agg_count = agg_result.count()
    agg_time = time.time() - start_time
    
    print(f"   ✓ Processed {agg_count} aggregate groups in {agg_time:.2f}s")
    print(f"   ✓ Top 5 Revenue Groups:")
    agg_result.show(5, truncate=False)
    
    # Test 2: Complex filtering and computation
    print(f"\n4. Test 2: Complex Filtering & Computation")
    start_time = time.time()
    
    filtered_df = df.filter(
        (col("final_amount") > 500) &
        (col("discount_pct") > 10) &
        (col("customer_age") < 40)
    ).withColumn(
        "roi_score",
        (col("final_amount") * col("discount_pct")) / 100
    )
    
    filtered_count = filtered_df.count()
    filtered_time = time.time() - start_time
    
    print(f"   ✓ Filtered to {filtered_count:,} records ({filtered_count/record_count*100:.1f}%) in {filtered_time:.2f}s")
    print(f"   ✓ Filter throughput: {record_count / filtered_time:,.0f} records/sec")
    
    # Test 3: Join operation (self-join simulation)
    print(f"\n5. Test 3: Join Operations")
    start_time = time.time()
    
    # Create customer summary
    customer_summary = df.groupBy("customer_id") \
        .agg(
            count("*").alias("purchase_count"),
            _sum("final_amount").alias("total_spent"),
            avg("final_amount").alias("avg_order_value")
        )
    
    # Join back to original data
    enriched_df = df.join(customer_summary, "customer_id", "left") \
        .withColumn("customer_value_segment", 
                    expr("case when total_spent > 50000 then 'VIP' " +
                         "when total_spent > 20000 then 'Premium' " +
                         "when total_spent > 5000 then 'Regular' " +
                         "else 'New' end"))
    
    join_count = enriched_df.count()
    join_time = time.time() - start_time
    
    print(f"   ✓ Joined {join_count:,} records in {join_time:.2f}s")
    print(f"   ✓ Join throughput: {join_count / join_time:,.0f} records/sec")
    
    # Test 4: Window functions (ranking)
    print(f"\n6. Test 4: Window Functions & Ranking")
    start_time = time.time()
    
    from pyspark.sql.window import Window
    
    window_spec = Window.partitionBy("region", "category").orderBy(col("final_amount").desc())
    
    ranked_df = df.withColumn("rank_in_category", row_number().over(window_spec)) \
        .filter(col("rank_in_category") <= 10)
    
    ranked_count = ranked_df.count()
    window_time = time.time() - start_time
    
    print(f"   ✓ Computed window functions for {ranked_count:,} top records in {window_time:.2f}s")
    print(f"   ✓ Sample top transactions by region/category:")
    ranked_df.select("region", "category", "product_id", "final_amount", "rank_in_category") \
        .show(10, truncate=False)
    
    # Test 5: Write to Iceberg
    print(f"\n7. Test 5: Write to Iceberg (Stress Test)")
    start_time = time.time()
    
    # Drop existing table if exists
    spark.sql("DROP TABLE IF EXISTS iceberg.test_db.stress_test_large")
    
    # Write with partitioning
    df.writeTo("iceberg.test_db.stress_test_large") \
        .partitionedBy("region") \
        .createOrReplace()
    
    write_time = time.time() - start_time
    
    print(f"   ✓ Wrote {record_count:,} records to Iceberg in {write_time:.2f}s")
    print(f"   ✓ Write throughput: {record_count / write_time:,.0f} records/sec")
    print(f"   ✓ Write speed: {record_count * 100 / 1024 / 1024 / write_time:.2f} MB/s")
    
    # Test 6: Read back and verify
    print(f"\n8. Test 6: Read Back & Verify")
    start_time = time.time()
    
    read_df = spark.table("iceberg.test_db.stress_test_large")
    read_count = read_df.count()
    read_time = time.time() - start_time
    
    print(f"   ✓ Read {read_count:,} records from Iceberg in {read_time:.2f}s")
    print(f"   ✓ Read throughput: {read_count / read_time:,.0f} records/sec")
    
    # Verify data integrity
    source_sum = df.agg(_sum("final_amount")).collect()[0][0]
    read_sum = read_df.agg(_sum("final_amount")).collect()[0][0]
    
    if abs(source_sum - read_sum) < 0.01:
        print(f"   ✓ Data integrity verified (sum match: ${source_sum:,.2f})")
    else:
        print(f"   ✗ Data integrity check FAILED!")
        print(f"     Source sum: ${source_sum:,.2f}")
        print(f"     Read sum: ${read_sum:,.2f}")
    
    # Performance Summary
    total_time = generation_time + agg_time + filtered_time + join_time + window_time + write_time + read_time
    
    print(f"\n{'='*80}")
    print(f"PERFORMANCE SUMMARY")
    print(f"{'='*80}")
    print(f"Dataset Size:          {record_count:,} records")
    print(f"Generation Time:       {generation_time:.2f}s")
    print(f"Aggregation Time:      {agg_time:.2f}s")
    print(f"Filtering Time:        {filtered_time:.2f}s")
    print(f"Join Time:             {join_time:.2f}s")
    print(f"Window Functions:      {window_time:.2f}s")
    print(f"Iceberg Write:         {write_time:.2f}s")
    print(f"Iceberg Read:          {read_time:.2f}s")
    print(f"{'='*80}")
    print(f"Total Processing Time: {total_time:.2f}s")
    print(f"Overall Throughput:    {record_count / total_time:,.0f} records/sec")
    print(f"{'='*80}")
    
    # Cleanup
    df.unpersist()
    spark.stop()
    
    print(f"\n✓ STRESS TEST COMPLETED SUCCESSFULLY")

if __name__ == "__main__":
    main()
