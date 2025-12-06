#!/usr/bin/env python3
"""
Spark AGGRESSIVE Stress Test - Maximum Performance Testing
Tests cluster limits with 50M records, complex transformations, and concurrent operations
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, rand, randn, expr, lit, when, 
    sum as _sum, avg, count, max as _max, min as _min, stddev,
    window, row_number, dense_rank, lag, lead,
    concat, lower, upper, substring, length,
    year, month, dayofmonth, hour, date_add, datediff,
    collect_list, explode, array, struct
)
from pyspark.sql.window import Window
from pyspark.sql.types import *
import time

def main():
    print("="*80)
    print("SPARK AGGRESSIVE STRESS TEST - MAXIMUM PERFORMANCE")
    print("="*80)
    
    # Create Spark session with aggressive settings
    spark = SparkSession.builder \
        .appName("Spark-Aggressive-Stress-Test") \
        .config("spark.sql.shuffle.partitions", "200") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.default.parallelism", "100") \
        .getOrCreate()
    
    spark.sparkContext.setLogLevel("WARN")
    
    # AGGRESSIVE Configuration
    NUM_RECORDS = 50_000_000  # 50 MILLION records
    NUM_PARTITIONS = 200
    
    print(f"\n🔥 AGGRESSIVE TEST CONFIGURATION:")
    print(f"   - Total Records: {NUM_RECORDS:,}")
    print(f"   - Partitions: {NUM_PARTITIONS}")
    print(f"   - Estimated Size: ~{NUM_RECORDS * 100 / 1024 / 1024:.1f} MB ({NUM_RECORDS * 100 / 1024 / 1024 / 1024:.2f} GB)")
    print(f"   - Executors: 5 x 2 cores = 10 cores total")
    print(f"   - Expected Memory Usage: ~10 GB")
    
    overall_start = time.time()
    
    # =========================================================================
    # TEST 1: MASSIVE DATA GENERATION WITH COMPLEX SCHEMA
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 1: MASSIVE DATA GENERATION")
    print(f"{'='*80}")
    start_time = time.time()
    
    df = spark.range(0, NUM_RECORDS, numPartitions=NUM_PARTITIONS) \
        .withColumn("transaction_id", expr("concat('TXN-', lpad(id, 12, '0'))")) \
        .withColumn("customer_id", expr("concat('CUST-', lpad(cast(rand() * 5000000 as int), 8, '0'))")) \
        .withColumn("product_id", expr("concat('PROD-', lpad(cast(rand() * 100000 as int), 6, '0'))")) \
        .withColumn("merchant_id", expr("concat('MERCH-', lpad(cast(rand() * 10000 as int), 5, '0'))")) \
        .withColumn("category", expr("""
            case when rand() < 0.15 then 'Electronics'
                 when rand() < 0.30 then 'Clothing'
                 when rand() < 0.45 then 'Food & Beverage'
                 when rand() < 0.60 then 'Home & Garden'
                 when rand() < 0.75 then 'Sports & Outdoors'
                 when rand() < 0.85 then 'Health & Beauty'
                 when rand() < 0.92 then 'Automotive'
                 else 'Books & Media' end
        """)) \
        .withColumn("subcategory", expr("concat(category, '-', cast(rand() * 20 as int))")) \
        .withColumn("quantity", expr("cast(rand() * 20 + 1 as int)")) \
        .withColumn("unit_price", expr("round(rand() * 2000 + 5, 2)")) \
        .withColumn("total_amount", col("quantity") * col("unit_price")) \
        .withColumn("discount_pct", expr("round(rand() * 40, 2)")) \
        .withColumn("tax_rate", expr("round(rand() * 0.15, 4)")) \
        .withColumn("final_amount", col("total_amount") * (1 - col("discount_pct") / 100) * (1 + col("tax_rate"))) \
        .withColumn("region", expr("""
            case when rand() < 0.20 then 'US-EAST'
                 when rand() < 0.40 then 'US-WEST'
                 when rand() < 0.55 then 'EU-CENTRAL'
                 when rand() < 0.70 then 'EU-WEST'
                 when rand() < 0.82 then 'ASIA-PACIFIC'
                 when rand() < 0.92 then 'MIDDLE-EAST'
                 else 'LATAM' end
        """)) \
        .withColumn("country", expr("""
            case when region = 'US-EAST' then case when rand() < 0.5 then 'USA' else 'Canada' end
                 when region = 'US-WEST' then 'USA'
                 when region = 'EU-CENTRAL' then case when rand() < 0.4 then 'Germany' when rand() < 0.7 then 'France' else 'Italy' end
                 when region = 'EU-WEST' then case when rand() < 0.6 then 'UK' else 'Spain' end
                 when region = 'ASIA-PACIFIC' then case when rand() < 0.3 then 'China' when rand() < 0.6 then 'Japan' else 'India' end
                 when region = 'MIDDLE-EAST' then case when rand() < 0.5 then 'UAE' else 'Saudi Arabia' end
                 else 'Brazil' end
        """)) \
        .withColumn("payment_method", expr("""
            case when rand() < 0.35 then 'Credit Card'
                 when rand() < 0.65 then 'Debit Card'
                 when rand() < 0.85 then 'PayPal'
                 when rand() < 0.95 then 'Bank Transfer'
                 else 'Crypto' end
        """)) \
        .withColumn("payment_status", expr("""
            case when rand() < 0.85 then 'Completed'
                 when rand() < 0.93 then 'Pending'
                 when rand() < 0.97 then 'Failed'
                 else 'Refunded' end
        """)) \
        .withColumn("timestamp", expr("timestamp(date_sub(current_timestamp(), cast(rand() * 730 as int)))")) \
        .withColumn("hour_of_day", hour(col("timestamp"))) \
        .withColumn("day_of_week", expr("dayofweek(timestamp)")) \
        .withColumn("is_weekend", expr("dayofweek(timestamp) in (1, 7)")) \
        .withColumn("customer_age", expr("cast(rand() * 70 + 18 as int)")) \
        .withColumn("customer_segment", expr("""
            case when customer_age < 25 then 'Gen-Z'
                 when customer_age < 40 then 'Millennial'
                 when customer_age < 55 then 'Gen-X'
                 else 'Baby Boomer' end
        """)) \
        .withColumn("customer_lifetime_orders", expr("cast(rand() * 100 + 1 as int)")) \
        .withColumn("is_new_customer", col("customer_lifetime_orders") <= 3) \
        .withColumn("shipping_cost", expr("round(rand() * 50 + 5, 2)")) \
        .withColumn("is_express_shipping", expr("rand() < 0.3")) \
        .withColumn("device_type", expr("""
            case when rand() < 0.50 then 'Mobile'
                 when rand() < 0.80 then 'Desktop'
                 else 'Tablet' end
        """)) \
        .withColumn("session_duration_mins", expr("cast(rand() * 60 + 1 as int)")) \
        .withColumn("fraud_score", expr("round(rand() * 100, 2)")) \
        .withColumn("is_high_risk", col("fraud_score") > 75) \
        .drop("id")
    
    # Force materialization and count
    record_count = df.count()
    generation_time = time.time() - start_time
    
    print(f"✓ Generated {record_count:,} records in {generation_time:.2f}s")
    print(f"✓ Throughput: {record_count / generation_time:,.0f} records/sec")
    print(f"✓ Data generation rate: {record_count * 100 / 1024 / 1024 / generation_time:.2f} MB/s")
    
    # Cache for reuse
    df.cache()
    df.count()  # Force caching
    
    # =========================================================================
    # TEST 2: EXTREME MULTI-DIMENSIONAL AGGREGATION
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 2: EXTREME MULTI-DIMENSIONAL AGGREGATION")
    print(f"{'='*80}")
    start_time = time.time()
    
    agg_result = df.groupBy("region", "country", "category", "payment_method", "payment_status", "customer_segment") \
        .agg(
            count("*").alias("transaction_count"),
            _sum("final_amount").alias("total_revenue"),
            avg("final_amount").alias("avg_transaction"),
            _max("final_amount").alias("max_transaction"),
            _min("final_amount").alias("min_transaction"),
            stddev("final_amount").alias("stddev_transaction"),
            avg("discount_pct").alias("avg_discount"),
            avg("fraud_score").alias("avg_fraud_score"),
            _sum(when(col("is_high_risk"), 1).otherwise(0)).alias("high_risk_count"),
            avg("session_duration_mins").alias("avg_session_duration")
        ) \
        .filter(col("transaction_count") > 10) \
        .orderBy(col("total_revenue").desc())
    
    agg_count = agg_result.count()
    agg_time = time.time() - start_time
    
    print(f"✓ Processed {agg_count:,} aggregate groups in {agg_time:.2f}s")
    print(f"✓ Aggregation throughput: {record_count / agg_time:,.0f} records/sec")
    print(f"✓ Top 5 Revenue Segments:")
    agg_result.show(5, truncate=False)
    
    # =========================================================================
    # TEST 3: COMPLEX MULTI-CONDITION FILTERING
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 3: COMPLEX MULTI-CONDITION FILTERING")
    print(f"{'='*80}")
    start_time = time.time()
    
    complex_filter = df.filter(
        (
            ((col("final_amount") > 1000) & (col("discount_pct") > 15)) |
            ((col("customer_lifetime_orders") > 50) & (col("is_new_customer") == False))
        ) &
        (col("payment_status") == "Completed") &
        (col("fraud_score") < 50) &
        (col("customer_age").between(25, 55))
    ).withColumn(
        "customer_value_score",
        (col("final_amount") * col("customer_lifetime_orders") / 100)
    ).withColumn(
        "profitability_index",
        ((col("final_amount") - col("shipping_cost")) / col("final_amount")) * 100
    )
    
    filtered_count = complex_filter.count()
    filter_time = time.time() - start_time
    
    print(f"✓ Filtered to {filtered_count:,} records ({filtered_count/record_count*100:.2f}%) in {filter_time:.2f}s")
    print(f"✓ Filter throughput: {record_count / filter_time:,.0f} records/sec")
    
    # =========================================================================
    # TEST 4: MASSIVE JOIN OPERATIONS (3-WAY JOIN)
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 4: MASSIVE 3-WAY JOIN OPERATIONS")
    print(f"{'='*80}")
    start_time = time.time()
    
    # Create customer aggregation
    customer_agg = df.groupBy("customer_id") \
        .agg(
            count("*").alias("total_purchases"),
            _sum("final_amount").alias("total_spent"),
            avg("final_amount").alias("avg_order_value"),
            _max("final_amount").alias("max_purchase"),
            avg("fraud_score").alias("customer_fraud_score")
        )
    
    # Create merchant aggregation
    merchant_agg = df.groupBy("merchant_id") \
        .agg(
            count("*").alias("merchant_transactions"),
            _sum("final_amount").alias("merchant_revenue"),
            avg("fraud_score").alias("merchant_risk_score")
        )
    
    # Create product aggregation
    product_agg = df.groupBy("product_id", "category") \
        .agg(
            count("*").alias("product_sales"),
            _sum("quantity").alias("total_quantity_sold"),
            avg("unit_price").alias("avg_price")
        )
    
    # Perform 3-way join
    enriched_df = df \
        .join(customer_agg, "customer_id", "left") \
        .join(merchant_agg, "merchant_id", "left") \
        .join(product_agg, ["product_id", "category"], "left") \
        .withColumn("customer_tier", 
            when(col("total_spent") > 100000, "Platinum")
            .when(col("total_spent") > 50000, "Gold")
            .when(col("total_spent") > 20000, "Silver")
            .otherwise("Bronze")
        ) \
        .withColumn("merchant_quality",
            when(col("merchant_revenue") > 10000000, "Premium")
            .when(col("merchant_revenue") > 5000000, "Standard")
            .otherwise("Basic")
        )
    
    join_count = enriched_df.count()
    join_time = time.time() - start_time
    
    print(f"✓ Completed 3-way join on {join_count:,} records in {join_time:.2f}s")
    print(f"✓ Join throughput: {join_count / join_time:,.0f} records/sec")
    
    # =========================================================================
    # TEST 5: ADVANCED WINDOW FUNCTIONS (RANKING, LAG, LEAD)
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 5: ADVANCED WINDOW FUNCTIONS")
    print(f"{'='*80}")
    start_time = time.time()
    
    # Define multiple windows
    customer_window = Window.partitionBy("customer_id").orderBy(col("timestamp").desc())
    region_category_window = Window.partitionBy("region", "category").orderBy(col("final_amount").desc())
    time_window = Window.partitionBy("region").orderBy(col("timestamp"))
    
    windowed_df = df \
        .withColumn("customer_purchase_rank", row_number().over(customer_window)) \
        .withColumn("prev_purchase_amount", lag("final_amount", 1).over(customer_window)) \
        .withColumn("next_purchase_amount", lead("final_amount", 1).over(customer_window)) \
        .withColumn("category_rank", dense_rank().over(region_category_window)) \
        .withColumn("cumulative_revenue", _sum("final_amount").over(time_window)) \
        .filter(
            (col("customer_purchase_rank") <= 10) |
            (col("category_rank") <= 5)
        )
    
    window_count = windowed_df.count()
    window_time = time.time() - start_time
    
    print(f"✓ Applied window functions on {window_count:,} records in {window_time:.2f}s")
    print(f"✓ Window operations throughput: {record_count / window_time:,.0f} input records/sec")
    print(f"✓ Sample windowed data:")
    windowed_df.select("customer_id", "transaction_id", "final_amount", "customer_purchase_rank", 
                       "prev_purchase_amount", "category_rank").show(10, truncate=False)
    
    # =========================================================================
    # TEST 6: MASSIVE WRITE TO ICEBERG (PARTITIONED)
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 6: MASSIVE WRITE TO ICEBERG (PARTITIONED)")
    print(f"{'='*80}")
    start_time = time.time()
    
    # Drop table if exists
    spark.sql("DROP TABLE IF EXISTS iceberg.test_db.stress_test_aggressive")
    
    # Add date partition column
    df_with_date = df.withColumn("transaction_date", expr("date(timestamp)"))
    
    # Write with multi-level partitioning
    df_with_date.writeTo("iceberg.test_db.stress_test_aggressive") \
        .partitionedBy("region", "transaction_date") \
        .createOrReplace()
    
    write_time = time.time() - start_time
    write_throughput = record_count / write_time
    write_speed_mb = record_count * 100 / 1024 / 1024 / write_time
    
    print(f"✓ Wrote {record_count:,} records to Iceberg in {write_time:.2f}s")
    print(f"✓ Write throughput: {write_throughput:,.0f} records/sec")
    print(f"✓ Write speed: {write_speed_mb:.2f} MB/s")
    
    # =========================================================================
    # TEST 7: CONCURRENT READ WITH PREDICATE PUSHDOWN
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 7: CONCURRENT READ WITH PREDICATE PUSHDOWN")
    print(f"{'='*80}")
    start_time = time.time()
    
    # Read with filters (predicate pushdown)
    read_df = spark.table("iceberg.test_db.stress_test_aggressive") \
        .filter(
            (col("region").isin("US-EAST", "US-WEST", "EU-CENTRAL")) &
            (col("payment_status") == "Completed") &
            (col("final_amount") > 500)
        )
    
    read_count = read_df.count()
    read_time = time.time() - start_time
    
    print(f"✓ Read {read_count:,} records from Iceberg in {read_time:.2f}s")
    print(f"✓ Read throughput: {read_count / read_time:,.0f} records/sec")
    print(f"✓ Partition pruning effectiveness: {(1 - read_count/record_count)*100:.1f}% of data skipped")
    
    # =========================================================================
    # TEST 8: COMPLEX ANALYTICAL QUERY
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 8: COMPLEX ANALYTICAL QUERY")
    print(f"{'='*80}")
    start_time = time.time()
    
    analytical_result = spark.sql("""
        SELECT 
            region,
            category,
            customer_segment,
            payment_method,
            COUNT(*) as total_transactions,
            SUM(final_amount) as total_revenue,
            AVG(final_amount) as avg_transaction,
            PERCENTILE_APPROX(final_amount, 0.50) as median_transaction,
            PERCENTILE_APPROX(final_amount, 0.95) as p95_transaction,
            SUM(CASE WHEN is_high_risk THEN 1 ELSE 0 END) as high_risk_count,
            AVG(discount_pct) as avg_discount,
            SUM(CASE WHEN is_weekend THEN final_amount ELSE 0 END) as weekend_revenue,
            SUM(CASE WHEN NOT is_weekend THEN final_amount ELSE 0 END) as weekday_revenue,
            COUNT(DISTINCT customer_id) as unique_customers,
            COUNT(DISTINCT product_id) as unique_products
        FROM iceberg.test_db.stress_test_aggressive
        WHERE payment_status = 'Completed'
            AND final_amount > 100
        GROUP BY region, category, customer_segment, payment_method
        HAVING COUNT(*) > 100
        ORDER BY total_revenue DESC
        LIMIT 20
    """)
    
    analytical_result.show(10, truncate=False)
    analytical_time = time.time() - start_time
    
    print(f"✓ Complex analytical query completed in {analytical_time:.2f}s")
    
    # =========================================================================
    # TEST 9: DATA INTEGRITY VERIFICATION
    # =========================================================================
    print(f"\n{'='*80}")
    print(f"TEST 9: DATA INTEGRITY VERIFICATION")
    print(f"{'='*80}")
    start_time = time.time()
    
    # Verify counts
    source_count = df.count()
    iceberg_count = spark.table("iceberg.test_db.stress_test_aggressive").count()
    
    # Verify sums
    source_sum = df.agg(_sum("final_amount")).collect()[0][0]
    iceberg_sum = spark.table("iceberg.test_db.stress_test_aggressive").agg(_sum("final_amount")).collect()[0][0]
    
    # Verify distinct values
    source_customers = df.select("customer_id").distinct().count()
    iceberg_customers = spark.table("iceberg.test_db.stress_test_aggressive").select("customer_id").distinct().count()
    
    verification_time = time.time() - start_time
    
    print(f"✓ Record count match: {source_count:,} == {iceberg_count:,} : {'✓ PASS' if source_count == iceberg_count else '✗ FAIL'}")
    print(f"✓ Revenue sum match: ${source_sum:,.2f} == ${iceberg_sum:,.2f} : {'✓ PASS' if abs(source_sum - iceberg_sum) < 0.01 else '✗ FAIL'}")
    print(f"✓ Unique customers match: {source_customers:,} == {iceberg_customers:,} : {'✓ PASS' if source_customers == iceberg_customers else '✗ FAIL'}")
    print(f"✓ Verification completed in {verification_time:.2f}s")
    
    # =========================================================================
    # FINAL SUMMARY
    # =========================================================================
    total_time = time.time() - overall_start
    
    print(f"\n{'='*80}")
    print(f"🔥 AGGRESSIVE STRESS TEST - FINAL SUMMARY 🔥")
    print(f"{'='*80}")
    print(f"Dataset Size:               {record_count:,} records (~{record_count * 100 / 1024 / 1024 / 1024:.2f} GB)")
    print(f"Total Execution Time:       {total_time:.2f}s ({total_time/60:.2f} minutes)")
    print(f"---")
    print(f"Generation Time:            {generation_time:.2f}s ({record_count/generation_time:,.0f} rec/s)")
    print(f"Aggregation Time:           {agg_time:.2f}s ({record_count/agg_time:,.0f} rec/s)")
    print(f"Filtering Time:             {filter_time:.2f}s ({record_count/filter_time:,.0f} rec/s)")
    print(f"3-Way Join Time:            {join_time:.2f}s ({join_count/join_time:,.0f} rec/s)")
    print(f"Window Functions Time:      {window_time:.2f}s")
    print(f"Iceberg Write Time:         {write_time:.2f}s ({write_throughput:,.0f} rec/s, {write_speed_mb:.2f} MB/s)")
    print(f"Iceberg Read Time:          {read_time:.2f}s ({read_count/read_time:,.0f} rec/s)")
    print(f"Analytical Query Time:      {analytical_time:.2f}s")
    print(f"Verification Time:          {verification_time:.2f}s")
    print(f"{'='*80}")
    print(f"Overall Processing Rate:    {record_count / total_time:,.0f} records/sec")
    print(f"Data Throughput:            {record_count * 100 / 1024 / 1024 / total_time:.2f} MB/s")
    print(f"{'='*80}")
    
    # Get table metadata
    print(f"\n📊 Iceberg Table Metadata:")
    spark.sql("DESCRIBE EXTENDED iceberg.test_db.stress_test_aggressive").filter(
        col("col_name").isin("Provider", "Location", "Partitioned by")
    ).show(truncate=False)
    
    # Show partition stats
    print(f"\n📂 Partition Statistics:")
    partition_stats = spark.sql("""
        SELECT region, COUNT(*) as record_count, 
               SUM(final_amount) as total_revenue
        FROM iceberg.test_db.stress_test_aggressive
        GROUP BY region
        ORDER BY record_count DESC
    """)
    partition_stats.show(truncate=False)
    
    # Cleanup
    df.unpersist()
    spark.stop()
    
    print(f"\n{'='*80}")
    print(f"✅ AGGRESSIVE STRESS TEST COMPLETED SUCCESSFULLY!")
    print(f"{'='*80}")

if __name__ == "__main__":
    main()
