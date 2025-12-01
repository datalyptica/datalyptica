# Datalyptica Platform - Environment Variables Reference

**Version:** v1.0.0  
**Last Updated:** November 26, 2025

---

## Overview

This document provides a complete reference for all environment variables used in the Datalyptica platform. Variables are organized by service layer.

**Configuration File:** `docker/.env`

---

## Quick Reference

### Critical Variables (Must Configure)

| Variable | Default | Description | Change for Production |
|----------|---------|-------------|---------------------|
| `MINIO_ROOT_PASSWORD` | minioadmin123 | MinIO admin password | ✅ YES |
| `POSTGRES_PASSWORD` | postgres123 | PostgreSQL password | ✅ YES |
| `GRAFANA_ADMIN_PASSWORD` | admin | Grafana admin password | ✅ YES |
| `KEYCLOAK_ADMIN_PASSWORD` | admin | Keycloak admin password | ✅ YES |
| `S3_SECRET_KEY` | minioadmin123 | S3 secret (match MinIO) | ✅ YES |

---

## Project Configuration

### `COMPOSE_PROJECT_NAME`
- **Default:** `datalyptica`
- **Description:** Docker Compose project name prefix for all containers
- **Example:** `datalyptica-minio`, `datalyptica-postgresql`
- **Production:** Keep default or use environment-specific name

### `DATALYPTICA_VERSION`
- **Default:** `v1.0.0`
- **Description:** Platform version for Docker image tags
- **Production:** Update when deploying new version

### `TIMEZONE`
- **Default:** `UTC`
- **Description:** Timezone for all services
- **Options:** Any valid TZ database timezone
- **Production:** Use UTC or your datacenter timezone

---

## Health Check Configuration

### `HEALTHCHECK_INTERVAL`
- **Default:** `30s`
- **Description:** How often to run health checks
- **Production:** Keep default or increase for production stability

### `HEALTHCHECK_TIMEOUT`
- **Default:** `10s`
- **Description:** Timeout for health check command
- **Production:** Keep default

### `HEALTHCHECK_RETRIES`
- **Default:** `3`
- **Description:** Number of consecutive failures before marking unhealthy
- **Production:** Keep default or increase to 5

### `HEALTHCHECK_START_PERIOD`
- **Default:** `60s`
- **Description:** Grace period before health checks start
- **Production:** Increase to 120s for slower systems

---

## Storage Layer - MinIO

### Ports

#### `MINIO_API_PORT`
- **Default:** `9000`
- **Description:** MinIO S3 API port
- **Production:** Keep default or use reverse proxy

#### `MINIO_CONSOLE_PORT`
- **Default:** `9001`
- **Description:** MinIO web console port
- **Production:** Consider restricting access

### Credentials ⚠️

#### `MINIO_ROOT_USER`
- **Default:** `admin`
- **Description:** MinIO administrator username
- **Production:** ✅ Change to unique username
- **Note:** Must match `S3_ACCESS_KEY`

#### `MINIO_ROOT_PASSWORD`
- **Default:** `minioadmin123`
- **Description:** MinIO administrator password
- **Production:** ✅ Use strong password (32+ characters)
- **Note:** Must match `S3_SECRET_KEY`
- **Generate:** `openssl rand -base64 32`

### Configuration

#### `MINIO_BUCKET_NAME`
- **Default:** `lakehouse`
- **Description:** Default bucket name for Iceberg data
- **Production:** Keep default

#### `MINIO_REGION`
- **Default:** `us-east-1`
- **Description:** AWS region designation
- **Production:** Keep default

---

## Storage Layer - PostgreSQL

### Port

#### `POSTGRES_PORT`
- **Default:** `5432`
- **Description:** PostgreSQL connection port
- **Production:** Keep default

### Credentials ⚠️

#### `POSTGRES_DB`
- **Default:** `postgres`
- **Description:** Default PostgreSQL database
- **Production:** Keep default

#### `POSTGRES_USER`
- **Default:** `postgres`
- **Description:** PostgreSQL superuser
- **Production:** ✅ Consider changing for security

#### `POSTGRES_PASSWORD`
- **Default:** `postgres123`
- **Description:** PostgreSQL superuser password
- **Production:** ✅ Use strong password (32+ characters)
- **Generate:** `openssl rand -base64 32`

### Performance Tuning

#### `POSTGRES_MAX_CONNECTIONS`
- **Default:** `200`
- **Description:** Maximum concurrent connections
- **Production:** Adjust based on workload (200-500)

#### `POSTGRES_SHARED_BUFFERS`
- **Default:** `256MB`
- **Description:** Memory for shared buffers
- **Production:** 25% of available RAM (e.g., 4GB for 16GB RAM)

#### `POSTGRES_EFFECTIVE_CACHE_SIZE`
- **Default:** `1GB`
- **Description:** Estimated OS cache size
- **Production:** 50-75% of available RAM

#### `POSTGRES_WORK_MEM`
- **Default:** `16MB`
- **Description:** Memory for sort operations
- **Production:** Total RAM / (max_connections * 2)

---

## Storage Layer - Nessie

### Configuration

#### `NESSIE_PORT`
- **Default:** `19120`
- **Description:** Nessie API port
- **Production:** Keep default

#### `NESSIE_URI`
- **Default:** `http://nessie:19120/api/v2`
- **Description:** Nessie API endpoint
- **Production:** Update protocol to https:// when SSL enabled

#### `NESSIE_VERSION_STORE_TYPE`
- **Default:** `JDBC2`
- **Description:** Backend storage type for Nessie
- **Production:** Keep default (uses PostgreSQL)

#### `WAREHOUSE_LOCATION`
- **Default:** `s3://lakehouse/warehouse`
- **Description:** Default warehouse location for Iceberg tables
- **Production:** Keep default or customize path

---

## Processing Layer - Spark

### Configuration

#### `SPARK_MASTER_URL`
- **Default:** `spark://spark-master:7077`
- **Description:** Spark master connection URL
- **Production:** Keep default

#### `SPARK_DRIVER_MEMORY`
- **Default:** `2g`
- **Description:** Memory for Spark driver
- **Production:** Increase for large jobs (4g-8g)

#### `SPARK_EXECUTOR_MEMORY`
- **Default:** `2g`
- **Description:** Memory per executor
- **Production:** Increase based on workload (4g-16g)

#### `SPARK_WORKER_MEMORY`
- **Default:** `4g`
- **Description:** Total memory available to worker
- **Production:** Set to 80% of worker node RAM

---

## Query Layer - Trino

### Configuration

#### `TRINO_PORT`
- **Default:** `8080`
- **Description:** Trino HTTP port
- **Production:** Keep default or use reverse proxy

#### `TRINO_QUERY_MAX_MEMORY`
- **Default:** `4GB`
- **Description:** Maximum memory per query
- **Production:** Increase for large queries (8GB-32GB)

#### `TRINO_JVM_XMX`
- **Default:** `8G`
- **Description:** Maximum JVM heap size
- **Production:** 80% of available RAM (e.g., 64G for 80GB RAM)

---

## Observability - Grafana

### Credentials ⚠️

#### `GRAFANA_ADMIN_USER`
- **Default:** `admin`
- **Description:** Grafana administrator username
- **Production:** ✅ Change to unique username

#### `GRAFANA_ADMIN_PASSWORD`
- **Default:** `admin`
- **Description:** Grafana administrator password
- **Production:** ✅ Use strong password
- **Generate:** `openssl rand -base64 24`

---

## Observability - Keycloak

### Credentials ⚠️

#### `KEYCLOAK_ADMIN_USER`
- **Default:** `admin`
- **Description:** Keycloak administrator username
- **Production:** ✅ Change to unique username

#### `KEYCLOAK_ADMIN_PASSWORD`
- **Default:** `admin`
- **Description:** Keycloak administrator password
- **Production:** ✅ Use strong password
- **Generate:** `openssl rand -base64 32`

---

## Production Configuration Template

```bash
# Generate secure passwords
export MINIO_PASS=$(openssl rand -base64 32)
export POSTGRES_PASS=$(openssl rand -base64 32)
export GRAFANA_PASS=$(openssl rand -base64 24)
export KEYCLOAK_PASS=$(openssl rand -base64 32)

# Update .env file
sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=${MINIO_PASS}/" docker/.env
sed -i "s/S3_SECRET_KEY=.*/S3_SECRET_KEY=${MINIO_PASS}/" docker/.env
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${POSTGRES_PASS}/" docker/.env
sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASS}/" docker/.env
sed -i "s/KEYCLOAK_ADMIN_PASSWORD=.*/KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_PASS}/" docker/.env

# Store passwords securely
echo "MinIO: ${MINIO_PASS}" >> ~/.datalyptica_prod_secrets
echo "PostgreSQL: ${POSTGRES_PASS}" >> ~/.datalyptica_prod_secrets
echo "Grafana: ${GRAFANA_PASS}" >> ~/.datalyptica_prod_secrets
echo "Keycloak: ${KEYCLOAK_PASS}" >> ~/.datalyptica_prod_secrets
chmod 600 ~/.datalyptica_prod_secrets
```

---

## Validation

### Check Required Variables

```bash
cd docker

# Verify all required variables are set
required_vars=(
    "MINIO_ROOT_PASSWORD"
    "POSTGRES_PASSWORD"
    "S3_SECRET_KEY"
    "NESSIE_URI"
    "WAREHOUSE_LOCATION"
)

for var in "${required_vars[@]}"; do
    if grep -q "^${var}=" .env; then
        echo "✅ $var is set"
    else
        echo "❌ $var is missing"
    fi
done
```

### Validate Configuration

```bash
# Test docker-compose configuration
docker compose config > /dev/null
echo "✅ Configuration is valid"
```

---

## See Also

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment procedures
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [README.md](README.md) - Platform overview
