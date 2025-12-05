# OpenShift Integration Tests

End-to-end integration tests for Datalyptica platform deployed on OpenShift.

## Test Structure

- `spark/` - Spark batch processing tests
- `flink/` - Flink streaming tests
- `trino/` - Trino query tests
- `e2e/` - End-to-end integration scenarios

## Prerequisites

- OpenShift CLI (`oc`) configured
- Access to `datalyptica` namespace
- MinIO credentials configured
- Nessie catalog accessible

## Running Tests

```bash
# Run all OpenShift integration tests
bash run-openshift-tests.sh

# Run specific test
python spark/test_iceberg_write.py
python flink/test_streaming_cdc.py
python trino/test_query_iceberg.py
```

## Test Scenarios

### 1. Spark Batch Processing
- Write sales data to Iceberg table via Nessie catalog
- Partition by date
- Verify data written to MinIO

### 2. Flink Streaming
- Stream events to Iceberg table
- Real-time CDC processing
- Time-windowed aggregations

### 3. Trino Queries
- Query Iceberg tables via Nessie
- Join across tables
- Time travel queries

### 4. End-to-End Flow
1. Spark writes initial batch data
2. Flink streams incremental updates
3. Trino queries unified view
