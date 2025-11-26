# ShuDL Configuration Management Guide

Complete guide to managing ShuDL configuration across all deployment environments.

## Table of Contents

- [Overview](#overview)
- [Configuration Architecture](#configuration-architecture)
- [Environment Variables](#environment-variables)
- [Configuration Files](#configuration-files)
- [Secrets Management](#secrets-management)
- [Configuration Validation](#configuration-validation)
- [Configuration Templates](#configuration-templates)
- [Best Practices](#best-practices)
- [Configuration Change Process](#configuration-change-process)
- [Troubleshooting](#troubleshooting)

## Overview

### Configuration Principles

ShuDL follows the **Twelve-Factor App** methodology for configuration:

- **Environment-based**: All configuration via environment variables
- **Separation of Concerns**: Config separate from code
- **Security**: Secrets never in version control
- **Validation**: Configuration validated before deployment
- **Documentation**: Every parameter documented with examples

### Configuration Hierarchy

```
1. Environment Variables (.env file)          [Highest Priority]
2. Docker Compose Environment Section
3. Service Configuration Files (mounted)
4. Default Values (in service images)         [Lowest Priority]
```

### Configuration Scope

- **160+ Parameters**: Complete system configuration
- **15 Services**: All services fully configurable
- **Multiple Environments**: Dev, test, staging, production
- **Security Layers**: Credentials, certificates, access control

## Configuration Architecture

### Directory Structure

```
shudl/
├── .env                          # Main environment variables (DO NOT COMMIT)
├── .env.example                  # Example with safe defaults
├── docker-compose.yml            # Service orchestration
├── configs/                      # Service-specific configs
│   ├── environment.example       # Complete env var reference
│   ├── monitoring/
│   │   ├── prometheus/
│   │   │   ├── prometheus.yml   # Prometheus configuration
│   │   │   └── alerts.yml       # Alert rules
│   │   └── grafana/
│   │       ├── datasources.yml  # Grafana datasources
│   │       └── dashboards/      # Dashboard definitions
│   └── config.yaml              # Platform-wide settings
├── docker/
│   ├── config/                  # Service configurations
│   │   ├── postgresql/
│   │   │   └── postgresql.conf
│   │   ├── spark/
│   │   │   └── spark-defaults.conf
│   │   ├── trino/
│   │   │   ├── config.properties
│   │   │   └── catalog/
│   │   ├── nessie/
│   │   │   └── application.properties
│   │   └── minio/
│   │       └── config.json
│   └── services/                # Service Dockerfiles
└── secrets/                     # Secrets (NEVER COMMIT)
    ├── certificates/
    ├── keys/
    └── credentials/
```

### Configuration Layers

#### Layer 1: Environment Variables (.env)

Main configuration file loaded by Docker Compose:

```bash
# .env file
PROJECT_NAME=shudl
ENVIRONMENT=production

# Database Configuration
POSTGRES_HOST=docker-postgresql
POSTGRES_PORT=5432
POSTGRES_DB=nessie
POSTGRES_USER=nessie
POSTGRES_PASSWORD=changeme123        # Change in production

# Object Storage
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=changeme123      # Change in production
MINIO_BUCKET=lakehouse
S3_ENDPOINT=http://docker-minio:9000
```

#### Layer 2: Docker Compose Environment

Service-specific overrides in `docker-compose.yml`:

```yaml
services:
  postgresql:
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      # Additional service-specific vars
      POSTGRES_MAX_CONNECTIONS: 200
```

#### Layer 3: Service Config Files

Mounted configuration files with templating:

```properties
# spark-defaults.conf
spark.sql.catalog.iceberg.s3.access-key-id    ${env:S3_ACCESS_KEY}
spark.sql.catalog.iceberg.s3.secret-access-key ${env:S3_SECRET_KEY}
```

## Environment Variables

### Variable Categories

#### 1. Project Configuration

```bash
# Project identity
PROJECT_NAME=shudl                    # Project identifier
ENVIRONMENT=production                # Environment: dev/test/staging/prod
PLATFORM=docker                       # Platform: docker/kubernetes
```

#### 2. Network Configuration

```bash
# Network settings
NETWORK_NAME=shunetwork               # Docker network name
NETWORK_DRIVER=bridge                 # Network driver
NETWORK_SUBNET=172.18.0.0/16          # Network CIDR
```

#### 3. Database Configuration

```bash
# PostgreSQL
POSTGRES_HOST=docker-postgresql
POSTGRES_PORT=5432
POSTGRES_DB=nessie
POSTGRES_USER=nessie
POSTGRES_PASSWORD=changeme123         # CHANGE IN PRODUCTION
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_WORK_MEM=16MB

# Patroni (HA)
PATRONI_CLUSTER_NAME=shudl-cluster
PATRONI_API_USERNAME=patroni
PATRONI_API_PASSWORD=changeme123      # CHANGE IN PRODUCTION
PATRONI_REPLICATION_USER=replicator
PATRONI_REPLICATION_PASSWORD=changeme123  # CHANGE IN PRODUCTION
```

#### 4. Object Storage Configuration

```bash
# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=changeme123       # CHANGE IN PRODUCTION
MINIO_BUCKET=lakehouse
MINIO_REGION=us-east-1
MINIO_DOMAIN=minio.local
MINIO_CONSOLE_PORT=9001

# S3 Configuration (for services)
S3_ENDPOINT=http://docker-minio:9000
S3_ACCESS_KEY=${MINIO_ROOT_USER}
S3_SECRET_KEY=${MINIO_ROOT_PASSWORD}
S3_REGION=${MINIO_REGION}
S3_PATH_STYLE_ACCESS=true
```

#### 5. Catalog Configuration

```bash
# Nessie
NESSIE_URI=http://docker-nessie:19120/api/v2
NESSIE_REF=main
NESSIE_AUTH_TYPE=NONE                 # NONE/BEARER/AWS/BASIC
NESSIE_DB_HOST=${POSTGRES_HOST}
NESSIE_DB_PORT=${POSTGRES_PORT}
NESSIE_DB_NAME=${POSTGRES_DB}
NESSIE_DB_USER=${POSTGRES_USER}
NESSIE_DB_PASSWORD=${POSTGRES_PASSWORD}
NESSIE_MICROMETER_EXPORT_PROMETHEUS_ENABLED=true
```

#### 6. Compute Configuration

```bash
# Trino
TRINO_PORT=8080
TRINO_DISCOVERY_URI=http://docker-trino:8080
TRINO_MEMORY_HEAP_SIZE=8G
TRINO_MAX_MEMORY=16G
TRINO_MAX_MEMORY_PER_NODE=8G

# Spark
SPARK_MASTER_URL=spark://docker-spark-master:7077
SPARK_MASTER_PORT=7077
SPARK_MASTER_WEBUI_PORT=8080
SPARK_WORKER_CORES=4
SPARK_WORKER_MEMORY=4G
SPARK_DRIVER_MEMORY=2G
SPARK_EXECUTOR_MEMORY=2G
SPARK_ICEBERG_CATALOG_NAME=iceberg
SPARK_ICEBERG_REF=main
SPARK_ICEBERG_URI=${NESSIE_URI}
SPARK_ICEBERG_WAREHOUSE=s3a://${MINIO_BUCKET}/warehouse
```

#### 7. Streaming Configuration

```bash
# Kafka
KAFKA_BROKER_ID=1
KAFKA_ZOOKEEPER_CONNECT=docker-zookeeper:2181
KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://docker-kafka:9092
KAFKA_NUM_PARTITIONS=3
KAFKA_DEFAULT_REPLICATION_FACTOR=1
KAFKA_LOG_RETENTION_HOURS=168
KAFKA_LOG_SEGMENT_BYTES=1073741824

# Schema Registry
SCHEMA_REGISTRY_HOST=docker-schema-registry
SCHEMA_REGISTRY_PORT=8081
SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=docker-kafka:9092
```

#### 8. Monitoring Configuration

```bash
# Prometheus
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_SCRAPE_INTERVAL=15s

# Grafana
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=changeme123    # CHANGE IN PRODUCTION
GRAFANA_ALLOW_SIGN_UP=false
```

### Variable Naming Conventions

```bash
# Format: <SERVICE>_<CATEGORY>_<NAME>
POSTGRES_DB_HOST              # PostgreSQL database host
SPARK_WORKER_MEMORY           # Spark worker memory allocation
NESSIE_AUTH_TYPE              # Nessie authentication type

# Exceptions (common/shared variables)
PROJECT_NAME                  # Project-wide
ENVIRONMENT                   # Environment type
S3_ENDPOINT                   # Shared S3 config
```

## Configuration Files

### Service Configuration Files

#### PostgreSQL (`docker/config/postgresql/postgresql.conf`)

```ini
# Connection Settings
max_connections = 200
port = 5432

# Memory Settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 64MB

# Write Ahead Log
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_statement = 'mod'
log_min_duration_statement = 1000

# Performance
random_page_cost = 1.1
effective_io_concurrency = 200
```

#### Spark (`docker/config/spark/spark-defaults.conf`)

```properties
# Iceberg Catalog Configuration
spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.iceberg.catalog-impl=org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.iceberg.uri=${env:NESSIE_URI}
spark.sql.catalog.iceberg.ref=${env:SPARK_ICEBERG_REF}
spark.sql.catalog.iceberg.warehouse=${env:SPARK_ICEBERG_WAREHOUSE}

# S3 Configuration (use environment variables)
spark.sql.catalog.iceberg.s3.endpoint=${env:S3_ENDPOINT}
spark.sql.catalog.iceberg.s3.access-key-id=${env:S3_ACCESS_KEY}
spark.sql.catalog.iceberg.s3.secret-access-key=${env:S3_SECRET_KEY}
spark.sql.catalog.iceberg.s3.path-style-access=${env:S3_PATH_STYLE_ACCESS}

# Hadoop S3A Configuration
spark.hadoop.fs.s3a.endpoint=${env:S3_ENDPOINT}
spark.hadoop.fs.s3a.access.key=${env:S3_ACCESS_KEY}
spark.hadoop.fs.s3a.secret.key=${env:S3_SECRET_KEY}
spark.hadoop.fs.s3a.path.style.access=${env:S3_PATH_STYLE_ACCESS}
spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
```

#### Trino (`docker/config/trino/config.properties`)

```properties
# Coordinator Settings
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
discovery.uri=http://localhost:8080

# Memory Configuration
query.max-memory=16GB
query.max-memory-per-node=8GB
memory.heap-headroom-per-node=2GB

# Query Execution
query.max-run-time=24h
query.max-execution-time=24h
query.client.timeout=5m
```

#### Trino Iceberg Catalog (`docker/config/trino/catalog/iceberg.properties`)

```properties
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie.uri=${ENV:NESSIE_URI}
iceberg.nessie.ref=${ENV:NESSIE_REF}
iceberg.nessie.auth.type=${ENV:NESSIE_AUTH_TYPE}

# S3 Configuration
fs.native-s3.enabled=true
s3.endpoint=${ENV:S3_ENDPOINT}
s3.region=${ENV:S3_REGION}
s3.path-style-access=${ENV:S3_PATH_STYLE_ACCESS}
s3.aws-access-key=${ENV:S3_ACCESS_KEY}
s3.aws-secret-key=${ENV:S3_SECRET_KEY}
```

#### Nessie (`docker/config/nessie/application.properties`)

```properties
# Server Configuration
quarkus.http.port=19120
quarkus.http.host=0.0.0.0

# Database Configuration
nessie.version.store.type=JDBC
quarkus.datasource.jdbc.url=jdbc:postgresql://${NESSIE_DB_HOST}:${NESSIE_DB_PORT}/${NESSIE_DB_NAME}
quarkus.datasource.username=${NESSIE_DB_USER}
quarkus.datasource.password=${NESSIE_DB_PASSWORD}

# Metrics
quarkus.micrometer.export.prometheus.enabled=${NESSIE_MICROMETER_EXPORT_PROMETHEUS_ENABLED}
```

### Prometheus Configuration (`configs/monitoring/prometheus/prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Load alert rules
rule_files:
  - "/etc/prometheus/alerts.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "minio"
    static_configs:
      - targets: ["docker-minio:9000"]
    metrics_path: "/minio/v2/metrics/cluster"

  - job_name: "nessie"
    static_configs:
      - targets: ["docker-nessie:19120"]
    metrics_path: "/q/metrics"

  - job_name: "trino"
    static_configs:
      - targets: ["docker-trino:8080"]
    metrics_path: "/v1/info"
```

## Secrets Management

### Current Approach: Environment Variables

**Development/Testing:**

```bash
# .env file (NOT in version control)
POSTGRES_PASSWORD=dev_password_123
MINIO_ROOT_PASSWORD=dev_minio_123
```

**Production: Docker Secrets (Recommended)**

```bash
# Create secrets
echo "prod_postgres_password" | docker secret create postgres_password -
echo "prod_minio_password" | docker secret create minio_password -

# docker-compose.yml
services:
  postgresql:
    secrets:
      - postgres_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password

secrets:
  postgres_password:
    external: true
```

### Secret Categories

#### Critical Secrets (Change Immediately in Production)

```bash
POSTGRES_PASSWORD              # Database passwords
PATRONI_API_PASSWORD          # Patroni API
PATRONI_REPLICATION_PASSWORD  # Replication user
MINIO_ROOT_PASSWORD           # Object storage
GRAFANA_ADMIN_PASSWORD        # Monitoring
```

#### Moderate Secrets (Consider Changing)

```bash
NESSIE_AUTH_TOKEN             # If using bearer auth
KAFKA_SASL_PASSWORD           # If using SASL
TRINO_PASSWORD                # Trino user passwords
```

#### Low Risk (Can Use Defaults in Dev)

```bash
ZOOKEEPER_PASSWORD            # Internal service
SCHEMA_REGISTRY_PASSWORD      # Internal service
```

### Secret Rotation

```bash
# 1. Generate new secret
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. Update docker secret
echo "$NEW_PASSWORD" | docker secret create postgres_password_v2 -

# 3. Update service
docker service update --secret-rm postgres_password \
  --secret-add postgres_password_v2 postgresql

# 4. Test connectivity
docker exec postgresql psql -U postgres -c "SELECT 1"

# 5. Remove old secret
docker secret rm postgres_password
```

## Configuration Validation

### Pre-Deployment Validation

```bash
#!/bin/bash
# validate-config.sh

# Check required variables
REQUIRED_VARS=(
  "POSTGRES_PASSWORD"
  "MINIO_ROOT_PASSWORD"
  "NESSIE_URI"
  "S3_ENDPOINT"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: $var is not set"
    exit 1
  fi
done

# Validate password strength
if [ ${#POSTGRES_PASSWORD} -lt 12 ]; then
  echo "ERROR: POSTGRES_PASSWORD must be at least 12 characters"
  exit 1
fi

# Check for default passwords in production
if [ "$ENVIRONMENT" = "production" ]; then
  if [[ "$POSTGRES_PASSWORD" == *"changeme"* ]]; then
    echo "ERROR: Default password detected in production"
    exit 1
  fi
fi

# Validate URLs
if ! curl -f -s "$NESSIE_URI/api/v2/config" > /dev/null; then
  echo "WARNING: Cannot reach Nessie at $NESSIE_URI"
fi

echo "✅ Configuration validation passed"
```

### Runtime Validation

```bash
# Check services can connect
docker exec docker-trino trino --execute "SHOW CATALOGS"
docker exec docker-spark-master spark-shell --version
docker exec docker-postgresql psql -U postgres -c "SELECT version()"
```

### Configuration Audit

```bash
# Audit current configuration
./scripts/audit-config.sh

# Output:
# ✅ No hardcoded passwords in config files
# ✅ All required variables set
# ⚠️  Using default MINIO_ROOT_PASSWORD
# ✅ TLS enabled on external ports
# ✅ Network segmentation configured
```

## Configuration Templates

### Template System

```bash
# configs/templates/production.env
PROJECT_NAME=shudl-prod
ENVIRONMENT=production

# High availability settings
PATRONI_CLUSTER_NAME=shudl-prod-cluster
POSTGRES_MAX_CONNECTIONS=500
POSTGRES_SHARED_BUFFERS=4GB

# Performance tuning
TRINO_MEMORY_HEAP_SIZE=16G
SPARK_WORKER_MEMORY=8G

# Security hardening
NESSIE_AUTH_TYPE=BEARER
S3_ENABLE_TLS=true
```

### Using Templates

```bash
# Copy template
cp configs/templates/production.env .env

# Customize passwords
sed -i 's/CHANGE_ME/'"$(openssl rand -base64 32)"'/g' .env

# Validate
./scripts/validate-config.sh

# Deploy
docker compose up -d
```

### Pre-built Templates

```
configs/templates/
├── development.env         # Local development
├── testing.env            # CI/CD testing
├── staging.env            # Staging environment
├── production.env         # Production (HA + security)
├── production-ha.env      # Production with full HA
└── minimal.env            # Minimal setup (dev/demo)
```

## Best Practices

### 1. Environment Separation

```bash
# Development
.env.development          # Local development settings
docker-compose.dev.yml    # Dev service configuration

# Production
.env.production          # Production settings
docker-compose.prod.yml  # Production configuration
```

### 2. Version Control

```gitignore
# .gitignore
.env
.env.local
.env.*.local
secrets/
*.key
*.pem
*.p12
```

```bash
# Commit safe examples
git add .env.example
git add configs/templates/*.env
```

### 3. Documentation

```bash
# Document every variable
# configs/environment.example

# Database Configuration
POSTGRES_HOST=docker-postgresql    # PostgreSQL hostname
POSTGRES_PORT=5432                 # PostgreSQL port (default: 5432)
POSTGRES_DB=nessie                # Database name
POSTGRES_USER=nessie              # Database user
POSTGRES_PASSWORD=changeme123     # Database password (CHANGE IN PRODUCTION)
```

### 4. Change Management

```bash
# 1. Document change
git commit -m "config: increase Trino memory from 8G to 16G"

# 2. Test in staging
./scripts/deploy.sh staging

# 3. Validate
./scripts/validate-deployment.sh staging

# 4. Deploy to production
./scripts/deploy.sh production

# 5. Monitor
./scripts/monitor-deployment.sh production
```

### 5. Configuration as Code

```yaml
# infrastructure/terraform/variables.tf
variable "postgres_max_connections" {
description = "Maximum PostgreSQL connections"
type        = number
default     = 200
validation {
condition     = var.postgres_max_connections >= 100
error_message = "Must allow at least 100 connections"
}
}
```

## Configuration Change Process

### 1. Planning Phase

```
1. Identify required change
2. Review documentation
3. Assess impact (services affected, downtime required)
4. Create change plan
5. Review with team
```

### 2. Implementation Phase

```bash
# Update configuration
vim .env

# Validate syntax
./scripts/validate-config.sh

# Test in development
docker compose -f docker-compose.dev.yml up -d

# Run integration tests
./tests/run-tests.sh
```

### 3. Deployment Phase

```bash
# Backup current configuration
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# Deploy changes
docker compose up -d --force-recreate

# Verify services
docker compose ps
./scripts/health-check.sh
```

### 4. Validation Phase

```bash
# Check service health
curl http://localhost:19120/api/v2/config     # Nessie
curl http://localhost:8080/v1/info            # Trino
curl http://localhost:9000/minio/health/live  # MinIO

# Run smoke tests
./tests/smoke-tests.sh

# Check metrics
curl http://localhost:9090/api/v1/query?query=up
```

### 5. Rollback Procedure

```bash
# If issues detected, rollback
cp .env.backup.20240115_143022 .env
docker compose up -d --force-recreate

# Verify rollback
./scripts/health-check.sh
```

## Troubleshooting

### Common Configuration Issues

#### Issue 1: Service Cannot Connect to PostgreSQL

```bash
# Symptom
ERROR: could not connect to database

# Diagnosis
docker logs docker-nessie | grep -i "connection"

# Resolution
1. Check POSTGRES_HOST matches service name
2. Verify POSTGRES_PASSWORD is correct
3. Ensure PostgreSQL is running: docker ps | grep postgresql
4. Test connectivity: docker exec docker-nessie nc -zv docker-postgresql 5432
```

#### Issue 2: Spark Cannot Access MinIO

```bash
# Symptom
java.io.FileNotFoundException: s3a://lakehouse/warehouse

# Diagnosis
docker logs docker-spark-master | grep -i "s3"

# Resolution
1. Check S3_ENDPOINT is accessible from Spark containers
2. Verify S3_ACCESS_KEY and S3_SECRET_KEY match MINIO credentials
3. Ensure S3_PATH_STYLE_ACCESS=true for MinIO
4. Test: docker exec docker-spark-master curl http://docker-minio:9000
```

#### Issue 3: Environment Variables Not Expanding

```bash
# Symptom
Config shows literal ${ENV:VAR} instead of value

# Diagnosis
cat docker/config/trino/catalog/iceberg.properties

# Resolution
1. Ensure Docker Compose version >= 1.28
2. Use ${ENV:VAR} syntax (not just ${VAR})
3. Verify variable is set: docker compose config | grep VAR
4. Restart with: docker compose up -d --force-recreate
```

#### Issue 4: Configuration Changes Not Applied

```bash
# Symptom
Services still use old configuration after update

# Diagnosis
docker compose config  # Shows merged configuration

# Resolution
1. Stop services: docker compose down
2. Remove volumes (if config cached): docker volume rm shudl_postgres_data
3. Start services: docker compose up -d
4. Verify: docker exec <service> cat /path/to/config
```

### Configuration Debugging

```bash
# View effective configuration
docker compose config

# Check specific service environment
docker exec docker-postgresql env | sort

# View mounted config files
docker exec docker-trino cat /etc/trino/config.properties

# Check for syntax errors
yamllint docker-compose.yml
yamllint configs/monitoring/prometheus/prometheus.yml
```

### Validation Tools

```bash
# Validate Docker Compose syntax
docker compose config --quiet

# Validate environment variables
env | grep -E "^(POSTGRES|MINIO|NESSIE|TRINO|SPARK)" | sort

# Check for security issues
grep -r "password.*=" .env | grep -v "changeme"

# Audit secrets
./scripts/audit-secrets.sh
```

## References

- [Environment Variables Reference](../reference/environment-variables.md)
- [Service Endpoints Reference](../reference/service-endpoints.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Backup & Recovery Guide](backup-recovery.md)
- [Monitoring Guide](monitoring.md)

## Checklists

### Pre-Deployment Configuration Checklist

- [ ] All required variables set in .env
- [ ] Production passwords changed (no "changeme" strings)
- [ ] URLs and endpoints validated
- [ ] Configuration syntax validated
- [ ] Backup of previous configuration taken
- [ ] Change documented in git commit
- [ ] Team notified of configuration change
- [ ] Rollback plan prepared

### Post-Deployment Validation Checklist

- [ ] All services started successfully
- [ ] Services can connect to dependencies
- [ ] Health checks passing
- [ ] Metrics being collected
- [ ] No error logs
- [ ] Smoke tests passed
- [ ] Performance within expected range
- [ ] Configuration changes documented

---

**Last Updated**: 2024-01-15  
**Version**: 1.0.0  
**Maintainer**: ShuDL Team
