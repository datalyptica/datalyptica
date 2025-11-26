# ShuDL Environment Variables Reference

Complete reference for all ShuDL environment variables across all services.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Project Configuration](#project-configuration)
- [Network Configuration](#network-configuration)
- [PostgreSQL Configuration](#postgresql-configuration)
- [MinIO Configuration](#minio-configuration)
- [Nessie Configuration](#nessie-configuration)
- [Trino Configuration](#trino-configuration)
- [Spark Configuration](#spark-configuration)
- [Kafka Configuration](#kafka-configuration)
- [Schema Registry Configuration](#schema-registry-configuration)
- [Zookeeper Configuration](#zookeeper-configuration)
- [Flink Configuration](#flink-configuration)
- [Kafka Connect Configuration](#kafka-connect-configuration)
- [ClickHouse Configuration](#clickhouse-configuration)
- [DBT Configuration](#dbt-configuration)
- [Monitoring Configuration](#monitoring-configuration)
- [Health Check Configuration](#health-check-configuration)

## Quick Reference

### Critical Variables (Must Change in Production)

| Variable                       | Default       | Description            | Security Risk |
| ------------------------------ | ------------- | ---------------------- | ------------- |
| `POSTGRES_PASSWORD`            | `changeme123` | PostgreSQL password    | **CRITICAL**  |
| `MINIO_ROOT_PASSWORD`          | `changeme123` | MinIO root password    | **CRITICAL**  |
| `PATRONI_API_PASSWORD`         | `changeme123` | Patroni API password   | **HIGH**      |
| `PATRONI_REPLICATION_PASSWORD` | `changeme123` | Replication password   | **HIGH**      |
| `GRAFANA_ADMIN_PASSWORD`       | `admin`       | Grafana admin password | **HIGH**      |

### Required Variables

| Variable               | Description                       | Services Affected   |
| ---------------------- | --------------------------------- | ------------------- |
| `COMPOSE_PROJECT_NAME` | Docker Compose project identifier | All                 |
| `NETWORK_NAME`         | Docker network name               | All                 |
| `POSTGRES_DB`          | PostgreSQL database name          | PostgreSQL, Nessie  |
| `POSTGRES_USER`        | PostgreSQL username               | PostgreSQL, Nessie  |
| `MINIO_ROOT_USER`      | MinIO admin username              | MinIO, Trino, Spark |
| `MINIO_BUCKET_NAME`    | Default S3 bucket                 | MinIO, Trino, Spark |

---

## Project Configuration

### COMPOSE_PROJECT_NAME

- **Description**: Docker Compose project name used as container prefix
- **Default**: `shudl`
- **Valid Values**: Alphanumeric string, lowercase recommended
- **Required**: Yes
- **Example**: `shudl-prod`, `shudl-staging`
- **Used By**: All services (container naming)
- **Impact**: Changes container names, network names, volume names

### SHUDL_VERSION

- **Description**: ShuDL Docker image version tag
- **Default**: `v1.0.0`
- **Valid Values**: Valid Docker image tag (e.g., `v1.0.0`, `latest`, `dev`)
- **Required**: No (defaults to v1.0.0)
- **Example**: `v1.1.0`, `v2.0.0-beta`
- **Used By**: All services (image selection)

### ENVIRONMENT

- **Description**: Deployment environment identifier
- **Default**: `development`
- **Valid Values**: `development`, `testing`, `staging`, `production`
- **Required**: No
- **Example**: `production`
- **Used By**: Logging, monitoring, alerting
- **Impact**: Affects log levels, alert thresholds, resource allocation

---

## Network Configuration

### NETWORK_NAME

- **Description**: Docker network name for service communication
- **Default**: `shunetwork`
- **Valid Values**: Valid Docker network name
- **Required**: Yes
- **Example**: `shudl-network`, `lakehouse-net`
- **Used By**: All services
- **Impact**: Service discovery, network isolation

### NETWORK_DRIVER

- **Description**: Docker network driver type
- **Default**: `bridge`
- **Valid Values**: `bridge`, `overlay`, `host`
- **Required**: No
- **Example**: `overlay` (for multi-host)
- **Used By**: Docker network creation

### NETWORK_SUBNET

- **Description**: Docker network CIDR block
- **Default**: `172.18.0.0/16`
- **Valid Values**: Valid CIDR notation
- **Required**: No
- **Example**: `10.0.0.0/16`
- **Used By**: Docker network IP allocation

---

## PostgreSQL Configuration

### Core Settings

#### POSTGRES_DB

- **Description**: Default database name
- **Default**: `nessie`
- **Valid Values**: Valid PostgreSQL database name
- **Required**: Yes
- **Example**: `lakehouse_catalog`
- **Used By**: PostgreSQL, Nessie
- **Security**: Low risk (publicly visible)

#### POSTGRES_USER

- **Description**: PostgreSQL superuser username
- **Default**: `nessie`
- **Valid Values**: Valid PostgreSQL username
- **Required**: Yes
- **Example**: `lakehouse_admin`
- **Used By**: PostgreSQL, Nessie
- **Security**: Low risk (username)

#### POSTGRES_PASSWORD

- **Description**: PostgreSQL superuser password
- **Default**: `changeme123`
- **Valid Values**: Any string (min 12 chars recommended)
- **Required**: Yes
- **Example**: Generated: `$(openssl rand -base64 32)`
- **Used By**: PostgreSQL, Nessie
- **Security**: **CRITICAL** - Must change in production
- **Rotation**: Recommended every 90 days

#### POSTGRES_PORT

- **Description**: PostgreSQL external port
- **Default**: `5432`
- **Valid Values**: 1024-65535
- **Required**: Yes
- **Example**: `5433`, `15432`
- **Used By**: External clients, backup scripts

### Connection Settings

#### POSTGRES_MAX_CONNECTIONS

- **Description**: Maximum concurrent connections
- **Default**: `200`
- **Valid Values**: 20-10000 (depends on RAM)
- **Required**: No
- **Example**: `500` (production), `100` (dev)
- **Tuning**: 100 connections ≈ 100MB RAM
- **Calculation**: `max_connections = available_ram_mb / 10`

#### POSTGRES_LISTEN_ADDRESSES

- **Description**: IP addresses to listen on
- **Default**: `*` (all interfaces)
- **Valid Values**: IP address or `*`
- **Required**: No
- **Example**: `0.0.0.0`, `172.18.0.0/16`
- **Security**: Use specific IPs in production

### Memory Settings

#### POSTGRES_SHARED_BUFFERS

- **Description**: PostgreSQL shared memory buffer cache
- **Default**: `256MB`
- **Valid Values**: Memory size (KB, MB, GB)
- **Required**: No
- **Example**: `4GB` (production), `128MB` (dev)
- **Tuning**: 25% of system RAM (up to 8GB)
- **Impact**: Higher = better read performance

#### POSTGRES_EFFECTIVE_CACHE_SIZE

- **Description**: Planner's estimate of OS cache
- **Default**: `1GB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `16GB` (production)
- **Tuning**: 50-75% of system RAM
- **Impact**: Query planning optimization

#### POSTGRES_WORK_MEM

- **Description**: Memory per query operation
- **Default**: `8MB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `64MB` (production), `4MB` (dev)
- **Tuning**: `total_ram / (max_connections * 3)`
- **Impact**: Sort/hash operations performance
- **Warning**: Too high can cause OOM

#### POSTGRES_MAINTENANCE_WORK_MEM

- **Description**: Memory for maintenance operations
- **Default**: `128MB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `2GB` (production)
- **Tuning**: 5-10% of system RAM
- **Used For**: VACUUM, CREATE INDEX, ALTER TABLE

### Write-Ahead Log (WAL)

#### POSTGRES_WAL_LEVEL

- **Description**: WAL verbosity for replication
- **Default**: `replica`
- **Valid Values**: `minimal`, `replica`, `logical`
- **Required**: No
- **Example**: `logical` (CDC required)
- **Impact**: Replication and point-in-time recovery

#### POSTGRES_MAX_WAL_SIZE

- **Description**: Maximum WAL size before checkpoint
- **Default**: `2GB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `4GB` (production)
- **Impact**: Write performance, recovery time

#### POSTGRES_MIN_WAL_SIZE

- **Description**: Minimum WAL size to retain
- **Default**: `1GB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `2GB`

#### POSTGRES_CHECKPOINT_COMPLETION_TARGET

- **Description**: Fraction of checkpoint interval for completion
- **Default**: `0.9`
- **Valid Values**: 0.0 to 1.0
- **Required**: No
- **Example**: `0.9`
- **Impact**: I/O smoothing

### Authentication

#### POSTGRES_AUTH_LOCAL

- **Description**: Authentication method for local connections
- **Default**: `trust`
- **Valid Values**: `trust`, `md5`, `scram-sha-256`, `peer`
- **Required**: No
- **Example**: `md5` (production)
- **Security**: Use `md5` or `scram-sha-256` in production

#### POSTGRES_AUTH_HOST_IPV4

- **Description**: Authentication for IPv4 TCP/IP connections
- **Default**: `md5`
- **Valid Values**: `trust`, `md5`, `scram-sha-256`, `reject`
- **Required**: No
- **Security**: Never use `trust` in production

#### POSTGRES_ALLOWED_NETWORKS

- **Description**: Allowed CIDR blocks for connections
- **Default**: `172.18.0.0/16,10.0.0.0/8`
- **Valid Values**: Comma-separated CIDR blocks
- **Required**: No
- **Example**: `172.18.0.0/16,192.168.1.0/24`
- **Security**: Restrict to Docker networks only

### Additional Databases

#### SHUDL_DB

- **Description**: ShuDL application database name
- **Default**: `shudl`
- **Valid Values**: Valid database name
- **Required**: No
- **Used By**: ShuDL installer/manager

#### NESSIE_DB

- **Description**: Nessie catalog database name (alias)
- **Default**: Same as `POSTGRES_DB`
- **Valid Values**: Valid database name
- **Required**: No
- **Used By**: Nessie service

---

## MinIO Configuration

### Core Settings

#### MINIO_ROOT_USER

- **Description**: MinIO admin username
- **Default**: `admin`
- **Valid Values**: Alphanumeric string (min 3 chars)
- **Required**: Yes
- **Example**: `lakehouse_admin`
- **Used By**: MinIO, Trino, Spark (as S3_ACCESS_KEY)
- **Security**: Change from default

#### MINIO_ROOT_PASSWORD

- **Description**: MinIO admin password
- **Default**: `changeme123`
- **Valid Values**: String (min 8 chars)
- **Required**: Yes
- **Example**: Generated: `$(openssl rand -base64 32)`
- **Used By**: MinIO, Trino, Spark (as S3_SECRET_KEY)
- **Security**: **CRITICAL** - Must change in production
- **Rotation**: Recommended every 90 days

#### MINIO_BUCKET_NAME

- **Description**: Default S3 bucket name
- **Default**: `lakehouse`
- **Valid Values**: Valid S3 bucket name (lowercase, no underscores)
- **Required**: Yes
- **Example**: `data-lakehouse`, `iceberg-warehouse`
- **Used By**: MinIO, Trino, Spark

#### MINIO_REGION

- **Description**: S3 region identifier
- **Default**: `us-east-1`
- **Valid Values**: AWS region name format
- **Required**: No
- **Example**: `eu-west-1`, `ap-south-1`
- **Used By**: MinIO, S3 clients

### Port Configuration

#### MINIO_API_PORT

- **Description**: MinIO API external port
- **Default**: `9000`
- **Valid Values**: 1024-65535
- **Required**: Yes
- **Example**: `9000`, `19000`
- **Used By**: S3 API clients

#### MINIO_CONSOLE_PORT

- **Description**: MinIO web console port
- **Default**: `9001`
- **Valid Values**: 1024-65535
- **Required**: Yes
- **Example**: `9001`, `19001`
- **Used By**: Web browser access

### Advanced Settings

#### MINIO_ADDRESS

- **Description**: MinIO API bind address
- **Default**: `:9000`
- **Valid Values**: `:<port>` or `<ip>:<port>`
- **Required**: No
- **Example**: `0.0.0.0:9000`

#### MINIO_CONSOLE_ADDRESS

- **Description**: Console bind address
- **Default**: `:9001`
- **Valid Values**: `:<port>` or `<ip>:<port>`
- **Required**: No

#### MINIO_VOLUMES

- **Description**: Storage volumes path
- **Default**: `/data`
- **Valid Values**: Valid filesystem path
- **Required**: No
- **Example**: `/minio/data`

#### MINIO_LOG_LEVEL

- **Description**: Logging level
- **Default**: `info`
- **Valid Values**: `debug`, `info`, `warn`, `error`
- **Required**: No
- **Example**: `warn` (production)

#### MINIO_BROWSER

- **Description**: Enable/disable web console
- **Default**: `on`
- **Valid Values**: `on`, `off`
- **Required**: No
- **Security**: Set to `off` if not needed

#### MINIO_COMPRESS

- **Description**: Enable compression for uploads
- **Default**: `off`
- **Valid Values**: `on`, `off`
- **Required**: No
- **Example**: `on` (saves storage)
- **Impact**: CPU vs. storage tradeoff

#### MINIO_COMPRESS_MIME_TYPES

- **Description**: MIME types to compress
- **Default**: `text/*,application/json,application/xml`
- **Valid Values**: Comma-separated MIME types
- **Required**: No (if compression enabled)

---

## Nessie Configuration

### Core Settings

#### NESSIE_URI

- **Description**: Nessie catalog API endpoint
- **Default**: `http://docker-nessie:19120/api/v2`
- **Valid Values**: Valid HTTP/HTTPS URL
- **Required**: Yes
- **Example**: `https://nessie.example.com/api/v2`
- **Used By**: Trino, Spark (catalog connection)

#### NESSIE_REF

- **Description**: Default branch/tag reference
- **Default**: `main`
- **Valid Values**: Valid Git-like reference name
- **Required**: No
- **Example**: `main`, `develop`, `v1.0`
- **Used By**: Trino, Spark (catalog operations)

#### NESSIE_AUTH_TYPE

- **Description**: Authentication method
- **Default**: `NONE`
- **Valid Values**: `NONE`, `BEARER`, `AWS`, `BASIC`
- **Required**: No
- **Example**: `BEARER` (production)
- **Security**: Use `BEARER` or `AWS` in production

### Database Connection

#### NESSIE_DB_HOST

- **Description**: PostgreSQL hostname
- **Default**: Same as `POSTGRES_HOST`
- **Valid Values**: Hostname or IP
- **Required**: Yes
- **Example**: `docker-postgresql`

#### NESSIE_DB_PORT

- **Description**: PostgreSQL port
- **Default**: `5432`
- **Valid Values**: 1024-65535
- **Required**: Yes

#### NESSIE_DB_NAME

- **Description**: Nessie database name
- **Default**: Same as `POSTGRES_DB`
- **Valid Values**: Valid database name
- **Required**: Yes

#### NESSIE_DB_USER

- **Description**: Database username
- **Default**: Same as `POSTGRES_USER`
- **Valid Values**: Valid username
- **Required**: Yes

#### NESSIE_DB_PASSWORD

- **Description**: Database password
- **Default**: Same as `POSTGRES_PASSWORD`
- **Valid Values**: String
- **Required**: Yes
- **Security**: Inherits from POSTGRES_PASSWORD

### Monitoring

#### NESSIE_MICROMETER_EXPORT_PROMETHEUS_ENABLED

- **Description**: Enable Prometheus metrics export
- **Default**: `true`
- **Valid Values**: `true`, `false`
- **Required**: No
- **Used By**: Prometheus scraper

---

## Trino Configuration

### Core Settings

#### TRINO_PORT

- **Description**: Trino coordinator HTTP port
- **Default**: `8080`
- **Valid Values**: 1024-65535
- **Required**: Yes
- **Example**: `8080`, `18080`

#### TRINO_DISCOVERY_URI

- **Description**: Trino discovery service URI
- **Default**: `http://docker-trino:8080`
- **Valid Values**: Valid HTTP URL
- **Required**: Yes
- **Example**: `http://trino.example.com:8080`

### Memory Configuration

#### TRINO_MEMORY_HEAP_SIZE

- **Description**: JVM heap size
- **Default**: `8G`
- **Valid Values**: Memory size (G)
- **Required**: No
- **Example**: `16G` (production), `4G` (dev)
- **Tuning**: 70% of container memory limit

#### TRINO_QUERY_MAX_MEMORY

- **Description**: Maximum memory per query
- **Default**: `4GB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `8GB` (production)
- **Impact**: Large query capability

#### TRINO_MEMORY_HEAP_HEADROOM

- **Description**: Memory reserved outside heap
- **Default**: `1GB`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `2GB`
- **Calculation**: 15-20% of heap size

---

## Spark Configuration

### Master Settings

#### SPARK_MASTER_URL

- **Description**: Spark master URL
- **Default**: `spark://docker-spark-master:7077`
- **Valid Values**: `spark://<host>:<port>`
- **Required**: Yes
- **Example**: `spark://spark-master.example.com:7077`
- **Used By**: Spark workers, clients

#### SPARK_MASTER_PORT

- **Description**: Spark master RPC port
- **Default**: `7077`
- **Valid Values**: 1024-65535
- **Required**: Yes

#### SPARK_MASTER_WEBUI_PORT

- **Description**: Spark master web UI port
- **Default**: `8080`
- **Valid Values**: 1024-65535
- **Required**: No
- **Example**: `8081` (avoid Trino conflict)

### Worker Settings

#### SPARK_WORKER_CORES

- **Description**: CPU cores per worker
- **Default**: `4`
- **Valid Values**: 1 to available cores
- **Required**: No
- **Example**: `8` (production), `2` (dev)
- **Tuning**: Leave 1-2 cores for OS

#### SPARK_WORKER_MEMORY

- **Description**: Memory per worker
- **Default**: `4G`
- **Valid Values**: Memory size (G, M)
- **Required**: No
- **Example**: `16G` (production), `2G` (dev)
- **Tuning**: 75% of worker node RAM

### Executor Settings

#### SPARK_DRIVER_MEMORY

- **Description**: Spark driver memory
- **Default**: `2G`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `8G` (large jobs)

#### SPARK_EXECUTOR_MEMORY

- **Description**: Executor memory per instance
- **Default**: `2G`
- **Valid Values**: Memory size
- **Required**: No
- **Example**: `8G` (production)

#### SPARK_EXECUTOR_CORES

- **Description**: Cores per executor
- **Default**: `2`
- **Valid Values**: 1 to worker cores
- **Required**: No
- **Example**: `4`

#### SPARK_EXECUTOR_INSTANCES

- **Description**: Number of executor instances
- **Default**: `2`
- **Valid Values**: Positive integer
- **Required**: No
- **Example**: `8` (production)
- **Calculation**: `worker_cores / executor_cores`

### Iceberg Catalog

#### SPARK_ICEBERG_CATALOG_NAME

- **Description**: Iceberg catalog identifier
- **Default**: `iceberg`
- **Valid Values**: Valid catalog name
- **Required**: Yes
- **Example**: `lakehouse`, `prod_catalog`

#### SPARK_ICEBERG_REF

- **Description**: Nessie branch reference
- **Default**: `main`
- **Valid Values**: Branch/tag name
- **Required**: No

#### SPARK_ICEBERG_URI

- **Description**: Nessie API URI
- **Default**: Same as `NESSIE_URI`
- **Valid Values**: Valid HTTP URL
- **Required**: Yes

#### SPARK_ICEBERG_WAREHOUSE

- **Description**: Warehouse S3 path
- **Default**: `s3a://${MINIO_BUCKET_NAME}/warehouse`
- **Valid Values**: S3 URI
- **Required**: Yes
- **Example**: `s3a://lakehouse/warehouse`

---

## Kafka Configuration

### Broker Settings

#### KAFKA_BROKER_ID

- **Description**: Unique broker identifier
- **Default**: `1`
- **Valid Values**: Positive integer
- **Required**: Yes
- **Example**: `1`, `2`, `3` (multi-broker)

#### KAFKA_ZOOKEEPER_CONNECT

- **Description**: Zookeeper connection string
- **Default**: `docker-zookeeper:2181`
- **Valid Values**: `<host>:<port>[,...]`
- **Required**: Yes
- **Example**: `zk1:2181,zk2:2181,zk3:2181`

#### KAFKA_ADVERTISED_LISTENERS

- **Description**: Advertised listener URLs
- **Default**: `PLAINTEXT://docker-kafka:9092`
- **Valid Values**: `<protocol>://<host>:<port>`
- **Required**: Yes
- **Example**: `PLAINTEXT://kafka.example.com:9092`
- **Security**: Use SSL in production

### Topic Settings

#### KAFKA_NUM_PARTITIONS

- **Description**: Default partitions per topic
- **Default**: `3`
- **Valid Values**: 1 to 10000
- **Required**: No
- **Example**: `12` (production)
- **Tuning**: Multiples of broker count

#### KAFKA_DEFAULT_REPLICATION_FACTOR

- **Description**: Default replication factor
- **Default**: `1`
- **Valid Values**: 1 to broker count
- **Required**: No
- **Example**: `3` (production HA)
- **Security**: Min 2 for durability

#### KAFKA_LOG_RETENTION_HOURS

- **Description**: Log retention period
- **Default**: `168` (7 days)
- **Valid Values**: Positive integer (hours)
- **Required**: No
- **Example**: `720` (30 days), `2160` (90 days)
- **Impact**: Storage requirements

#### KAFKA_LOG_SEGMENT_BYTES

- **Description**: Log segment file size
- **Default**: `1073741824` (1GB)
- **Valid Values**: Bytes
- **Required**: No
- **Example**: `536870912` (512MB)

---

## Schema Registry Configuration

#### SCHEMA_REGISTRY_HOST

- **Description**: Schema Registry hostname
- **Default**: `docker-schema-registry`
- **Valid Values**: Hostname
- **Required**: Yes

#### SCHEMA_REGISTRY_PORT

- **Description**: Schema Registry HTTP port
- **Default**: `8081`
- **Valid Values**: 1024-65535
- **Required**: Yes

#### SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS

- **Description**: Kafka bootstrap servers
- **Default**: `docker-kafka:9092`
- **Valid Values**: `<host>:<port>[,...]`
- **Required**: Yes

---

## Monitoring Configuration

### Prometheus

#### PROMETHEUS_PORT

- **Description**: Prometheus HTTP port
- **Default**: `9090`
- **Valid Values**: 1024-65535
- **Required**: No

#### PROMETHEUS_RETENTION_TIME

- **Description**: Metrics retention period
- **Default**: `15d`
- **Valid Values**: Time duration (d, h, m)
- **Required**: No
- **Example**: `30d` (production)

#### PROMETHEUS_SCRAPE_INTERVAL

- **Description**: Default scrape interval
- **Default**: `15s`
- **Valid Values**: Time duration
- **Required**: No
- **Example**: `30s` (lower load)

### Grafana

#### GRAFANA_PORT

- **Description**: Grafana HTTP port
- **Default**: `3000`
- **Valid Values**: 1024-65535
- **Required**: No

#### GRAFANA_ADMIN_USER

- **Description**: Grafana admin username
- **Default**: `admin`
- **Valid Values**: String
- **Required**: No
- **Security**: Change in production

#### GRAFANA_ADMIN_PASSWORD

- **Description**: Grafana admin password
- **Default**: `admin`
- **Valid Values**: String (min 4 chars)
- **Required**: No
- **Security**: **HIGH** - Change immediately

---

## Health Check Configuration

#### HEALTHCHECK_INTERVAL

- **Description**: Health check execution interval
- **Default**: `30s`
- **Valid Values**: Duration (s, m)
- **Required**: No
- **Example**: `15s` (more responsive), `60s` (lower load)

#### HEALTHCHECK_TIMEOUT

- **Description**: Health check timeout
- **Default**: `10s`
- **Valid Values**: Duration (s)
- **Required**: No
- **Example**: `5s`

#### HEALTHCHECK_RETRIES

- **Description**: Retries before marking unhealthy
- **Default**: `3`
- **Valid Values**: Positive integer
- **Required**: No
- **Example**: `5` (more tolerant)

#### HEALTHCHECK_START_PERIOD

- **Description**: Grace period before checks start
- **Default**: `60s`
- **Valid Values**: Duration (s, m)
- **Required**: No
- **Example**: `120s` (slow startup services)

---

## Variable Templates

### Development Environment

```bash
# Minimal security, maximum convenience
COMPOSE_PROJECT_NAME=shudl-dev
POSTGRES_PASSWORD=devpass123
MINIO_ROOT_PASSWORD=devpass123
POSTGRES_MAX_CONNECTIONS=50
TRINO_MEMORY_HEAP_SIZE=4G
SPARK_WORKER_MEMORY=2G
```

### Production Environment

```bash
# Maximum security and performance
COMPOSE_PROJECT_NAME=shudl-prod
POSTGRES_PASSWORD=$(openssl rand -base64 32)
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
POSTGRES_MAX_CONNECTIONS=500
POSTGRES_SHARED_BUFFERS=4GB
TRINO_MEMORY_HEAP_SIZE=16G
SPARK_WORKER_MEMORY=16G
NESSIE_AUTH_TYPE=BEARER
```

---

## References

- [Configuration Management Guide](../operations/configuration.md)
- [Service Endpoints Reference](service-endpoints.md)
- [Troubleshooting Guide](../operations/troubleshooting.md)

---

**Last Updated**: 2024-11-26  
**Version**: 1.0.0  
**Total Variables**: 160+
