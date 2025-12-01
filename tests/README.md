# Datalyptica Comprehensive Test Suite

## Overview

Comprehensive testing framework for all 21 components of the Datalyptica Data Lakehouse platform.

## Test Structure

```
tests/
├── run-tests.sh                              # Main test runner
├── comprehensive-test-all-21-components.sh   # Complete test suite
├── helpers/
│   └── test_helpers.sh                       # Common test utilities
├── health/
│   └── test-all-health.sh                    # Health checks for all 21 components
├── integration/
│   └── test-data-flow.sh                     # Integration tests
└── e2e/
    └── test-complete-pipeline.sh             # End-to-end pipeline tests
```

## All 21 Components Tested

### Storage Layer (3)

1. **MinIO** - S3-compatible object storage
2. **PostgreSQL** - Metadata store
3. **Nessie** - Data catalog with versioning

### Streaming Layer (4)

4. **Zookeeper** - Coordination service
5. **Kafka** - Message broker
6. **Schema Registry** - Schema management
7. **Kafka UI** - Management console

### Processing Layer (4)

8. **Spark Master** - Batch processing coordinator
9. **Spark Worker** - Batch execution
10. **Flink JobManager** - Stream processing coordinator
11. **Flink TaskManager** - Stream processing executor

### Query/Analytics Layer (4)

12. **Trino** - Distributed SQL query engine
13. **ClickHouse** - OLAP database
14. **dbt** - Data transformation tool
15. **Kafka Connect** - CDC and integration

### Observability Layer (6)

16. **Prometheus** - Metrics collection
17. **Grafana** - Visualization and dashboards
18. **Loki** - Log aggregation
19. **Alloy** - Log collection agent
20. **Alertmanager** - Alert routing
21. **Keycloak** - Identity and access management

## Running Tests

### Prerequisites

```bash
# Ensure all services are running
cd docker && docker compose up -d

# Install coreutils for timeout command (macOS)
brew install coreutils
```

### Quick Start

```bash
# Run all tests (comprehensive)
./tests/run-tests.sh full

# Run quick health checks only
./tests/run-tests.sh quick

# Run specific test suites
./tests/run-tests.sh health       # Health checks
./tests/run-tests.sh integration  # Integration tests
./tests/run-tests.sh e2e          # End-to-end tests
```

### Individual Test Execution

```bash
# Comprehensive test (all 21 components)
./tests/comprehensive-test-all-21-components.sh

# Health checks only
./tests/health/test-all-health.sh

# Integration tests
./tests/integration/test-data-flow.sh

# End-to-end pipeline test
./tests/e2e/test-complete-pipeline.sh
```

## Test Coverage

### Phase 1: Pre-Flight Checks

- Docker environment validation
- Docker Compose availability
- Project file verification
- Environment configuration check

### Phase 2: Component Health Checks (21 components)

- Service running status
- Container health status
- Basic connectivity tests

### Phase 3: Network Connectivity Tests

- HTTP endpoint availability
- Port accessibility
- API responsiveness
- Service-specific health checks

### Phase 4: Storage Layer Integration

- MinIO bucket operations
- PostgreSQL database queries
- Nessie catalog operations
- Cross-service communication

### Phase 5: Streaming Layer Integration

- Kafka topic operations
- Schema Registry schema management
- Kafka Connect connector status
- Message production/consumption

### Phase 6: Processing Layer Integration

- Spark cluster status
- Flink cluster status
- Job submission capabilities
- Worker connectivity

### Phase 7: Query Engine Integration

- Trino catalog queries
- ClickHouse query execution
- Cross-engine data access
- SQL operation validation

### Phase 8: Observability Stack

- Prometheus target scraping
- Grafana datasource connectivity
- Loki log ingestion
- Alertmanager functionality

### Phase 9: Security & IAM

- Keycloak health and readiness
- Realm accessibility
- Authentication capabilities

### Phase 10: End-to-End Data Flow

- Complete data pipeline from ingestion to analytics
- Multi-component workflow validation
- Data persistence verification
- Cross-engine data consistency

### Phase 11: Component Interdependency

- Nessie ↔ PostgreSQL connection
- Trino ↔ Nessie catalog integration
- Kafka Connect ↔ Kafka communication
- Flink ↔ Kafka integration
- Grafana ↔ Prometheus integration

## Test Scenarios

### Integration Test Scenarios

1. **Kafka → Iceberg Flow**

   - Produce messages to Kafka
   - Consume and store in Iceberg
   - Verify data persistence

2. **Trino → Iceberg → Trino Roundtrip**

   - Create tables via Trino
   - Insert data
   - Query and verify data

3. **Cross-Engine Data Access**

   - Write data via Trino
   - Read data via Spark
   - Verify consistency

4. **ClickHouse Analytics**
   - Create analytical tables
   - Load data
   - Execute analytical queries

### E2E Test Scenario: IoT Sensor Pipeline

```
Data Source → Kafka → Flink → Iceberg → Trino → ClickHouse → Analytics
```

Steps:

1. Ingest IoT sensor data via Kafka
2. Process stream via Flink
3. Store in Iceberg (Data Lake)
4. Query via Trino (SQL Analytics)
5. Load into ClickHouse (OLAP)
6. Execute real-time analytics
7. Verify data versioning (Nessie)
8. Check monitoring metrics (Prometheus/Loki)

## Test Output

### Success Example

```
✅ Passed: 45
❌ Failed: 0
📊 Total:  45
🎉 All tests passed!
```

### Component Status Example

```
✅ MinIO is healthy
✅ PostgreSQL is healthy
✅ Nessie is healthy
✅ Kafka is healthy
✅ Trino is healthy
✅ ClickHouse is healthy
... (15 more components)
```

## Debugging Failed Tests

### View Service Logs

```bash
# View logs for specific service
docker logs datalyptica-<component-name>

# Follow logs in real-time
docker logs -f datalyptica-<component-name>

# View last 100 lines
docker logs --tail 100 datalyptica-<component-name>
```

### Check Service Health

```bash
# Check container status
docker ps -a | grep datalyptica-

# Inspect container health
docker inspect --format='{{.State.Health.Status}}' datalyptica-<component-name>

# Check resource usage
docker stats --no-stream | grep datalyptica-
```

### Manual Component Testing

```bash
# Test MinIO
curl http://localhost:9000/minio/health/live

# Test Nessie
curl http://localhost:19120/api/v2/config

# Test Trino
docker exec datalyptica-trino trino --execute "SHOW CATALOGS"

# Test Kafka
docker exec datalyptica-kafka kafka-topics --bootstrap-server localhost:9092 --list

# Test ClickHouse
docker exec datalyptica-clickhouse clickhouse-client --query "SELECT 1"
```

## Test Development

### Adding New Tests

1. Create test file in appropriate directory
2. Source test helpers: `source "${SCRIPT_DIR}/../helpers/test_helpers.sh"`
3. Use helper functions: `test_start`, `test_step`, `test_info`, `test_error`, `test_success`
4. Make script executable: `chmod +x your-test.sh`

### Test Helper Functions

- `test_start(name)` - Start test suite
- `test_step(message)` - Log test step
- `test_info(message)` - Log info message
- `test_error(message)` - Log error message
- `test_success(message)` - Mark test as successful
- `test_warning(message)` - Log warning message
- `check_service_running(service)` - Check if service is running
- `check_service_healthy(service)` - Check if service is healthy
- `http_health_check(url)` - Perform HTTP health check
- `execute_trino_query(query)` - Execute Trino SQL query
- `execute_clickhouse_query(query)` - Execute ClickHouse query
- `create_kafka_topic(topic)` - Create Kafka topic
- `print_test_summary()` - Print test results summary

## Continuous Integration

### GitHub Actions Example

```yaml
name: Datalyptica Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Start services
        run: cd docker && docker compose up -d
      - name: Wait for services
        run: sleep 60
      - name: Run tests
        run: ./tests/run-tests.sh full
```

## Performance Considerations

- Tests use timeouts to prevent hanging
- Parallel execution not recommended (resource constraints)
- Full test suite takes approximately 5-10 minutes
- Quick health checks take approximately 1-2 minutes

## Troubleshooting

### Common Issues

1. **Timeout errors**: Increase timeout values in test scripts
2. **Connection refused**: Ensure all services are fully started
3. **Permission denied**: Make scripts executable with `chmod +x`
4. **Port conflicts**: Check no other services are using the same ports
5. **Resource exhaustion**: Ensure Docker has sufficient resources (8GB+ RAM)

### Environment Requirements

- Docker 20.10+
- Docker Compose v2+
- 8GB+ RAM allocated to Docker
- 20GB+ disk space
- macOS: Install coreutils (`brew install coreutils`)

## Contributing

When adding new components to Datalyptica:

1. Add health check to `test-all-health.sh`
2. Add integration test to `test-data-flow.sh`
3. Update comprehensive test suite
4. Update this README with component count
5. Document any new test helper functions

## Support

For issues with tests:

1. Check service logs: `docker logs datalyptica-<component>`
2. Verify all services are running: `docker ps | grep datalyptica-`
3. Review test output for specific errors
4. Check GitHub Issues for known problems
