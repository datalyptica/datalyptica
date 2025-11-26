# ShuDL Service Endpoints Reference

Complete reference for all ShuDL service endpoints, ports, and APIs.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Core Data Services](#core-data-services)
- [Compute Services](#compute-services)
- [Streaming Services](#streaming-services)
- [Monitoring Services](#monitoring-services)
- [Management Services](#management-services)
- [API Documentation](#api-documentation)
- [Health Check Endpoints](#health-check-endpoints)
- [Metrics Endpoints](#metrics-endpoints)

---

## Quick Reference

### Service Ports Overview

| Service           | Internal Port | External Port | Protocol | Purpose            |
| ----------------- | ------------- | ------------- | -------- | ------------------ |
| PostgreSQL        | 5432          | 5432          | TCP      | Database           |
| MinIO API         | 9000          | 9000          | HTTP     | Object Storage API |
| MinIO Console     | 9001          | 9001          | HTTP     | Web Console        |
| Nessie            | 19120         | 19120         | HTTP     | Catalog API        |
| Trino             | 8080          | 8080          | HTTP     | Query Engine       |
| Spark Master      | 7077          | 7077          | TCP      | Spark RPC          |
| Spark Master UI   | 8080          | 8081          | HTTP     | Web UI             |
| Spark Worker UI   | 8081          | 8082          | HTTP     | Web UI             |
| Kafka             | 9092          | 9092          | TCP      | Message Broker     |
| Zookeeper         | 2181          | 2181          | TCP      | Coordination       |
| Schema Registry   | 8081          | 8081          | HTTP     | Schema Management  |
| Kafka UI          | 8080          | 8083          | HTTP     | Kafka Management   |
| Flink JobManager  | 8081          | 8084          | HTTP     | Flink Dashboard    |
| ClickHouse HTTP   | 8123          | 8123          | HTTP     | Analytics API      |
| ClickHouse Native | 9000          | 9001          | TCP      | Native Protocol    |
| Prometheus        | 9090          | 9090          | HTTP     | Metrics            |
| Grafana           | 3000          | 3000          | HTTP     | Dashboards         |

### Default Credentials

| Service    | Default Username | Default Password | Change Required |
| ---------- | ---------------- | ---------------- | --------------- |
| PostgreSQL | `nessie`         | `changeme123`    | **YES**         |
| MinIO      | `admin`          | `changeme123`    | **YES**         |
| Grafana    | `admin`          | `admin`          | **YES**         |
| ClickHouse | `default`        | (empty)          | **YES**         |
| Kafka UI   | (none)           | (none)           | N/A             |

---

## Core Data Services

### PostgreSQL Database

**Container Name**: `docker-postgresql` (or `${COMPOSE_PROJECT_NAME}-postgresql`)

#### Connection Details

- **Hostname**: `docker-postgresql` (internal), `localhost` (external)
- **Port**: `5432`
- **Default Database**: `nessie`
- **Default User**: `nessie`
- **Default Password**: `changeme123` ⚠️ **CHANGE IN PRODUCTION**

#### Connection Strings

```bash
# psql CLI
psql -h localhost -p 5432 -U nessie -d nessie

# JDBC URL
jdbc:postgresql://docker-postgresql:5432/nessie

# Python (psycopg2)
postgresql://nessie:changeme123@docker-postgresql:5432/nessie

# Go (pgx)
postgres://nessie:changeme123@docker-postgresql:5432/nessie?sslmode=disable
```

#### Available Databases

- `nessie` - Nessie catalog metadata
- `shudl` - ShuDL application data
- `postgres` - PostgreSQL system database

#### Authentication

- **Method**: MD5 password authentication
- **Allowed Networks**: Docker networks (172.18.0.0/16, 10.0.0.0/8)
- **SSL/TLS**: Not enabled by default (configure for production)

#### Management Tools

```bash
# Access PostgreSQL CLI
docker exec -it docker-postgresql psql -U nessie -d nessie

# List databases
docker exec docker-postgresql psql -U nessie -c "\l"

# Database size
docker exec docker-postgresql psql -U nessie -c "SELECT pg_size_pretty(pg_database_size('nessie'));"

# Active connections
docker exec docker-postgresql psql -U nessie -c "SELECT count(*) FROM pg_stat_activity;"
```

---

### MinIO Object Storage

**Container Name**: `docker-minio`

#### API Endpoint

- **URL**: http://localhost:9000
- **Internal URL**: http://docker-minio:9000
- **Protocol**: S3-compatible HTTP API
- **Authentication**: AWS Signature V4
- **Default Credentials**:
  - Access Key: `admin`
  - Secret Key: `changeme123` ⚠️ **CHANGE IN PRODUCTION**

#### Web Console

- **URL**: http://localhost:9001
- **Login**: Same credentials as API
- **Features**:
  - Bucket management
  - Object browser
  - User management
  - Monitoring dashboard

#### S3 Client Configuration

```bash
# AWS CLI
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key changeme123
aws configure set default.region us-east-1
aws --endpoint-url http://localhost:9000 s3 ls

# MinIO Client (mc)
mc alias set myminio http://localhost:9000 admin changeme123
mc ls myminio

# Python (boto3)
import boto3
s3 = boto3.client(
    's3',
    endpoint_url='http://docker-minio:9000',
    aws_access_key_id='admin',
    aws_secret_access_key='changeme123'
)
```

#### Default Buckets

- `lakehouse` - Iceberg table storage
- Auto-created on first start

#### Health Check

```bash
# Live check
curl http://localhost:9000/minio/health/live

# Ready check
curl http://localhost:9000/minio/health/ready
```

---

### Nessie Catalog

**Container Name**: `docker-nessie`

#### API Endpoint

- **Base URL**: http://localhost:19120
- **API Version**: v2
- **API Path**: `/api/v2`
- **Full URL**: http://localhost:19120/api/v2
- **Internal URL**: http://docker-nessie:19120/api/v2

#### Authentication

- **Default**: None (NONE auth type)
- **Production Options**:
  - BEARER token authentication
  - AWS SigV4 authentication
  - BASIC authentication

#### API Operations

**Configuration**

```bash
# Get server config
curl http://localhost:19120/api/v2/config

# Get server info
curl http://localhost:19120/api/v2/config | jq
```

**Branches & Tags**

```bash
# List references
curl http://localhost:19120/api/v2/trees

# Get default branch
curl http://localhost:19120/api/v2/trees/tree/main

# Create branch
curl -X POST http://localhost:19120/api/v2/trees/branch/dev \
  -H "Content-Type: application/json" \
  -d '{"name":"dev","hash":"<commit-hash>"}'
```

**Catalog Operations**

```bash
# List tables
curl http://localhost:19120/api/v2/trees/tree/main/entries

# Get table metadata
curl http://localhost:19120/api/v2/trees/tree/main/entries/namespace.table
```

#### Metrics

- **Prometheus Metrics**: http://localhost:19120/q/metrics
- **Health Check**: http://localhost:19120/q/health
- **Liveness**: http://localhost:19120/q/health/live
- **Readiness**: http://localhost:19120/q/health/ready

#### Swagger/OpenAPI

- **Swagger UI**: http://localhost:19120/q/swagger-ui
- **OpenAPI Spec**: http://localhost:19120/q/openapi

---

## Compute Services

### Trino Query Engine

**Container Name**: `docker-trino`

#### Coordinator Endpoint

- **URL**: http://localhost:8080
- **Internal URL**: http://docker-trino:8080
- **Discovery URI**: http://docker-trino:8080
- **Default User**: Any username (no auth by default)

#### Web Interface

- **URL**: http://localhost:8080
- **Features**:
  - Query history
  - Running queries
  - Worker status
  - Cluster metrics

#### CLI Access

```bash
# Trino CLI (inside container)
docker exec -it docker-trino trino

# External Trino CLI
trino --server http://localhost:8080 --catalog iceberg --schema default

# Execute query
trino --server http://localhost:8080 --execute "SHOW CATALOGS"
```

#### JDBC Connection

```java
// JDBC URL
jdbc:trino://docker-trino:8080/iceberg/default

// Java example
Connection conn = DriverManager.getConnection(
    "jdbc:trino://localhost:8080/iceberg",
    "trino-user",
    null
);
```

#### Python Connection (trino-python-client)

```python
import trino

conn = trino.dbapi.connect(
    host='localhost',
    port=8080,
    user='trino-user',
    catalog='iceberg',
    schema='default',
)
```

#### Available Catalogs

- `iceberg` - Iceberg tables via Nessie
- `system` - System information

#### REST API

```bash
# Server info
curl http://localhost:8080/v1/info

# Query execution
curl -X POST http://localhost:8080/v1/statement \
  -H "X-Trino-User: trino-user" \
  -d "SHOW CATALOGS"

# Cluster stats
curl http://localhost:8080/v1/cluster
```

---

### Apache Spark

**Master Container**: `docker-spark-master`  
**Worker Container**: `docker-spark-worker`

#### Spark Master

- **RPC URL**: spark://docker-spark-master:7077
- **Web UI**: http://localhost:8081 (external), http://docker-spark-master:8080 (internal)
- **REST API**: http://localhost:6066

#### Spark Worker

- **Web UI**: http://localhost:8082
- **Status**: Visible in master UI

#### Spark Submit

```bash
# Inside container
docker exec docker-spark-master spark-submit \
  --master spark://docker-spark-master:7077 \
  --class org.example.MyApp \
  /path/to/app.jar

# External submission (if exposed)
spark-submit \
  --master spark://localhost:7077 \
  --deploy-mode client \
  --class org.example.MyApp \
  app.jar
```

#### Spark Shell (Scala)

```bash
# Interactive Scala shell
docker exec -it docker-spark-master spark-shell \
  --master spark://docker-spark-master:7077

# With Iceberg
spark-shell \
  --master spark://docker-spark-master:7077 \
  --conf spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.iceberg.catalog-impl=org.apache.iceberg.nessie.NessieCatalog \
  --conf spark.sql.catalog.iceberg.uri=http://docker-nessie:19120/api/v2
```

#### PySpark Shell

```bash
docker exec -it docker-spark-master pyspark \
  --master spark://docker-spark-master:7077
```

#### Application Monitoring

- **Spark History Server**: Not included by default (add if needed)
- **Job Metrics**: Available in master UI
- **Executor Logs**: http://localhost:8082 (worker UI)

---

## Streaming Services

### Apache Kafka

**Container Name**: `docker-kafka`

#### Broker Connection

- **Bootstrap Servers**: `docker-kafka:9092` (internal), `localhost:9092` (external)
- **Protocol**: PLAINTEXT (no SSL by default)
- **Default Topics**: Auto-created as needed

#### Producer Example

```bash
# Console producer
docker exec -it docker-kafka kafka-console-producer \
  --bootstrap-server docker-kafka:9092 \
  --topic test-topic

# Python (kafka-python)
from kafka import KafkaProducer
producer = KafkaProducer(bootstrap_servers=['localhost:9092'])
producer.send('test-topic', b'Hello World')
```

#### Consumer Example

```bash
# Console consumer
docker exec -it docker-kafka kafka-console-consumer \
  --bootstrap-server docker-kafka:9092 \
  --topic test-topic \
  --from-beginning

# Python (kafka-python)
from kafka import KafkaConsumer
consumer = KafkaConsumer('test-topic', bootstrap_servers=['localhost:9092'])
for message in consumer:
    print(message.value)
```

#### Topic Management

```bash
# List topics
docker exec docker-kafka kafka-topics \
  --bootstrap-server docker-kafka:9092 \
  --list

# Create topic
docker exec docker-kafka kafka-topics \
  --bootstrap-server docker-kafka:9092 \
  --create \
  --topic my-topic \
  --partitions 3 \
  --replication-factor 1

# Describe topic
docker exec docker-kafka kafka-topics \
  --bootstrap-server docker-kafka:9092 \
  --describe \
  --topic my-topic
```

#### Consumer Groups

```bash
# List consumer groups
docker exec docker-kafka kafka-consumer-groups \
  --bootstrap-server docker-kafka:9092 \
  --list

# Describe group
docker exec docker-kafka kafka-consumer-groups \
  --bootstrap-server docker-kafka:9092 \
  --describe \
  --group my-group
```

---

### Schema Registry

**Container Name**: `docker-schema-registry`

#### REST API

- **URL**: http://localhost:8081
- **Internal URL**: http://docker-schema-registry:8081
- **API Version**: v1
- **Content-Type**: `application/vnd.schemaregistry.v1+json`

#### API Operations

**Subjects & Schemas**

```bash
# List subjects
curl http://localhost:8081/subjects

# Get schema versions
curl http://localhost:8081/subjects/my-topic-value/versions

# Get specific version
curl http://localhost:8081/subjects/my-topic-value/versions/1

# Register new schema
curl -X POST http://localhost:8081/subjects/my-topic-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"schema": "{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"}]}"}'

# Check compatibility
curl -X POST http://localhost:8081/compatibility/subjects/my-topic-value/versions/latest \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"schema": "..."}'
```

**Configuration**

```bash
# Get global config
curl http://localhost:8081/config

# Set compatibility level
curl -X PUT http://localhost:8081/config \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"compatibility": "BACKWARD"}'

# Subject-specific compatibility
curl -X PUT http://localhost:8081/config/my-topic-value \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"compatibility": "FULL"}'
```

#### Compatibility Modes

- `BACKWARD` - New schema can read old data
- `FORWARD` - Old schema can read new data
- `FULL` - Both backward and forward compatible
- `NONE` - No compatibility checks

---

### Kafka UI

**Container Name**: `docker-kafka-ui`

#### Web Interface

- **URL**: http://localhost:8083
- **Authentication**: None (by default)

#### Features

- **Brokers**: View broker status, configs
- **Topics**: Create, view, delete topics
- **Consumers**: Monitor consumer groups, lag
- **Messages**: Browse messages, publish test messages
- **Schemas**: View Schema Registry schemas
- **Connect**: Manage Kafka Connect connectors

---

### Apache Zookeeper

**Container Name**: `docker-zookeeper`

#### Connection

- **Host**: `docker-zookeeper:2181`
- **Protocol**: Zookeeper native protocol
- **CLI Tool**: `zkCli.sh`

#### ZK CLI Access

```bash
# Connect to Zookeeper
docker exec -it docker-zookeeper zkCli.sh -server localhost:2181

# List nodes
ls /

# Get Kafka broker IDs
ls /brokers/ids

# Get topic list
ls /brokers/topics
```

---

## Monitoring Services

### Prometheus

**Container Name**: `docker-prometheus` (when added)

#### Web Interface

- **URL**: http://localhost:9090
- **Features**:
  - Query interface
  - Target status
  - Alert manager
  - Configuration

#### API Endpoints

```bash
# Query API
curl 'http://localhost:9090/api/v1/query?query=up'

# Query range
curl 'http://localhost:9090/api/v1/query_range?query=up&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'

# Targets status
curl http://localhost:9090/api/v1/targets

# Alert status
curl http://localhost:9090/api/v1/alerts

# Rules
curl http://localhost:9090/api/v1/rules
```

#### PromQL Examples

```promql
# Service uptime
up{job="nessie"}

# Memory usage
container_memory_usage_bytes{container_name="docker-trino"}

# Query rate
rate(trino_execution_QueryManager_CompletedQueries[5m])

# Kafka consumer lag
kafka_consumergroup_lag{consumergroup="my-group"}
```

---

### Grafana

**Container Name**: `docker-grafana` (when added)

#### Web Interface

- **URL**: http://localhost:3000
- **Default Login**:
  - Username: `admin`
  - Password: `admin` (prompts to change on first login)

#### API Access

```bash
# Get API key (requires auth)
curl -X POST http://localhost:3000/api/auth/keys \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d '{"name":"my-key","role":"Admin"}'

# List datasources
curl http://localhost:3000/api/datasources \
  -H "Authorization: Bearer <api-key>"

# Create dashboard
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d @dashboard.json
```

#### Pre-configured Datasources

- Prometheus (if configured)

---

## Health Check Endpoints

### Quick Health Check Script

```bash
#!/bin/bash
# check-all-services.sh

echo "🏥 ShuDL Health Check"
echo "===================="

# PostgreSQL
if docker exec docker-postgresql pg_isready -U nessie &>/dev/null; then
  echo "✅ PostgreSQL: Healthy"
else
  echo "❌ PostgreSQL: Unhealthy"
fi

# MinIO
if curl -sf http://localhost:9000/minio/health/live &>/dev/null; then
  echo "✅ MinIO: Healthy"
else
  echo "❌ MinIO: Unhealthy"
fi

# Nessie
if curl -sf http://localhost:19120/q/health/live &>/dev/null; then
  echo "✅ Nessie: Healthy"
else
  echo "❌ Nessie: Unhealthy"
fi

# Trino
if curl -sf http://localhost:8080/v1/info &>/dev/null; then
  echo "✅ Trino: Healthy"
else
  echo "❌ Trino: Unhealthy"
fi

# Kafka
if docker exec docker-kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9092 &>/dev/null; then
  echo "✅ Kafka: Healthy"
else
  echo "❌ Kafka: Unhealthy"
fi

# Schema Registry
if curl -sf http://localhost:8081/subjects &>/dev/null; then
  echo "✅ Schema Registry: Healthy"
else
  echo "❌ Schema Registry: Unhealthy"
fi
```

### Individual Health Checks

| Service         | Health Check Command                                                                   |
| --------------- | -------------------------------------------------------------------------------------- |
| PostgreSQL      | `docker exec docker-postgresql pg_isready -U nessie`                                   |
| MinIO           | `curl http://localhost:9000/minio/health/live`                                         |
| Nessie          | `curl http://localhost:19120/q/health/live`                                            |
| Trino           | `curl http://localhost:8080/v1/info`                                                   |
| Kafka           | `docker exec docker-kafka kafka-broker-api-versions --bootstrap-server localhost:9092` |
| Zookeeper       | `echo ruok \| nc localhost 2181`                                                       |
| Schema Registry | `curl http://localhost:8081/subjects`                                                  |

---

## Metrics Endpoints

### Prometheus Scrape Targets

| Service      | Metrics Path                | Port  | Format        |
| ------------ | --------------------------- | ----- | ------------- |
| MinIO        | `/minio/v2/metrics/cluster` | 9000  | Prometheus    |
| Nessie       | `/q/metrics`                | 19120 | Prometheus    |
| Trino        | `/v1/info`                  | 8080  | JSON (custom) |
| Spark Master | `/metrics/json`             | 8080  | JSON          |
| Spark Worker | `/metrics/json`             | 8081  | JSON          |

### Example Metrics Queries

```bash
# MinIO metrics
curl http://localhost:9000/minio/v2/metrics/cluster

# Nessie metrics
curl http://localhost:19120/q/metrics

# Trino info
curl http://localhost:8080/v1/info | jq

# Spark master metrics
curl http://localhost:8081/metrics/json | jq
```

---

## API Documentation

### Official Documentation Links

| Service         | Documentation URL                                                        |
| --------------- | ------------------------------------------------------------------------ |
| PostgreSQL      | https://www.postgresql.org/docs/16/                                      |
| MinIO           | https://min.io/docs/minio/linux/reference/minio-server/minio-server.html |
| Nessie          | https://projectnessie.org/nessie-latest/                                 |
| Apache Iceberg  | https://iceberg.apache.org/docs/latest/                                  |
| Trino           | https://trino.io/docs/current/                                           |
| Spark           | https://spark.apache.org/docs/latest/                                    |
| Kafka           | https://kafka.apache.org/documentation/                                  |
| Schema Registry | https://docs.confluent.io/platform/current/schema-registry/              |

### Swagger/OpenAPI Endpoints

| Service | Swagger UI                          | OpenAPI Spec                     |
| ------- | ----------------------------------- | -------------------------------- |
| Nessie  | http://localhost:19120/q/swagger-ui | http://localhost:19120/q/openapi |

---

## Security Considerations

### Network Security

- All services on same Docker network by default
- External exposure via port mapping
- **Production**: Use firewalls, VPNs, or service mesh

### Authentication

- PostgreSQL: Password-based (MD5)
- MinIO: AWS SigV4
- Nessie: Configurable (NONE/BEARER/AWS/BASIC)
- Trino: None by default (configure password auth)
- Kafka: PLAINTEXT by default (configure SASL/SSL)

### TLS/SSL

- Not enabled by default
- **Production Setup Required**:
  - Generate certificates
  - Configure each service for TLS
  - Update client connections

---

## Quick Command Reference

```bash
# Check all service status
docker compose ps

# View service logs
docker compose logs -f <service-name>

# Restart service
docker compose restart <service-name>

# Execute command in service
docker exec -it docker-<service> <command>

# Scale workers
docker compose up -d --scale spark-worker=3

# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v
```

---

## References

- [Environment Variables Reference](environment-variables.md)
- [Configuration Management Guide](../operations/configuration.md)
- [Troubleshooting Guide](../operations/troubleshooting.md)
- [Monitoring Guide](../operations/monitoring.md)

---

**Last Updated**: 2024-11-26  
**Version**: 1.0.0  
**Services Covered**: 15
