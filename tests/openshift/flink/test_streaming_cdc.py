#!/usr/bin/env python3
"""
Flink Streaming Test - Real-time Event Processing to Iceberg
Tests: Flink → Iceberg CDC → Nessie → MinIO
"""

from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings
from pyflink.table.expressions import col
import time

def test_flink_streaming():
    """Test Flink streaming with Iceberg sink"""
    
    print("=" * 80)
    print("FLINK INTEGRATION TEST: Streaming to Iceberg")
    print("=" * 80)
    
    # Create execution environment
    print("\n1. Creating Flink execution environment...")
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(2)
    
    # Create table environment
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = StreamTableEnvironment.create(env, environment_settings=settings)
    
    print("   ✓ Environment created (streaming mode, parallelism=2)")
    
    # Configure Iceberg catalog
    print("\n2. Configuring Iceberg catalog...")
    t_env.execute_sql("""
        CREATE CATALOG iceberg WITH (
            'type' = 'iceberg',
            'catalog-impl' = 'org.apache.iceberg.nessie.NessieCatalog',
            'uri' = 'http://nessie.datalyptica.svc.cluster.local:19120/api/v2',
            'ref' = 'main',
            'warehouse' = 's3://lakehouse/',
            'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
            's3.endpoint' = 'http://minio.datalyptica.svc.cluster.local:9000',
            's3.path-style-access' = 'true'
        )
    """)
    
    t_env.execute_sql("USE CATALOG iceberg")
    t_env.execute_sql("CREATE DATABASE IF NOT EXISTS test_db")
    t_env.execute_sql("USE test_db")
    
    print("   ✓ Iceberg catalog configured")
    
    # Create source table (datagen connector for testing)
    print("\n3. Creating streaming source (event generator)...")
    t_env.execute_sql("""
        CREATE TABLE event_source (
            event_id STRING,
            user_id STRING,
            event_type STRING,
            event_value DOUBLE,
            event_time TIMESTAMP(3),
            WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
        ) WITH (
            'connector' = 'datagen',
            'rows-per-second' = '10',
            'fields.event_id.length' = '16',
            'fields.user_id.kind' = 'random',
            'fields.user_id.min' = '1',
            'fields.user_id.max' = '1000',
            'fields.event_type.length' = '1',
            'fields.event_value.min' = '0',
            'fields.event_value.max' = '1000'
        )
    """)
    
    print("   ✓ Event source created (10 events/sec)")
    
    # Create Iceberg sink table
    print("\n4. Creating Iceberg sink table...")
    t_env.execute_sql("""
        CREATE TABLE IF NOT EXISTS event_aggregations (
            window_start TIMESTAMP(3),
            window_end TIMESTAMP(3),
            event_type STRING,
            event_count BIGINT,
            total_value DOUBLE,
            avg_value DOUBLE,
            PRIMARY KEY (window_start, event_type) NOT ENFORCED
        ) WITH (
            'format-version' = '2',
            'write.upsert.enabled' = 'true'
        )
    """)
    
    print("   ✓ Iceberg sink table created")
    
    # Create windowed aggregation query
    print("\n5. Creating streaming aggregation pipeline...")
    print("   - Window: 1 minute tumbling")
    print("   - Aggregations: COUNT, SUM, AVG")
    print("   - Group by: event_type")
    
    aggregation_query = """
        INSERT INTO event_aggregations
        SELECT
            TUMBLE_START(event_time, INTERVAL '1' MINUTE) as window_start,
            TUMBLE_END(event_time, INTERVAL '1' MINUTE) as window_end,
            event_type,
            COUNT(*) as event_count,
            SUM(event_value) as total_value,
            AVG(event_value) as avg_value
        FROM event_source
        GROUP BY
            TUMBLE(event_time, INTERVAL '1' MINUTE),
            event_type
    """
    
    # Execute streaming job
    print("\n6. Starting Flink streaming job...")
    print("   ⚠ Job will run for 2 minutes to collect data...")
    print("   - Events will be aggregated per minute")
    print("   - Results written to Iceberg table")
    
    table_result = t_env.execute_sql(aggregation_query)
    
    # Wait for some data to be processed
    print("\n7. Waiting for data processing (120 seconds)...")
    time.sleep(120)
    
    # Query results
    print("\n8. Querying aggregated results...")
    result = t_env.execute_sql("SELECT * FROM event_aggregations ORDER BY window_start DESC LIMIT 10")
    
    print("\n   Recent aggregations:")
    result.print()
    
    # Get row count
    count_result = t_env.execute_sql("SELECT COUNT(*) as total_windows FROM event_aggregations")
    print("\n9. Total aggregation windows:")
    count_result.print()
    
    print("\n" + "=" * 80)
    print("✓ FLINK TEST COMPLETED")
    print("=" * 80)
    print("\nResults:")
    print("  - Streaming job processed events for 2 minutes")
    print("  - Aggregations written to iceberg.test_db.event_aggregations")
    print("  - Data can be queried via Trino")
    
    return True

if __name__ == "__main__":
    import sys
    try:
        success = test_flink_streaming()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
