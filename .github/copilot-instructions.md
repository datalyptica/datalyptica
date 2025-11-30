# ShuDL (Shugur Data Lakehouse) AI Agent Instructions

## Project Overview

ShuDL is a comprehensive on-premises **Data Lakehouse platform** built on Apache Iceberg table format with Project Nessie catalog, MinIO object storage, PostgreSQL HA cluster, and dual query engines (Trino + Spark). The platform provides ACID transactions, schema evolution, time-travel queries, and git-like data versioning.

### Development Philosophy

- **No Backward Compatibility**: Platform upgrades use direct replacements, not gradual migrations. Clean, modern implementations preferred over compatibility layers.
- **Production-Ready HA**: PostgreSQL HA with Patroni, etcd, and HAProxy provides automatic failover (~15s) and zero data loss.
- **Security First**: SSL/TLS for all inter-service communication, Docker Secrets for sensitive data, network segmentation.
- **Cloud-Native Patterns**: 25 containerized services, declarative configuration, health checks, and automated recovery.

## Platform Maturity

**Current Status**: Phase 2 Complete (60% of Security & HA roadmap)

**Completed**:

- ✅ SSL/TLS Infrastructure (self-signed certificates for all services)
- ✅ Docker Secrets (sensitive data management)
- ✅ PostgreSQL HA (Patroni + etcd + HAProxy, automatic failover tested)
- ✅ Security Hardening (8.5/10 security score, network segmentation)
- ✅ Enhanced Monitoring (Patroni/etcd metrics in Prometheus/Grafana)
- ✅ Kafka KRaft Migration (removed ZooKeeper dependency)
- ✅ CDC Pipeline (Debezium → Kafka → validated)

**In Progress**:

- 🔄 Kafka HA (multi-broker cluster)
- 🔄 Service Replication (Trino, Flink workers)
- 🔄 Keycloak Configuration (SSO for services)
- 🔄 Service Authentication (API security)

**Production Readiness**: 80% (was 52% before Phase 2)

## Core Architecture

### Complete Platform Layers (8 layers)

1. **Data Sources**: Structured, semi-structured, and unstructured data inputs
2. **Integration Layer**: Airbyte & Debezium for data ingestion and CDC
3. **Streaming Layer**: Kafka (KRaft mode) + Schema Registry for real-time data pipelines
4. **Processing & Transformation**: Flink for stream processing, Spark for batch ETL
5. **Storage Layer (Lakehouse)**:
   - **Apache Iceberg**: Table format with ACID transactions
   - **Nessie** (port 19120): Git-like catalog for data versioning
   - **MinIO** (ports 9000/9001/9443): S3-compatible object storage with SSL/TLS
   - **PostgreSQL HA**: 2-node Patroni cluster with etcd coordination and HAProxy load balancing
   - **HAProxy** (ports 15000/15001/8404): PostgreSQL write/read routing and automatic failover
6. **OLAP Layer**: ClickHouse for real-time analytics
7. **Semantic & Modeling**: Trino (port 8080) for federated queries, dbt for transformations
8. **Consumers**: Power BI and other BI tools

### Complete Component List

**Security & Observability**:

- **Keycloak** (port 8180): Identity and access management
- **Prometheus** (port 9090): Metrics collection
- **Grafana** (port 3000): Dashboards and visualization
- **Loki** (port 3100): Log aggregation
- **Alloy** (port 12345): Log collection agent
- **Alertmanager** (port 9095): Alert routing

**Orchestration**:

- **Apache Airflow**: Workflow orchestration and scheduling

**Core Services** (25 total):

- **Integration**: Airbyte (ELT), Debezium (CDC via Kafka Connect port 8083)
- **Streaming**: Kafka (9092/9093, KRaft mode), Schema Registry (8085), Kafka UI (8090)
- **Processing**: Flink (JobManager 8081 + TaskManager), Spark (Master 7077 + Worker)
- **Storage**: MinIO (9000/9001/9443), PostgreSQL HA (Patroni + etcd + HAProxy), Nessie (19120), Iceberg
- **High Availability**: Patroni (2 nodes with 8008 REST API), etcd (3-node cluster on 2379), HAProxy (15000/15001/8404)
- **OLAP**: ClickHouse (HTTP 8123, native 9000)
- **Query/Transform**: Trino (8080), dbt (docs 8580)
- **Consumers**: Power BI connector

### Data Flow Architecture

**Batch/ETL Flow**:

```text
Data Sources → Airbyte → Kafka → Flink/Spark → Iceberg (Nessie + MinIO) → Trino/dbt → ClickHouse → Power BI
```

**Real-Time/CDC Flow**:

```text
Databases → Debezium → Kafka → Flink → Iceberg → ClickHouse → Power BI
```

**Query Flow** (Semantic layer):

```text
Power BI ← ClickHouse ← Trino/dbt ← Iceberg (Nessie catalog)
```

### Key Integration Points

- **Iceberg as Central Hub**: All processed data lands in Iceberg tables (Nessie catalog + MinIO storage)
- **Cross-Engine Access**: Trino, Spark, ClickHouse, and dbt all query the same Iceberg tables
- **Kafka as Message Backbone**: Runs in KRaft mode (self-managed metadata), connects integration layer (Airbyte/Debezium) to processing (Flink/Spark)
- **Schema Registry**: Manages Avro schemas for Kafka messages (required by Debezium connectors)
- **HAProxy as PostgreSQL Gateway**: All services connect to PostgreSQL through HAProxy (port 5000 for writes, 5001 for reads) with automatic failover
- **Patroni for HA**: Manages 2-node PostgreSQL cluster with streaming replication and automatic failover (~15 seconds)
- **etcd Coordination**: 3-node etcd cluster provides distributed consensus for Patroni leader election
- **Security**: SSL/TLS for inter-service communication, Docker Secrets for sensitive data, network segmentation
- **Configuration Pattern**: All services use environment variable substitution at runtime (no mounted config files)
- **Networking**: 4 Docker bridge networks: `management`, `control`, `data`, `storage` for service isolation

## Critical Developer Workflows

### Building & Running

```bash
# Build all custom images (dependency order: minio → postgresql → nessie → trino/spark)
./scripts/build/build-all-images.sh

# Start full stack (images from ghcr.io/shugur-network/shudl)
cd docker && docker compose up -d

# Check service health (all services have health checks)
docker compose ps
```

### Testing Strategy

Tests are located in `tests/` (though directory may not exist in your workspace view):

- **Config tests**: Validate environment variables and docker-compose syntax
- **Health tests**: Verify individual service endpoints (e.g., `curl http://localhost:19120/api/v2/config`)
- **Integration tests**: Test cross-engine data access (Spark writes → Trino reads via Iceberg)
- **Use timeout commands**: `timeout 120 ./tests/e2e/use-cases.e2e.test.sh` (macOS requires `brew install coreutils`)

### Environment Configuration

- **Source of truth**: `docker/.env` (copy from `.env.example`) + service-specific `.env.*` files
- **Template processing**: Entrypoint scripts (`docker/services/*/scripts/entrypoint.sh`) use `envsubst` to generate configs at runtime
- **S3 credentials**: `S3_ACCESS_KEY`/`S3_SECRET_KEY` must match `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`
- **PostgreSQL connectivity**: Always use `POSTGRES_HOST=haproxy` and `POSTGRES_PORT=5000` (writes) or `5001` (reads)
- **Nessie URI pattern**: `http://nessie:19120/api/v2` (Trino/Spark use `/api/v2` endpoint)
- **Docker Secrets**: Sensitive data stored in `secrets/passwords/` and mounted as files in containers
- **SSL/TLS**: All inter-service communication uses self-signed certificates from `secrets/certificates/`

## Project-Specific Conventions

### Service Entrypoint Pattern

All custom services follow this pattern in `docker/services/*/scripts/entrypoint.sh`:

```bash
# 1. Validate required env vars (fail fast if missing)
: ${REQUIRED_VAR:?'REQUIRED_VAR must be set'}

# 2. Process config templates using envsubst
envsubst < /opt/service/config.template > /opt/service/config.properties

# 3. Wait for dependencies (e.g., PostgreSQL) using health checks
while ! pg_isready -h postgresql; do sleep 2; done

# 4. Execute main service process with exec (PID 1)
exec /opt/service/bin/start-service
```

### Iceberg Configuration Consistency

**Critical**: Spark and Trino must use identical Iceberg catalog settings:

- Catalog type: `nessie` (Trino) / `NessieCatalog` (Spark)
- URI: `http://nessie:19120/api/v2`
- Warehouse: `s3://lakehouse/` (or `s3a://` for Spark)
- S3 endpoint: `http://minio:9000` with `path-style-access=true`
- Reference branch: `main` (Nessie git-like branching)

Example from `docker/config/spark/spark-defaults.conf`:

```properties
spark.sql.catalog.iceberg.catalog-impl=org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.iceberg.uri=http://nessie:19120/api/v2
spark.sql.catalog.iceberg.warehouse=s3://lakehouse/
spark.sql.catalog.iceberg.s3.path-style-access=true
```

### Docker Image Structure

- **Registry**: `ghcr.io/shugur-network/shudl` (GitHub Container Registry)
- **Tagging**: `{service}:${SHUDL_VERSION}` where version is in `docker/VERSION`
- **User standardization**: All containers run as `shusr` (UID 1000) for security
- **Health checks**: Every service has `HEALTHCHECK` directive and `depends_on: {condition: service_healthy}`

## Common Gotchas

1. **AWS Region Conflicts**: Spark requires `AWS_REGION=us-east-1` env var for Iceberg S3FileIO, even with MinIO
2. **Nessie JDBC Backend**: Uses `NESSIE_VERSION_STORE_TYPE=JDBC2` with Quarkus datasource, connects via HAProxy (port 5000)
3. **PostgreSQL Connectivity**: All services MUST connect through HAProxy (haproxy:5000 for writes, haproxy:5001 for reads), not directly to PostgreSQL
4. **Port Collisions**:
   - PostgreSQL (internal): 5432 (not exposed, use HAProxy)
   - HAProxy Write: 15000 (maps to internal 5000)
   - HAProxy Read: 15001 (maps to internal 5001)
   - HAProxy Stats: 8404
   - MinIO API: 9000 (conflicts with ClickHouse native port)
   - MinIO Console: 9001
   - MinIO HTTPS: 9443
   - Kafka: 9092, 9093 (internal/external, KRaft mode)
   - Schema Registry: 8085
   - Kafka Connect: 8083
   - Kafka UI: 8090
   - Flink JobManager: 8081
   - Trino: 8080
   - Nessie: 19120
   - ClickHouse HTTP: 8123
   - dbt Docs: 8580
   - Keycloak: 8180, 8543
   - Patroni REST API: 8008 (per node, internal)
   - etcd: 2379, 2380 (client, peer)
5. **Test Helper Location**: Shell test helpers are in `tests/helpers/test_helpers.sh` with functions like `execute_trino_query`, `execute_spark_sql`
6. **Docker Compose Project Name**: Always uses `${COMPOSE_PROJECT_NAME}` prefix for containers (e.g., `docker-minio`)
7. **Kafka Schema Registry**: Debezium CDC connectors require Schema Registry for Avro serialization
8. **Service Startup Order**: Must follow dependency chain: etcd → Patroni → HAProxy → (Nessie, Keycloak, Kafka Connect) → Kafka → Schema Registry → Kafka Connect → Flink
9. **ClickHouse Kafka Engine**: Requires Kafka to be fully operational before creating Kafka table engines
10. **Kafka KRaft Mode**: No ZooKeeper required; Kafka manages its own metadata via internal Raft consensus

## Service-Specific Patterns

### PostgreSQL High Availability

- **Patroni** (REST API 8008): Manages 2-node PostgreSQL cluster with automatic failover
- **etcd** (ports 2379/2380): 3-node cluster for distributed consensus and leader election
- **HAProxy** (ports 15000/15001/8404): Load balancer with health checks via Patroni REST API
  - Port 5000 (15000 external): Write endpoint (routes to PRIMARY only)
  - Port 5001 (15001 external): Read endpoint (load balances across all nodes)
  - Port 8404: Stats dashboard at `http://localhost:8404/stats`
- **Connection pattern**: Services use `jdbc:postgresql://haproxy:5000/dbname` for writes, `haproxy:5001` for reads
- **Failover time**: ~15 seconds for ungraceful failover, ~2 seconds for planned switchover
- **Monitoring**: Patroni exposes metrics at `/metrics` endpoint, integrated with Prometheus

### Kafka Ecosystem

- **Kafka** (port 9092): Message broker in KRaft mode (self-managed metadata, no ZooKeeper)
- **Schema Registry** (port 8085): Avro schema management for Kafka messages
- **Kafka Connect** (port 8083): Runs Debezium CDC connectors with Avro converters
- **Kafka UI** (port 8090): Management interface for Kafka cluster
- **Topic naming**: Use descriptive names like `{source}.{schema}.{table}` for CDC topics
- **KRaft Configuration**: Uses `KAFKA_PROCESS_ROLES=broker,controller` with internal Raft consensus

### Flink Stream Processing

- **JobManager** (port 8081): Cluster coordinator and job scheduler
- **TaskManager**: Executes streaming tasks (connects to JobManager:6123)
- **Checkpointing**: Stores state in `/opt/flink/checkpoints` volume
- **Savepoints**: Manual snapshots in `/opt/flink/savepoints` for versioned rollbacks

### ClickHouse OLAP

- **HTTP port** (8123): Query interface for SQL queries
- **Native port** (9000): ClickHouse native protocol (conflict with MinIO - use 9001 for MinIO console)
- **Kafka Engine**: Direct integration with Kafka topics for real-time ingestion
- **Materialized Views**: Pre-aggregate data for fast queries

### dbt Transformations

- **Profiles**: Located in `/root/.dbt` volume, configure Trino/Spark connections
- **Project structure**: Models in `/dbt` volume
- **Docs server** (port 8580): Serve generated documentation
- **Target adapters**: dbt-trino for SQL transformations, dbt-spark for PySpark models

### Keycloak IAM

- **Admin console** (port 8180): Identity and access management UI
- **Database**: Uses dedicated PostgreSQL database (`keycloak` DB) via HAProxy
- **Realms**: Create separate realms for different environments/tenants
- **Client configs**: Configure OAuth2/OIDC for services like Grafana, Airflow

### High Availability Operations

#### Patroni Cluster Management

```bash
# Check cluster status
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml list

# Planned switchover (graceful, ~2 seconds)
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml switchover \
  --leader postgresql-patroni-1 \
  --candidate postgresql-patroni-2 \
  --force

# Restart a member (for config changes)
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml restart postgresql-patroni-1

# Reload configuration (no downtime)
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml reload postgresql-patroni-1
```

#### etcd Cluster Health

```bash
# Check cluster health
docker exec docker-etcd-1 etcdctl --endpoints=http://etcd-1:2379,http://etcd-2:2379,http://etcd-3:2379 endpoint health

# Check member list
docker exec docker-etcd-1 etcdctl --endpoints=http://localhost:2379 member list

# Check leader
docker exec docker-etcd-1 etcdctl --endpoints=http://localhost:2379 endpoint status --write-out=table
```

#### HAProxy Monitoring

```bash
# View stats dashboard
open http://localhost:8404/stats

# Check backend status via CLI
docker exec docker-haproxy sh -c "echo 'show stat' | socat stdio /run/haproxy/admin.sock"

# Test write routing (should always go to PRIMARY)
psql -h localhost -p 15000 -U postgres -c "SELECT pg_is_in_recovery();"

# Test read routing (load balanced across all nodes)
psql -h localhost -p 15001 -U postgres -c "SELECT pg_is_in_recovery();"
```

## Data Pipeline Patterns

### CDC with Debezium → Kafka → Iceberg

```bash
# 1. Register Debezium PostgreSQL connector (via Kafka Connect)
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d '{
  "name": "postgres-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgresql",
    "database.port": "5432",
    "database.user": "debezium_user",
    "database.dbname": "source_db",
    "table.include.list": "public.customers",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}'

# 2. Flink job consumes from Kafka and writes to Iceberg
# (Flink SQL or Java job)

# 3. Query in Trino
docker exec shudl-trino trino --execute "SELECT * FROM iceberg.cdc.customers"
```

### Batch Ingestion with Airbyte → Kafka → Spark → Iceberg

```python
# Spark streaming job reading from Kafka
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("KafkaToIceberg") \
    .getOrCreate()

# Read from Kafka
df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "airbyte.raw.customers") \
    .load()

# Write to Iceberg
df.writeStream \
    .format("iceberg") \
    .outputMode("append") \
    .option("checkpointLocation", "/tmp/checkpoints") \
    .toTable("iceberg.raw.customers")
```

### Creating Iceberg Tables

```sql
-- Trino syntax
CREATE SCHEMA iceberg.my_schema;
CREATE TABLE iceberg.my_schema.my_table (
    id BIGINT,
    name VARCHAR,
    amount DECIMAL(10,2)
) WITH (format = 'PARQUET');

-- Spark SQL (same result)
CREATE NAMESPACE iceberg.my_schema;
CREATE TABLE iceberg.my_schema.my_table (...) USING iceberg;
```

### Real-Time Analytics with ClickHouse

```sql
-- Create Kafka engine table in ClickHouse
CREATE TABLE kafka_source (
    id UInt64,
    name String,
    amount Decimal(10,2),
    timestamp DateTime
) ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:9092',
         kafka_topic_list = 'transactions',
         kafka_group_name = 'clickhouse_consumer',
         kafka_format = 'Avro',
         kafka_schema = 'schema_id';

-- Create materialized view for aggregations
CREATE MATERIALIZED VIEW transactions_mv
ENGINE = SummingMergeTree()
ORDER BY (toDate(timestamp), id)
AS SELECT
    toDate(timestamp) as date,
    id,
    sum(amount) as total_amount
FROM kafka_source
GROUP BY date, id;
```

### dbt Transformations on Iceberg

```yaml
# models/marts/customers_summary.sql
{{ config(materialized='incremental', unique_key='customer_id') }}

SELECT
    customer_id,
    COUNT(*) as order_count,
    SUM(amount) as total_spent,
    MAX(order_date) as last_order_date
FROM {{ source('iceberg', 'orders') }}
{% if is_incremental() %}
WHERE order_date > (SELECT MAX(last_order_date) FROM {{ this }})
{% endif %}
GROUP BY customer_id
```

### Cross-Engine Verification

```bash
# Write with Spark
docker exec shudl-spark-master spark-submit /path/to/etl.py

# Read with Trino
docker exec shudl-trino trino --execute "SELECT * FROM iceberg.my_schema.my_table"

# Query aggregated data in ClickHouse
docker exec shudl-clickhouse clickhouse-client --query "SELECT * FROM transactions_mv"
```

## Monitoring & Observability Stack

- **Prometheus** (port 9090): Scrapes metrics from all services
- **Grafana** (port 3000): Dashboards at `configs/monitoring/grafana/dashboards/`
- **Loki** (port 3100): Log aggregation via Alloy (Promtail successor)
- **Alloy** (port 12345): Collects logs from Docker containers and forwards to Loki
- **Alertmanager** (port 9095): Alert routing with templates in `configs/monitoring/alertmanager/`

## When Modifying Services

1. **Update entrypoint script**: Changes to config generation logic go in `docker/services/{service}/scripts/entrypoint.sh`
2. **Reflect in docker-compose**: Add new env vars to `docker/docker-compose.yml` service definition
3. **Update .env files**: Document new variables in `docker/.env.example` and service-specific `.env` files (e.g., `.env.patroni`, `.env.nessie`)
4. **Use Docker Secrets**: For sensitive data, add to `secrets/passwords/` and reference in `docker-compose.yml`
5. **Update dependencies**: If service depends on PostgreSQL, ensure it uses HAProxy (`haproxy:5000`) not direct connection
6. **Test integration**: Add test case to `tests/integration/` following `test_cross_engine.sh` pattern
7. **Rebuild image**: `docker build -t ghcr.io/shugur-network/shudl/{service}:latest docker/services/{service}/`
8. **HA considerations**: For stateful services, consider replication strategy and failover mechanisms

## Key Files Reference

- `docker/docker-compose.yml`: Complete service definitions (1500+ lines, 25 services)
- `docker/.env.example`: All configurable environment variables
- `docker/.env.patroni`: PostgreSQL HA specific environment variables
- `configs/config.yaml`: ShuDL application config (separate from Docker)
- `docker/services/*/Dockerfile`: Service image definitions
- `docker/services/patroni/config/patroni.yml`: Patroni cluster configuration
- `docker/config/*/`: Config templates processed by entrypoint scripts
- `configs/haproxy/haproxy.cfg`: HAProxy load balancer configuration with health checks
- `secrets/passwords/*`: Docker Secrets for sensitive data (passwords, keys)
- `secrets/certificates/*`: SSL/TLS certificates for inter-service communication
- `scripts/build/build-all-images.sh`: Build all custom images
- `scripts/generate-certificates.sh`: Generate SSL/TLS certificates for all services
- `scripts/generate-secrets.sh`: Generate secure passwords and keys
- `scripts/setup-loki.sh`, `scripts/setup-alloy.sh`: Monitoring stack setup
- `POSTGRESQL_HA.md`: PostgreSQL High Availability documentation and operations guide
- `TROUBLESHOOTING.md`: Common issues and solutions

## Testing Commands

```bash
# Quick health check (requires services running)
curl http://localhost:19120/api/v2/config      # Nessie
curl http://localhost:8080/v1/info             # Trino
curl http://localhost:9000/minio/health/live   # MinIO
curl http://localhost:8404/stats               # HAProxy stats dashboard
curl http://localhost:9092                     # Kafka (kafka-broker-api-versions)
curl http://localhost:8085                     # Schema Registry
curl http://localhost:8083                     # Kafka Connect
curl http://localhost:8081/overview            # Flink JobManager
curl http://localhost:8123/?query=SELECT%201   # ClickHouse
curl http://localhost:8090/actuator/health     # Kafka UI

# PostgreSQL HA cluster status
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml list
docker exec docker-etcd-1 etcdctl --endpoints=http://localhost:2379 endpoint health
curl http://localhost:8404/stats               # HAProxy dashboard

# Test automatic failover
docker kill docker-postgresql-patroni-1        # Kill primary
sleep 15                                       # Wait for failover
docker exec docker-postgresql-patroni-2 patronictl -c /etc/patroni/patroni.yml list

# Full integration test suite
cd tests && ./run-tests.sh --quick

# Specific test category
./tests/config/test_docker_compose.sh
./tests/health/test_nessie.sh
./tests/integration/test_spark_iceberg.sh
./tests/integration/test_cross_engine.sh

# Verify Kafka ecosystem (KRaft mode)
docker exec docker-kafka kafka-topics --bootstrap-server localhost:9092 --list
docker exec docker-kafka kafka-metadata --snapshot /tmp/kraft-combined-logs/__cluster_metadata-0/00000000000000000000.log --print
docker exec docker-schema-registry curl http://localhost:8081/subjects
curl http://localhost:8083/connectors  # List Debezium connectors

# Check Flink jobs
curl http://localhost:8081/jobs

# Query ClickHouse
docker exec docker-clickhouse clickhouse-client --query "SHOW DATABASES"

# Monitor Patroni metrics (Prometheus integration)
curl http://localhost:9090/api/v1/query?query=patroni_cluster_status
curl http://localhost:9090/api/v1/query?query=etcd_server_has_leader
```
