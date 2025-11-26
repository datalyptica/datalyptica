# ShuDL Use Cases Test Guide

## Overview

This guide explains how to run and validate the comprehensive use case tests that demonstrate all 21 components of the ShuDL platform working together in real-world scenarios.

## Test Coverage

The use cases test suite (`tests/e2e/use-cases.e2e.test.sh`) validates 7 real-world scenarios with 28 individual test cases:

### Use Case 1: Real-Time CDC Pipeline for E-commerce Analytics (7 tests)

- PostgreSQL operational database setup
- Debezium CDC connector configuration
- Kafka event streaming
- Schema Registry Avro schema management
- Flink stream processing
- Iceberg lakehouse storage
- Trino interactive analytics

### Use Case 2: Large-Scale Batch Processing for Financial Reporting (4 tests)

- Apache Spark batch job setup
- Financial transaction data ingestion
- Aggregated reporting with Iceberg
- Time Travel queries for historical analysis

### Use Case 3: Interactive Data Exploration and BI (3 tests)

- Analytics schema creation
- Business-friendly view creation with dbt patterns
- BI metrics querying through Trino

### Use Case 4: Data Versioning and Reproducibility with Nessie (3 tests)

- Git-like branch creation
- Isolated experimentation on branches
- Branch management and listing

### Use Case 5: Real-Time Anomaly Detection (3 tests)

- Kafka topic for sensor data streams
- Real-time event production
- Anomaly detection results storage

### Use Case 6: Secure Data Access with Keycloak (2 tests)

- Keycloak authentication service verification
- Service integration with IAM

### Use Case 7: Platform Monitoring and Observability (4 tests)

- Prometheus metrics collection
- Grafana dashboard availability
- Loki log aggregation
- Overall service health monitoring

## Prerequisites

Before running the use case tests, ensure:

1. **All services are running**:

   ```bash
   cd docker
   docker compose up -d
   docker compose ps  # Verify all services are healthy
   ```

2. **Test helpers are available**:

   ```bash
   ls tests/helpers/test_helpers.sh  # Should exist
   ```

3. **Required ports are accessible**:
   - PostgreSQL: 5432
   - Kafka: 9092
   - Kafka Connect: 8083
   - Schema Registry: 8081
   - Trino: 8080
   - Nessie: 19120
   - Keycloak: 8180
   - Prometheus: 9090
   - Grafana: 3000
   - Loki: 3100

## Running the Tests

### Run All Use Case Tests

```bash
cd tests
./e2e/use-cases.e2e.test.sh
```

### Expected Output

```
==========================================
ShuDL Use Cases E2E Test Suite
==========================================
Testing 7 real-world use cases
Validating 21-component integration

==========================================
Use Case 1: Real-Time CDC Pipeline
==========================================
[2024-11-26 10:00:00] ℹ️  Running test 1: UC1.1: PostgreSQL orders table
[2024-11-26 10:00:02] ✅ Test 1: UC1.1: PostgreSQL orders table
[2024-11-26 10:00:02] ℹ️  Running test 2: UC1.2: Insert order data
[2024-11-26 10:00:04] ✅ Test 2: UC1.2: Insert order data
...

==========================================
Test Summary
==========================================
Total tests: 28
Passed: 28
Failed: 0
Success rate: 100.00%

Full log: tests/logs/use-cases-e2e-20241126-100000.log
==========================================
[2024-11-26 10:05:30] ✅ All use case tests passed! 🎉
```

### Test Duration

- **Full suite**: ~5-8 minutes (all 28 tests)
- **Per use case**: ~30-90 seconds

## Test Details

### Use Case 1: CDC Pipeline Test Flow

```
PostgreSQL (orders table)
    ↓ (Debezium captures changes)
Kafka (ecommerce.public.orders topic)
    ↓ (Avro serialization)
Schema Registry (schema management)
    ↓ (Flink processes stream)
Iceberg (orders_enriched table in S3/MinIO)
    ↓ (Nessie catalog)
Trino (interactive queries)
```

**Test validates**:

- Database change capture works
- CDC events flow through Kafka
- Schemas are registered properly
- Data lands in Iceberg with ACID guarantees
- Cross-engine access (Trino can read Spark-written data)

### Use Case 2: Batch Processing Test Flow

```
Raw Data (transactions)
    ↓ (Spark batch job)
Transformations (aggregations, calculations)
    ↓ (Iceberg commit)
Lakehouse Storage (daily_summary table)
    ↓ (Time Travel)
Historical Analysis
```

**Test validates**:

- Large-scale data transformations
- ACID transactions for batch loads
- Time Travel capabilities
- Atomic multi-table commits via Nessie

### Use Case 3: BI Layer Test Flow

```
Raw Lakehouse Data
    ↓ (dbt-style transformations)
Semantic Layer (views, aggregations)
    ↓ (Trino SQL)
Business Metrics
    ↓ (BI tools)
Dashboards & Reports
```

**Test validates**:

- View creation and management
- Business logic encapsulation
- Query performance for analytics
- Self-service data access

### Use Case 4: Data Versioning Test Flow

```
Main Branch (production data)
    ↓ (create branch)
Feature Branch (experimental changes)
    ↓ (isolated work)
Testing & Validation
    ↓ (merge or discard)
Production Ready or Rollback
```

**Test validates**:

- Git-like branching for data
- Isolated experimentation
- Multi-table atomic transactions
- Branch management through Nessie API

### Use Case 5: Anomaly Detection Test Flow

```
IoT Sensors
    ↓ (high-frequency data)
Kafka Topics (sensor-data)
    ↓ (Flink streaming)
Real-time Analysis (anomaly detection)
    ↓ (alerting)
Prometheus/Alertmanager
    ↓ (storage)
Iceberg (sensor_anomalies table)
```

**Test validates**:

- High-throughput streaming
- Real-time processing with Flink
- Alert generation
- Stream-to-lakehouse integration

### Use Case 6: Security Test Flow

```
User Request
    ↓ (authentication)
Keycloak (IAM)
    ↓ (JWT token)
Service (Trino, Spark, etc.)
    ↓ (authorization)
Data Access (role-based)
```

**Test validates**:

- Keycloak availability
- Service integration
- OAuth2/OIDC flow
- Centralized access control

### Use Case 7: Monitoring Test Flow

```
All Services (21 components)
    ↓ (metrics export)
Prometheus (metrics collection)
    ↓ (visualization)
Grafana (dashboards)
    ↓ (logs)
Loki (log aggregation)
    ↓ (alerting)
Alertmanager
```

**Test validates**:

- Metrics collection from all services
- Dashboard accessibility
- Log aggregation
- Health monitoring
- Alert configuration

## Troubleshooting

### Common Issues

#### 1. Service Not Ready

**Error**: `Failed to connect to service`

**Solution**:

```bash
# Check service health
docker compose ps

# Wait for all services to be healthy
docker compose ps | grep "healthy"

# Restart specific service if needed
docker compose restart <service-name>
```

#### 2. Debezium Connector Fails

**Error**: `Failed to configure Debezium connector`

**Solution**:

```bash
# Check Kafka Connect logs
docker logs docker-kafka-connect --tail 50

# Verify PostgreSQL is accessible
docker exec docker-postgresql psql -U postgres -c "SELECT 1"

# Delete and recreate connector
curl -X DELETE http://localhost:8083/connectors/orders-cdc-connector
# Re-run test
```

#### 3. Schema Registry Issues

**Error**: `Schema not found in Schema Registry`

**Solution**:

```bash
# Check Schema Registry
curl http://localhost:8081/subjects

# Verify Kafka Connect can reach Schema Registry
docker exec docker-kafka-connect curl http://schema-registry:8081/subjects
```

#### 4. Nessie Branch Creation Fails

**Error**: `Failed to create Nessie branch`

**Solution**:

```bash
# Check Nessie service
curl http://localhost:19120/api/v2/config

# List existing branches
curl http://localhost:19120/api/v2/trees

# Delete existing branch if conflict
curl -X DELETE http://localhost:19120/api/v2/trees/branch/feature-experiment
```

#### 5. Trino Query Timeout

**Error**: `Trino query failed`

**Solution**:

```bash
# Check Trino coordinator logs
docker logs docker-trino --tail 100

# Verify Trino can connect to Nessie
docker exec docker-trino curl http://nessie:19120/api/v1/config

# Check Iceberg catalog
docker exec docker-trino /opt/trino/bin/trino --execute "SHOW CATALOGS"
```

#### 6. Prometheus Metrics Not Available

**Error**: `Prometheus metrics collection failed`

**Solution**:

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify Prometheus configuration
docker exec docker-prometheus cat /etc/prometheus/prometheus.yml

# Restart Prometheus
docker compose restart prometheus
```

## Logs and Debugging

### Test Logs Location

```bash
# View latest test log
ls -lt tests/logs/use-cases-e2e-*.log | head -1

# Tail test log in real-time
tail -f tests/logs/use-cases-e2e-*.log
```

### Service Logs

```bash
# View specific service logs
docker logs docker-<service-name> --tail 100 -f

# View all service logs
docker compose logs --tail 50

# View logs for specific use case components
docker compose logs postgresql kafka kafka-connect schema-registry
```

### Debug Mode

To run tests with verbose output:

```bash
# Add set -x for bash debugging
cd tests/e2e
bash -x use-cases.e2e.test.sh
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Use Cases E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  use-cases-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start ShuDL services
        run: |
          cd docker
          docker compose up -d

      - name: Wait for services
        run: |
          sleep 60
          docker compose ps

      - name: Run use cases tests
        run: |
          cd tests
          ./e2e/use-cases.e2e.test.sh

      - name: Upload test logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-logs
          path: tests/logs/
```

## Performance Benchmarks

Expected test performance on standard hardware:

| Use Case               | Tests  | Duration    | Key Metrics           |
| ---------------------- | ------ | ----------- | --------------------- |
| UC1: CDC Pipeline      | 7      | 90s         | < 5s CDC latency      |
| UC2: Batch Processing  | 4      | 60s         | 1K rows/sec ingestion |
| UC3: Interactive BI    | 3      | 30s         | < 1s query response   |
| UC4: Versioning        | 3      | 20s         | < 500ms branch ops    |
| UC5: Anomaly Detection | 3      | 40s         | 100 events/sec        |
| UC6: Security          | 2      | 15s         | < 200ms auth          |
| UC7: Monitoring        | 4      | 30s         | All services healthy  |
| **Total**              | **28** | **5-8 min** | **100% pass rate**    |

## Next Steps

After running use case tests:

1. **Explore the data**:

   ```bash
   # Connect to Trino
   docker exec -it docker-trino /opt/trino/bin/trino

   # Query created tables
   SHOW SCHEMAS IN iceberg;
   SHOW TABLES IN iceberg.ecommerce;
   SELECT * FROM iceberg.ecommerce.orders_enriched LIMIT 10;
   ```

2. **View dashboards**:

   - Grafana: http://localhost:3000
   - Kafka UI: http://localhost:8080 (if enabled)
   - Trino UI: http://localhost:8080

3. **Experiment with features**:

   - Create your own Nessie branches
   - Build dbt models
   - Configure Flink jobs
   - Set up custom dashboards

4. **Run other test suites**:

   ```bash
   # Complete E2E suite
   ./run-e2e-suite.sh

   # Specific use cases
   ./e2e/cdc-pipeline.e2e.test.sh
   ./e2e/streaming-pipeline.e2e.test.sh
   ```

## Support

For issues or questions:

- Check logs: `tests/logs/use-cases-e2e-*.log`
- Review documentation: `docs/USE_CASES.md`
- See troubleshooting guide: `docs/operations/troubleshooting.md`
- Open an issue on GitHub

## Summary

The use cases test suite provides comprehensive validation that all 21 ShuDL components work together seamlessly in real-world scenarios. These tests demonstrate:

✅ **Real-time CDC pipelines** from operational databases to lakehouse  
✅ **Batch processing** with Spark and Iceberg  
✅ **Interactive analytics** with Trino and dbt  
✅ **Data versioning** with Git-like workflows  
✅ **Stream processing** for real-time insights  
✅ **Enterprise security** with centralized IAM  
✅ **Complete observability** across the platform

Run these tests regularly to ensure platform health and validate new features!
