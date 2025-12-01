# Datalyptica Comprehensive Test Suite - Execution Guide

## 🎯 What Was Created

A complete testing framework for all **21 components** of the Datalyptica Data Lakehouse platform:

### Test Files Created

```
tests/
├── run-tests.sh                              # 🚀 Main test runner
├── test-summary.sh                           # 📊 Quick component status check
├── comprehensive-test-all-21-components.sh   # 🔬 Complete test suite
├── README.md                                 # 📖 Detailed documentation
│
├── helpers/
│   └── test_helpers.sh                       # 🛠️ Reusable test utilities
│
├── health/
│   └── test-all-health.sh                    # ❤️ Health checks for 21 components
│
├── integration/
│   └── test-data-flow.sh                     # 🔄 Cross-component integration tests
│
└── e2e/
    └── test-complete-pipeline.sh             # 🌐 End-to-end pipeline validation
```

## 🧪 Test Coverage (11 Phases)

### Phase 1: Pre-Flight Checks

- ✅ Docker environment validation
- ✅ Docker Compose availability
- ✅ Project file verification
- ✅ Environment configuration

### Phase 2: Component Health Checks (21 Components)

All components across 5 layers:

1. **Storage** (3): MinIO, PostgreSQL, Nessie
2. **Streaming** (4): Zookeeper, Kafka, Schema Registry, Kafka UI
3. **Processing** (4): Spark Master/Worker, Flink JobManager/TaskManager
4. **Analytics** (4): Trino, ClickHouse, dbt, Kafka Connect
5. **Observability** (6): Prometheus, Grafana, Loki, Alloy, Alertmanager, Keycloak

### Phase 3: Network Connectivity

- HTTP endpoint availability tests
- Port accessibility verification
- API responsiveness checks

### Phase 4: Storage Layer Integration

- MinIO bucket operations
- PostgreSQL database queries
- Nessie catalog operations

### Phase 5: Streaming Layer Integration

- Kafka topic creation/deletion
- Message production/consumption
- Schema Registry operations

### Phase 6: Processing Layer Integration

- Spark cluster status
- Flink cluster operations
- Job submission capabilities

### Phase 7: Query Engine Integration

- Trino SQL query execution
- ClickHouse analytical queries
- Cross-engine data access

### Phase 8: Observability Stack

- Prometheus metrics scraping
- Grafana datasource connectivity
- Loki log ingestion

### Phase 9: Security & IAM

- Keycloak health and readiness
- Realm accessibility tests

### Phase 10: End-to-End Data Flow

- Complete pipeline testing
- Multi-component workflows
- Data consistency verification

### Phase 11: Component Interdependency

- Service-to-service communication
- Dependency chain validation

## 🚀 Quick Start

### 1. Start All Services

```bash
cd docker
docker compose up -d

# Wait for services to start (2-3 minutes)
watch -n 2 'docker compose ps'
```

### 2. Check Component Status

```bash
# Quick status check
./tests/test-summary.sh
```

**Expected Output:**

```
╔═══════════════════════════════════════════════════════════════╗
║          Datalyptica Component Test Summary                         ║
║          Testing All 21 Platform Components                   ║
╚═══════════════════════════════════════════════════════════════╝

═══ Storage Layer (3 components) ═══
✓ minio
✓ postgresql
✓ nessie

═══ Streaming Layer (4 components) ═══
✓ zookeeper
✓ kafka
✓ schema-registry
✓ kafka-ui

... (continues for all 21 components)

════════════════════════════════════════════════════
                  Summary
════════════════════════════════════════════════════
✓ Healthy:   21 / 21
○ Running:   0 / 21
✗ Down:      0 / 21
════════════════════════════════════════════════════

🎉 All systems operational! (100%)
```

### 3. Run Health Checks

```bash
# Quick health check (1-2 minutes)
./tests/run-tests.sh quick
```

### 4. Run Comprehensive Tests

```bash
# Full test suite (5-10 minutes)
./tests/run-tests.sh full
```

## 📋 Test Execution Options

### Option 1: Quick Health Check (Recommended for CI)

```bash
./tests/run-tests.sh quick
```

- ⏱️ Duration: 1-2 minutes
- ✅ Tests: Component health checks only
- 🎯 Use: Quick validation, CI pipelines

### Option 2: Health-Only Tests

```bash
./tests/run-tests.sh health
```

- ⏱️ Duration: 1-2 minutes
- ✅ Tests: Detailed health checks for all 21 components

### Option 3: Integration Tests

```bash
./tests/run-tests.sh integration
```

- ⏱️ Duration: 3-5 minutes
- ✅ Tests: Cross-component data flow
- 🔄 Tests: Kafka → Iceberg, Trino ↔ Spark, ClickHouse

### Option 4: End-to-End Tests

```bash
./tests/run-tests.sh e2e
```

- ⏱️ Duration: 5-7 minutes
- ✅ Tests: Complete pipeline simulation
- 🌐 Scenario: IoT sensor data pipeline

### Option 5: Comprehensive Test Suite

```bash
./tests/comprehensive-test-all-21-components.sh
```

- ⏱️ Duration: 10-15 minutes
- ✅ Tests: All 11 phases
- 📊 Coverage: 100% of components

## 🎯 Test Scenarios Covered

### Scenario 1: Storage Layer Validation

```
MinIO → PostgreSQL → Nessie → Iceberg Tables
```

**Tests:**

- Bucket creation/deletion
- Database connectivity
- Catalog operations
- Table metadata storage

### Scenario 2: Streaming Pipeline

```
Data Source → Kafka → Flink → Iceberg
```

**Tests:**

- Topic creation
- Message production/consumption
- Stream processing
- Data persistence

### Scenario 3: SQL Analytics

```
Iceberg ← Trino → Query Results
```

**Tests:**

- Schema creation
- Table creation
- Data insertion
- Query execution
- Cross-engine access

### Scenario 4: Real-Time OLAP

```
Kafka → ClickHouse → Materialized Views → Analytics
```

**Tests:**

- Kafka engine tables
- Real-time ingestion
- Aggregation queries
- Performance metrics

### Scenario 5: Complete IoT Pipeline (E2E)

```
IoT Sensors → Kafka → Flink → Iceberg → Trino → ClickHouse → Power BI
```

**Tests:**

- Data ingestion
- Stream processing
- Storage in Data Lake
- SQL analytics
- OLAP analytics
- Monitoring & observability

## 📊 Understanding Test Results

### Success Output

```
✅ Component is healthy (24s)

========================================
        Test Summary
========================================
✅ Passed: 45
❌ Failed: 0
📊 Total:  45
========================================
🎉 All tests passed!
```

### Partial Failure Output

```
❌ Component health check failed

========================================
        Test Summary
========================================
✅ Passed: 38
❌ Failed: 7
📊 Total:  45
========================================
💥 Some tests failed
```

## 🐛 Troubleshooting Failed Tests

### Common Failures and Solutions

#### 1. Service Not Running

```
❌ postgresql health check failed
```

**Solution:**

```bash
# Check service status
docker ps -a | grep datalyptica-postgresql

# Restart service
docker restart datalyptica-postgresql

# Check logs
docker logs datalyptica-postgresql
```

#### 2. Port Already in Use

```
Error: bind: address already in use
```

**Solution:**

```bash
# Find process using port
lsof -i :9092  # Example for Kafka port

# Kill process or change port in docker/.env
```

#### 3. Insufficient Resources

```
❌ Container exited with code 137
```

**Solution:**

```bash
# Increase Docker resources
# Docker Desktop → Settings → Resources
# RAM: 8GB+ (recommended: 16GB)
# CPUs: 4+ (recommended: 8)
```

#### 4. Dependency Not Ready

```
❌ Nessie health check failed
```

**Solution:**

```bash
# Check dependencies
docker logs datalyptica-nessie | grep -i error

# Restart with dependencies
docker compose up -d postgresql
sleep 10
docker compose up -d nessie
```

## 🔍 Detailed Component Testing

### Test Individual Component

```bash
# Example: Test MinIO
curl http://localhost:9000/minio/health/live

# Example: Test Nessie
curl http://localhost:19120/api/v2/config

# Example: Test Trino
docker exec datalyptica-trino trino --execute "SHOW CATALOGS"

# Example: Test Kafka
docker exec datalyptica-kafka kafka-topics --bootstrap-server localhost:9092 --list

# Example: Test ClickHouse
docker exec datalyptica-clickhouse clickhouse-client --query "SELECT 1"
```

## 📈 CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Datalyptica Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up environment
        run: cp docker/.env.example docker/.env

      - name: Start services
        run: |
          cd docker
          docker compose up -d

      - name: Wait for services
        run: sleep 120

      - name: Run health checks
        run: ./tests/run-tests.sh quick

      - name: Run integration tests
        run: ./tests/run-tests.sh integration

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: tests/*.log
```

## 📝 Test Development Guide

### Adding New Component Test

1. **Add to health check** (`tests/health/test-all-health.sh`):

```bash
test_step "22. New Component (Description)"
if http_health_check "http://localhost:PORT/health"; then
    test_info "✅ New Component is healthy"
else
    test_error "❌ New Component health check failed"
fi
```

2. **Add integration test** (`tests/integration/test-data-flow.sh`):

```bash
test_step "Test: New Component integration"
# Add test logic here
```

3. **Update comprehensive test** (`comprehensive-test-all-21-components.sh`):

```bash
# Add to appropriate phase
test_step "Testing New Component..."
# Add test logic
```

4. **Update documentation**:

- Update component count in README.md
- Add component to architecture diagram
- Document new test scenarios

## 🎓 Best Practices

### 1. Test Isolation

- Each test creates its own resources
- Cleanup after test completion
- Use unique identifiers (e.g., `test-$$`)

### 2. Timeouts

- All tests use timeouts to prevent hanging
- Default: 30-120 seconds per operation
- Adjust based on resource availability

### 3. Error Handling

- Tests continue on non-critical failures
- Clear error messages
- Comprehensive logging

### 4. Idempotency

- Tests can be run multiple times
- No side effects between runs
- Proper cleanup on failure

## 📚 Additional Resources

- **Test Helpers**: See `tests/helpers/test_helpers.sh` for reusable functions
- **Docker Compose**: See `docker/docker-compose.yml` for service definitions
- **Configuration**: See `docker/.env.example` for environment variables
- **Architecture**: See `.github/copilot-instructions.md` for platform overview

## 🆘 Getting Help

If tests fail:

1. ✅ Check service logs: `docker logs datalyptica-<component>`
2. ✅ Verify services running: `docker ps | grep datalyptica-`
3. ✅ Check resource usage: `docker stats`
4. ✅ Review test output for specific errors
5. ✅ Check GitHub Issues for known problems

## 🎉 Success Criteria

All tests passing indicates:

- ✅ All 21 components are operational
- ✅ Network connectivity is working
- ✅ Storage layer is functional
- ✅ Streaming pipeline is operational
- ✅ Processing engines are running
- ✅ Query engines are accessible
- ✅ Observability stack is collecting data
- ✅ Security layer is protecting resources
- ✅ End-to-end data flow is working
- ✅ Platform is ready for production use

---

**Last Updated**: November 26, 2025
**Test Suite Version**: 1.0.0
**Components Tested**: 21/21 (100%)
