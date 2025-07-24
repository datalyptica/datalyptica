#!/bin/bash

# ShuDL Data Lakehouse - Docker Run Script
# Alternative to docker-compose using plain docker commands
# Usage: ./run-docker.sh [start|stop|restart|status|cleanup]

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${CYAN}🔄 $1${NC}"
}

# Load environment variables
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        exit 1
    fi
    
    log_info "Loading environment variables from $ENV_FILE"
    set -a  # Automatically export all variables
    source "$ENV_FILE"
    set +a
    log_success "Environment variables loaded"
}

# Wait for container to be healthy
wait_for_container() {
    local container_name="$1"
    local max_wait="${2:-300}"  # Default 5 minutes
    local check_interval="${3:-5}"  # Default 5 seconds
    
    log_step "Waiting for $container_name to be healthy (max ${max_wait}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        if docker container inspect "$container_name" --format '{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            log_success "$container_name is healthy"
            return 0
        fi
        
        if ! docker container inspect "$container_name" >/dev/null 2>&1; then
            log_error "$container_name container not found"
            return 1
        fi
        
        sleep "$check_interval"
        elapsed=$((elapsed + check_interval))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            log_info "Still waiting for $container_name... (${elapsed}s elapsed)"
        fi
    done
    
    log_error "$container_name failed to become healthy within ${max_wait} seconds"
    return 1
}

# Create network
create_network() {
    log_step "Creating Docker network: $NETWORK_NAME"
    
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        log_info "Network $NETWORK_NAME already exists"
    else
        docker network create \
            --driver bridge \
            "$NETWORK_NAME"
        log_success "Network $NETWORK_NAME created"
    fi
}

# Create volumes
create_volumes() {
    log_step "Creating Docker volumes"
    
    local volumes=("minio_data" "postgresql_data")
    
    for volume in "${volumes[@]}"; do
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            log_info "Volume $volume already exists"
        else
            docker volume create "$volume"
            log_success "Volume $volume created"
        fi
    done
}

# Start MinIO container
start_minio() {
    local container_name="${COMPOSE_PROJECT_NAME}-minio"
    
    log_step "Starting MinIO container: $container_name"
    
    if docker container inspect "$container_name" >/dev/null 2>&1; then
        if docker container inspect "$container_name" --format '{{.State.Status}}' | grep -q "running"; then
            log_info "MinIO container already running"
            return 0
        else
            log_info "Removing existing MinIO container"
            docker container rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -p "${MINIO_API_PORT}:9000" \
        -p "${MINIO_CONSOLE_PORT}:9001" \
        -v minio_data:/data \
        -e MINIO_ROOT_USER="$MINIO_ROOT_USER" \
        -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
        -e MINIO_VOLUMES=/data \
        -e MINIO_OPTS="--console-address :9001" \
        -e MINIO_REGION="$MINIO_REGION" \
        -e MINIO_DEFAULT_BUCKETS="$MINIO_BUCKET_NAME" \
        -e MINIO_ADDRESS="$MINIO_ADDRESS" \
        -e MINIO_CONSOLE_ADDRESS="$MINIO_CONSOLE_ADDRESS" \
        -e MINIO_LOG_LEVEL="$MINIO_LOG_LEVEL" \
        -e MINIO_LOG_FILE="$MINIO_LOG_FILE" \
        -e MINIO_CACHE_DRIVES="$MINIO_CACHE_DRIVES" \
        -e MINIO_CACHE_EXPIRY="$MINIO_CACHE_EXPIRY" \
        -e MINIO_CACHE_QUOTA="$MINIO_CACHE_QUOTA" \
        -e MINIO_CACHE_EXCLUDE="$MINIO_CACHE_EXCLUDE" \
        -e MINIO_COMPRESS="$MINIO_COMPRESS" \
        -e MINIO_COMPRESS_MIME_TYPES="$MINIO_COMPRESS_MIME_TYPES" \
        -e MINIO_BROWSER="$MINIO_BROWSER" \
        --health-cmd "curl -f http://localhost:9000/minio/health/live" \
        --health-interval "${HEALTHCHECK_INTERVAL}" \
        --health-timeout "${HEALTHCHECK_TIMEOUT}" \
        --health-retries "${HEALTHCHECK_RETRIES}" \
        --health-start-period "${HEALTHCHECK_START_PERIOD}" \
        ghcr.io/shugur-network/shudl/minio:latest
    
    log_success "MinIO container started"
}

# Start PostgreSQL container
start_postgresql() {
    local container_name="${COMPOSE_PROJECT_NAME}-postgresql"
    
    log_step "Starting PostgreSQL container: $container_name"
    
    if docker container inspect "$container_name" >/dev/null 2>&1; then
        if docker container inspect "$container_name" --format '{{.State.Status}}' | grep -q "running"; then
            log_info "PostgreSQL container already running"
            return 0
        else
            log_info "Removing existing PostgreSQL container"
            docker container rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -p "${POSTGRES_PORT}:5432" \
        -v postgresql_data:/var/lib/postgresql/data \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_INITDB_ARGS="--encoding=UTF-8 --lc-collate=C --lc-ctype=C" \
        -e PGDATA=/var/lib/postgresql/data/pgdata \
        -e SHUDL_DB="$SHUDL_DB" \
        -e SHUDL_USER="$SHUDL_USER" \
        -e SHUDL_PASSWORD="$SHUDL_PASSWORD" \
        -e NESSIE_DB="$NESSIE_DB" \
        -e POSTGRES_MAX_CONNECTIONS="$POSTGRES_MAX_CONNECTIONS" \
        -e POSTGRES_SHARED_BUFFERS="$POSTGRES_SHARED_BUFFERS" \
        -e POSTGRES_EFFECTIVE_CACHE_SIZE="$POSTGRES_EFFECTIVE_CACHE_SIZE" \
        -e POSTGRES_WORK_MEM="$POSTGRES_WORK_MEM" \
        -e POSTGRES_MAINTENANCE_WORK_MEM="$POSTGRES_MAINTENANCE_WORK_MEM" \
        -e POSTGRES_WAL_LEVEL="$POSTGRES_WAL_LEVEL" \
        -e POSTGRES_MAX_WAL_SIZE="$POSTGRES_MAX_WAL_SIZE" \
        -e POSTGRES_MIN_WAL_SIZE="$POSTGRES_MIN_WAL_SIZE" \
        -e POSTGRES_CHECKPOINT_COMPLETION_TARGET="$POSTGRES_CHECKPOINT_COMPLETION_TARGET" \
        -e POSTGRES_SUPERUSER_RESERVED_CONNECTIONS="$POSTGRES_SUPERUSER_RESERVED_CONNECTIONS" \
        -e POSTGRES_LISTEN_ADDRESSES="$POSTGRES_LISTEN_ADDRESSES" \
        -e POSTGRES_AUTH_LOCAL="$POSTGRES_AUTH_LOCAL" \
        -e POSTGRES_AUTH_HOST_IPV4="$POSTGRES_AUTH_HOST_IPV4" \
        -e POSTGRES_AUTH_HOST_IPV6="$POSTGRES_AUTH_HOST_IPV6" \
        -e POSTGRES_AUTH_REPLICATION_LOCAL="$POSTGRES_AUTH_REPLICATION_LOCAL" \
        -e POSTGRES_AUTH_REPLICATION_HOST="$POSTGRES_AUTH_REPLICATION_HOST" \
        -e POSTGRES_AUTH_DOCKER_NETWORKS="$POSTGRES_AUTH_DOCKER_NETWORKS" \
        -e POSTGRES_ALLOWED_NETWORKS="$POSTGRES_ALLOWED_NETWORKS" \
        --health-cmd "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}" \
        --health-interval "${HEALTHCHECK_INTERVAL}" \
        --health-timeout "${HEALTHCHECK_TIMEOUT}" \
        --health-retries "${HEALTHCHECK_RETRIES}" \
        --health-start-period "${HEALTHCHECK_START_PERIOD}" \
        ghcr.io/shugur-network/shudl/postgresql:latest
    
    log_success "PostgreSQL container started"
}

# Start Nessie container
start_nessie() {
    local container_name="${COMPOSE_PROJECT_NAME}-nessie"
    
    log_step "Starting Nessie container: $container_name"
    
    if docker container inspect "$container_name" >/dev/null 2>&1; then
        if docker container inspect "$container_name" --format '{{.State.Status}}' | grep -q "running"; then
            log_info "Nessie container already running"
            return 0
        else
            log_info "Removing existing Nessie container"
            docker container rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -p "${NESSIE_PORT}:19120" \
        -e QUARKUS_HTTP_PORT="$NESSIE_PORT" \
        -e QUARKUS_HTTP_HOST="$NESSIE_HOST" \
        -e QUARKUS_HTTP_CORS="$NESSIE_CORS_ENABLED" \
        -e QUARKUS_HTTP_CORS_ORIGINS="$NESSIE_CORS_ORIGINS" \
        -e QUARKUS_HTTP_CORS_METHODS="$NESSIE_CORS_METHODS" \
        -e QUARKUS_HTTP_CORS_HEADERS="$NESSIE_CORS_HEADERS" \
        -e QUARKUS_HTTP_CORS_EXPOSED_HEADERS="$NESSIE_CORS_EXPOSED_HEADERS" \
        -e QUARKUS_HTTP_CORS_ACCESS_CONTROL_MAX_AGE="$NESSIE_CORS_MAX_AGE" \
        -e NESSIE_VERSION_STORE_TYPE="$NESSIE_VERSION_STORE_TYPE" \
        -e NESSIE_VERSION_STORE_PERSIST_JDBC_DATASOURCE="$NESSIE_DATASOURCE_NAME" \
        -e QUARKUS_DATASOURCE_POSTGRESQL_JDBC_URL="jdbc:postgresql://shudl-postgresql:5432/${POSTGRES_DB}" \
        -e QUARKUS_DATASOURCE_POSTGRESQL_USERNAME="$POSTGRES_USER" \
        -e QUARKUS_DATASOURCE_POSTGRESQL_PASSWORD="$POSTGRES_PASSWORD" \
        -e QUARKUS_DATASOURCE_POSTGRESQL_JDBC_INITIAL_SIZE="$NESSIE_DB_INITIAL_SIZE" \
        -e QUARKUS_DATASOURCE_POSTGRESQL_JDBC_MIN_SIZE="$NESSIE_DB_MIN_SIZE" \
        -e QUARKUS_DATASOURCE_POSTGRESQL_JDBC_MAX_SIZE="$NESSIE_DB_MAX_SIZE" \
        -e QUARKUS_DATASOURCE_JDBC_URL="jdbc:postgresql://shudl-postgresql:5432/${POSTGRES_DB}" \
        -e QUARKUS_DATASOURCE_USERNAME="$QUARKUS_DATASOURCE_USERNAME" \
        -e QUARKUS_DATASOURCE_PASSWORD="$QUARKUS_DATASOURCE_PASSWORD" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -e NESSIE_CATALOG_DEFAULT_WAREHOUSE="$NESSIE_DEFAULT_WAREHOUSE" \
        -e NESSIE_CATALOG_WAREHOUSES_WAREHOUSE_LOCATION="$NESSIE_WAREHOUSE_LOCATION" \
        -e WAREHOUSE_LOCATION="$WAREHOUSE_LOCATION" \
        -e NESSIE_MICROMETER_ENABLED="$NESSIE_MICROMETER_ENABLED" \
        -e NESSIE_MICROMETER_EXPORT_PROMETHEUS_ENABLED="$NESSIE_MICROMETER_EXPORT_PROMETHEUS_ENABLED" \
        -e NESSIE_HEALTH_ROOT_PATH="$NESSIE_HEALTH_ROOT_PATH" \
        -e NESSIE_SWAGGER_UI_ALWAYS_INCLUDE="$NESSIE_SWAGGER_UI_ALWAYS_INCLUDE" \
        -e NESSIE_SWAGGER_UI_PATH="$NESSIE_SWAGGER_UI_PATH" \
        -e NESSIE_SERVER_AUTHENTICATION_ENABLED="$NESSIE_SERVER_AUTHENTICATION_ENABLED" \
        -e S3_ACCESS_KEY="$S3_ACCESS_KEY" \
        -e S3_SECRET_KEY="$S3_SECRET_KEY" \
        -e S3_ENDPOINT="$S3_ENDPOINT" \
        -e MINIO_REGION="$MINIO_REGION" \
        --health-cmd "curl -f http://localhost:19120/api/v2/config" \
        --health-interval "${HEALTHCHECK_INTERVAL}" \
        --health-timeout "${HEALTHCHECK_TIMEOUT}" \
        --health-retries 5 \
        --health-start-period 60s \
        ghcr.io/shugur-network/shudl/nessie:latest
    
    log_success "Nessie container started"
}

# Start Trino container
start_trino() {
    local container_name="${COMPOSE_PROJECT_NAME}-trino"
    
    log_step "Starting Trino container: $container_name"
    
    if docker container inspect "$container_name" >/dev/null 2>&1; then
        if docker container inspect "$container_name" --format '{{.State.Status}}' | grep -q "running"; then
            log_info "Trino container already running"
            return 0
        else
            log_info "Removing existing Trino container"
            docker container rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -p "${TRINO_PORT}:8080" \
        -e TRINO_COORDINATOR="$TRINO_COORDINATOR" \
        -e TRINO_NODE_SCHEDULER_INCLUDE_COORDINATOR="$TRINO_INCLUDE_COORDINATOR" \
        -e TRINO_HTTP_SERVER_PORT="$TRINO_PORT" \
        -e TRINO_DISCOVERY_URI="$TRINO_DISCOVERY_URI" \
        -e TRINO_QUERY_MAX_MEMORY="$TRINO_QUERY_MAX_MEMORY" \
        -e TRINO_MEMORY_HEAP_HEADROOM_PER_NODE="$TRINO_MEMORY_HEAP_HEADROOM" \
        -e TRINO_NODE_ENVIRONMENT="$TRINO_NODE_ENVIRONMENT" \
        -e TRINO_NODE_DATA_DIR="$TRINO_NODE_DATA_DIR" \
        -e TRINO_NODE_ID="$TRINO_NODE_ID" \
        -e TRINO_JVM_XMX="$TRINO_JVM_XMX" \
        -e TRINO_JVM_GC="$TRINO_JVM_GC" \
        -e TRINO_JVM_G1_HEAP_REGION_SIZE="$TRINO_JVM_G1_HEAP_REGION_SIZE" \
        -e TRINO_JVM_EXIT_ON_OOM="$TRINO_JVM_EXIT_ON_OOM" \
        -e TRINO_JVM_USE_GC_OVERHEAD_LIMIT="$TRINO_JVM_USE_GC_OVERHEAD_LIMIT" \
        -e TRINO_JVM_NIO_MAX_CACHED_BUFFER_SIZE="$TRINO_JVM_NIO_MAX_CACHED_BUFFER_SIZE" \
        -e TRINO_JVM_ALLOW_ATTACH_SELF="$TRINO_JVM_ALLOW_ATTACH_SELF" \
        -e TRINO_LOG_LEVEL_ROOT="$TRINO_LOG_LEVEL_ROOT" \
        -e TRINO_LOG_LEVEL_SERVER="$TRINO_LOG_LEVEL_SERVER" \
        -e TRINO_LOG_LEVEL_EXECUTION="$TRINO_LOG_LEVEL_EXECUTION" \
        -e TRINO_LOG_LEVEL_METADATA="$TRINO_LOG_LEVEL_METADATA" \
        -e TRINO_LOG_LEVEL_SECURITY="$TRINO_LOG_LEVEL_SECURITY" \
        -e TRINO_LOG_LEVEL_SPI="$TRINO_LOG_LEVEL_SPI" \
        -e TRINO_LOG_LEVEL_SQL="$TRINO_LOG_LEVEL_SQL" \
        -e TRINO_LOG_LEVEL_TRANSACTION="$TRINO_LOG_LEVEL_TRANSACTION" \
        -e TRINO_LOG_LEVEL_TYPE="$TRINO_LOG_LEVEL_TYPE" \
        -e TRINO_LOG_LEVEL_UTIL="$TRINO_LOG_LEVEL_UTIL" \
        -e TRINO_LOG_LEVEL_HTTP_REQUEST="$TRINO_LOG_LEVEL_HTTP_REQUEST" \
        -e TRINO_CATALOG_ICEBERG_CONNECTOR_NAME=icebergoka \
        -e TRINO_CATALOG_ICEBERG_CATALOG_TYPE="$TRINO_CATALOG_ICEBERG_CATALOG_TYPE" \
        -e TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI="$TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI" \
        -e TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_REF="$TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_REF" \
        -e TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_DEFAULT_WAREHOUSE_DIR="$TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_DEFAULT_WAREHOUSE_DIR" \
        -e TRINO_CATALOG_ICEBERG_FILE_FORMAT="$TRINO_CATALOG_ICEBERG_FILE_FORMAT" \
        -e TRINO_CATALOG_ICEBERG_COMPRESSION_CODEC="$TRINO_CATALOG_ICEBERG_COMPRESSION_CODEC" \
        -e TRINO_CATALOG_ICEBERG_S3_ENDPOINT="$S3_ENDPOINT" \
        -e TRINO_CATALOG_ICEBERG_S3_REGION="$S3_REGION" \
        -e TRINO_CATALOG_ICEBERG_S3_PATH_STYLE_ACCESS="$S3_PATH_STYLE_ACCESS" \
        -e TRINO_CATALOG_ICEBERG_S3_ACCESS_KEY="$S3_ACCESS_KEY" \
        -e TRINO_CATALOG_ICEBERG_S3_SECRET_KEY="$S3_SECRET_KEY" \
        -e S3_ENDPOINT="$S3_ENDPOINT" \
        -e S3_ACCESS_KEY="$S3_ACCESS_KEY" \
        -e S3_SECRET_KEY="$S3_SECRET_KEY" \
        -e S3_REGION="$S3_REGION" \
        -e S3_PATH_STYLE_ACCESS="$S3_PATH_STYLE_ACCESS" \
        -e FS_NATIVE_S3_ENABLED=true \
        -e NESSIE_HOST="shudl-nessie" \
        -e NESSIE_PORT="19120" \
        --health-cmd "curl -f http://localhost:8080/v1/info" \
        --health-interval "${HEALTHCHECK_INTERVAL}" \
        --health-timeout "${HEALTHCHECK_TIMEOUT}" \
        --health-retries "${HEALTHCHECK_RETRIES}" \
        --health-start-period 60s \
        ghcr.io/shugur-network/shudl/trino:latest
    
    log_success "Trino container started"
}

# Start Spark Master container
start_spark_master() {
    local container_name="${COMPOSE_PROJECT_NAME}-spark-master"
    
    log_step "Starting Spark Master container: $container_name"
    
    if docker container inspect "$container_name" >/dev/null 2>&1; then
        if docker container inspect "$container_name" --format '{{.State.Status}}' | grep -q "running"; then
            log_info "Spark Master container already running"
            return 0
        else
            log_info "Removing existing Spark Master container"
            docker container rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -p "${SPARK_UI_PORT}:4040" \
        -p "${SPARK_MASTER_PORT}:7077" \
        -e SPARK_MODE=master \
        -e SPARK_WEBUI_PORT="$SPARK_UI_PORT" \
        -e SPARK_UI_PORT="$SPARK_UI_PORT" \
        -e SPARK_RPC_AUTHENTICATION_ENABLED=false \
        -e SPARK_RPC_ENCRYPTION_ENABLED=false \
        -e SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=false \
        -e SPARK_SSL_ENABLED=false \
        -e SPARK_MASTER_URL="$SPARK_MASTER_URL" \
        -e SPARK_DRIVER_MEMORY="$SPARK_DRIVER_MEMORY" \
        -e SPARK_DRIVER_MAX_RESULT_SIZE="$SPARK_DRIVER_MAX_RESULT_SIZE" \
        -e SPARK_EXECUTOR_MEMORY="$SPARK_EXECUTOR_MEMORY" \
        -e SPARK_EXECUTOR_CORES="$SPARK_EXECUTOR_CORES" \
        -e SPARK_EXECUTOR_INSTANCES="$SPARK_EXECUTOR_INSTANCES" \
        -e SPARK_DYNAMIC_ALLOCATION_ENABLED="$SPARK_DYNAMIC_ALLOCATION_ENABLED" \
        -e SPARK_SERIALIZER="$SPARK_SERIALIZER" \
        -e SPARK_SQL_ADAPTIVE_ENABLED="$SPARK_SQL_ADAPTIVE_ENABLED" \
        -e SPARK_SQL_ADAPTIVE_COALESCE_PARTITIONS_ENABLED="$SPARK_SQL_ADAPTIVE_COALESCE_PARTITIONS_ENABLED" \
        -e SPARK_SQL_ADAPTIVE_SKEW_JOIN_ENABLED="$SPARK_SQL_ADAPTIVE_SKEW_JOIN_ENABLED" \
        -e NESSIE_URI="$NESSIE_URI" \
        -e WAREHOUSE_LOCATION="$WAREHOUSE_LOCATION" \
        -e S3_ENDPOINT="$S3_ENDPOINT" \
        -e S3_ACCESS_KEY="$S3_ACCESS_KEY" \
        -e S3_SECRET_KEY="$S3_SECRET_KEY" \
        -e S3_REGION="$S3_REGION" \
        -e S3_PATH_STYLE_ACCESS="$S3_PATH_STYLE_ACCESS" \
        -e MINIO_REGION="$MINIO_REGION" \
        -e SPARK_ICEBERG_CATALOG_NAME="$SPARK_ICEBERG_CATALOG_NAME" \
        -e SPARK_ICEBERG_REF="$SPARK_ICEBERG_REF" \
        -e SPARK_ICEBERG_URI="$SPARK_ICEBERG_URI" \
        -e SPARK_ICEBERG_WAREHOUSE="$SPARK_ICEBERG_WAREHOUSE" \
        -e SPARK_ICEBERG_IO_IMPL="$SPARK_ICEBERG_IO_IMPL" \
        -e AWS_REGION="$S3_REGION" \
        -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
        -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        -e SPARK_CONF_DIR=/tmp/spark/conf \
        --health-cmd "curl -f http://localhost:4040" \
        --health-interval "${HEALTHCHECK_INTERVAL}" \
        --health-timeout "${HEALTHCHECK_TIMEOUT}" \
        --health-retries "${HEALTHCHECK_RETRIES}" \
        --health-start-period 60s \
        ghcr.io/shugur-network/shudl/spark:latest
    
    log_success "Spark Master container started"
}

# Start Spark Worker container
start_spark_worker() {
    local container_name="${COMPOSE_PROJECT_NAME}-spark-worker"
    
    log_step "Starting Spark Worker container: $container_name"
    
    if docker container inspect "$container_name" >/dev/null 2>&1; then
        if docker container inspect "$container_name" --format '{{.State.Status}}' | grep -q "running"; then
            log_info "Spark Worker container already running"
            return 0
        else
            log_info "Removing existing Spark Worker container"
            docker container rm "$container_name" >/dev/null 2>&1 || true
        fi
    fi
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -p "4041:4040" \
        -e SPARK_MODE=worker \
        -e SPARK_RPC_AUTHENTICATION_ENABLED=false \
        -e SPARK_RPC_ENCRYPTION_ENABLED=false \
        -e SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=false \
        -e SPARK_SSL_ENABLED=false \
        -e SPARK_MASTER_URL="$SPARK_MASTER_URL" \
        -e SPARK_MASTER_HOST="$SPARK_MASTER_HOST" \
        -e SPARK_UI_PORT="$SPARK_UI_PORT" \
        -e SPARK_WORKER_MEMORY="$SPARK_WORKER_MEMORY" \
        -e SPARK_WORKER_CORES="$SPARK_WORKER_CORES" \
        -e SPARK_EXECUTOR_MEMORY="$SPARK_EXECUTOR_MEMORY" \
        -e SPARK_EXECUTOR_CORES="$SPARK_EXECUTOR_CORES" \
        -e SPARK_SQL_ADAPTIVE_ENABLED="$SPARK_SQL_ADAPTIVE_ENABLED" \
        -e SPARK_SQL_ADAPTIVE_COALESCE_PARTITIONS_ENABLED="$SPARK_SQL_ADAPTIVE_COALESCE_PARTITIONS_ENABLED" \
        -e SPARK_SQL_ADAPTIVE_SKEW_JOIN_ENABLED="$SPARK_SQL_ADAPTIVE_SKEW_JOIN_ENABLED" \
        -e SPARK_ICEBERG_CATALOG_NAME="$SPARK_ICEBERG_CATALOG_NAME" \
        -e SPARK_ICEBERG_URI="$SPARK_ICEBERG_URI" \
        -e SPARK_ICEBERG_REF="$SPARK_ICEBERG_REF" \
        -e SPARK_ICEBERG_WAREHOUSE="$SPARK_ICEBERG_WAREHOUSE" \
        -e SPARK_ICEBERG_IO_IMPL="$SPARK_ICEBERG_IO_IMPL" \
        -e NESSIE_URI="$NESSIE_URI" \
        -e WAREHOUSE_LOCATION="$WAREHOUSE_LOCATION" \
        -e S3_ENDPOINT="$S3_ENDPOINT" \
        -e S3_ACCESS_KEY="$S3_ACCESS_KEY" \
        -e S3_SECRET_KEY="$S3_SECRET_KEY" \
        -e S3_REGION="$S3_REGION" \
        -e S3_PATH_STYLE_ACCESS="$S3_PATH_STYLE_ACCESS" \
        -e MINIO_REGION="$MINIO_REGION" \
        -e AWS_REGION="$S3_REGION" \
        -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
        -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        -e SPARK_CONF_DIR=/tmp/spark/conf \
        --health-cmd "curl -f http://localhost:4040" \
        --health-interval "${HEALTHCHECK_INTERVAL}" \
        --health-timeout "${HEALTHCHECK_TIMEOUT}" \
        --health-retries "${HEALTHCHECK_RETRIES}" \
        --health-start-period 60s \
        ghcr.io/shugur-network/shudl/spark:latest
    
    log_success "Spark Worker container started"
}

# Start all containers
start_all() {
    echo -e "${PURPLE}===============================================================================${NC}"
    echo -e "${PURPLE}🚀 Starting ShuDL Data Lakehouse with Docker Commands${NC}"
    echo -e "${PURPLE}===============================================================================${NC}"
    
    load_env
    create_network
    create_volumes
    
    # Start containers in dependency order
    log_step "Starting infrastructure containers (MinIO, PostgreSQL)..."
    start_minio
    start_postgresql
    
    # Wait for infrastructure to be healthy
    wait_for_container "${COMPOSE_PROJECT_NAME}-minio"
    wait_for_container "${COMPOSE_PROJECT_NAME}-postgresql"
    
    log_step "Starting data catalog service (Nessie)..."
    start_nessie
    wait_for_container "${COMPOSE_PROJECT_NAME}-nessie"
    
    log_step "Starting query engines (Trino, Spark)..."
    start_trino
    start_spark_master
    
    # Wait for Trino and Spark Master
    wait_for_container "${COMPOSE_PROJECT_NAME}-trino"
    wait_for_container "${COMPOSE_PROJECT_NAME}-spark-master"
    
    log_step "Starting Spark worker..."
    start_spark_worker
    wait_for_container "${COMPOSE_PROJECT_NAME}-spark-worker"
    
    echo
    echo -e "${GREEN}===============================================================================${NC}"
    echo -e "${GREEN}🎉 ShuDL Data Lakehouse Started Successfully!${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
    echo
    echo -e "${CYAN}📊 Service Endpoints:${NC}"
    echo -e "  • MinIO Console: ${BLUE}http://localhost:${MINIO_CONSOLE_PORT}${NC} (admin/password123)"
    echo -e "  • MinIO API: ${BLUE}http://localhost:${MINIO_API_PORT}${NC}"
    echo -e "  • PostgreSQL: ${BLUE}localhost:${POSTGRES_PORT}${NC} (nessie/nessie123)"
    echo -e "  • Nessie API: ${BLUE}http://localhost:${NESSIE_PORT}${NC}"
    echo -e "  • Trino: ${BLUE}http://localhost:${TRINO_PORT}${NC}"
    echo -e "  • Spark Master UI: ${BLUE}http://localhost:${SPARK_UI_PORT}${NC}"
    echo -e "  • Spark Worker UI: ${BLUE}http://localhost:4041${NC}"
    echo
    echo -e "${CYAN}🔧 Quick Commands:${NC}"
    echo -e "  • Check status: ${YELLOW}./run-docker.sh status${NC}"
    echo -e "  • Stop all: ${YELLOW}./run-docker.sh stop${NC}"
    echo -e "  • View logs: ${YELLOW}docker logs [container-name]${NC}"
    echo
}

# Stop all containers
stop_all() {
    load_env
    
    echo -e "${PURPLE}===============================================================================${NC}"
    echo -e "${PURPLE}🛑 Stopping ShuDL Data Lakehouse Containers${NC}"
    echo -e "${PURPLE}===============================================================================${NC}"
    
    local containers=(
        "${COMPOSE_PROJECT_NAME}-spark-worker"
        "${COMPOSE_PROJECT_NAME}-spark-master"
        "${COMPOSE_PROJECT_NAME}-trino"
        "${COMPOSE_PROJECT_NAME}-nessie"
        "${COMPOSE_PROJECT_NAME}-postgresql"
        "${COMPOSE_PROJECT_NAME}-minio"
    )
    
    for container in "${containers[@]}"; do
        if docker container inspect "$container" >/dev/null 2>&1; then
            log_step "Stopping $container"
            docker container stop "$container" >/dev/null 2>&1 || true
            docker container rm "$container" >/dev/null 2>&1 || true
            log_success "$container stopped and removed"
        else
            log_info "$container not running"
        fi
    done
    
    log_success "All containers stopped"
}

# Check status of all containers
check_status() {
    load_env
    
    echo -e "${PURPLE}===============================================================================${NC}"
    echo -e "${PURPLE}📊 ShuDL Data Lakehouse Status${NC}"
    echo -e "${PURPLE}===============================================================================${NC}"
    
    local containers=(
        "${COMPOSE_PROJECT_NAME}-minio"
        "${COMPOSE_PROJECT_NAME}-postgresql"
        "${COMPOSE_PROJECT_NAME}-nessie"
        "${COMPOSE_PROJECT_NAME}-trino"
        "${COMPOSE_PROJECT_NAME}-spark-master"
        "${COMPOSE_PROJECT_NAME}-spark-worker"
    )
    
    for container in "${containers[@]}"; do
        if docker container inspect "$container" >/dev/null 2>&1; then
            local status=$(docker container inspect "$container" --format '{{.State.Status}}')
            local health=$(docker container inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
            
            if [[ "$status" == "running" ]]; then
                if [[ "$health" == "healthy" ]]; then
                    echo -e "  ${GREEN}✅ $container${NC} - Running (Healthy)"
                elif [[ "$health" == "no-healthcheck" ]]; then
                    echo -e "  ${GREEN}✅ $container${NC} - Running (No Health Check)"
                else
                    echo -e "  ${YELLOW}⚠️  $container${NC} - Running ($health)"
                fi
            else
                echo -e "  ${RED}❌ $container${NC} - $status"
            fi
        else
            echo -e "  ${RED}❌ $container${NC} - Not Found"
        fi
    done
    
    echo
    echo -e "${CYAN}📊 Network Status:${NC}"
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Network '$NETWORK_NAME'${NC} - Exists"
    else
        echo -e "  ${RED}❌ Network '$NETWORK_NAME'${NC} - Not Found"
    fi
    
    echo
    echo -e "${CYAN}💾 Volume Status:${NC}"
    local volumes=("minio_data" "postgresql_data")
    for volume in "${volumes[@]}"; do
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Volume '$volume'${NC} - Exists"
        else
            echo -e "  ${RED}❌ Volume '$volume'${NC} - Not Found"
        fi
    done
}

# Cleanup everything (containers, networks, volumes)
cleanup_all() {
    load_env
    
    echo -e "${PURPLE}===============================================================================${NC}"
    echo -e "${PURPLE}🧹 Cleaning Up ShuDL Data Lakehouse${NC}"
    echo -e "${PURPLE}===============================================================================${NC}"
    
    log_warning "This will remove all containers, networks, and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    # Stop and remove containers
    stop_all
    
    # Remove network
    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        log_step "Removing network $NETWORK_NAME"
        docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
        log_success "Network removed"
    fi
    
    # Remove volumes
    local volumes=("minio_data" "postgresql_data")
    for volume in "${volumes[@]}"; do
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            log_step "Removing volume $volume"
            docker volume rm "$volume" >/dev/null 2>&1 || true
            log_success "Volume $volume removed"
        fi
    done
    
    log_success "Cleanup completed"
}

# Show usage
show_usage() {
    echo -e "${PURPLE}ShuDL Data Lakehouse - Docker Run Script${NC}"
    echo -e "${PURPLE}Alternative to docker-compose using plain docker commands${NC}"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 [COMMAND]"
    echo
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  ${GREEN}start${NC}     Start all ShuDL containers"
    echo -e "  ${GREEN}stop${NC}      Stop all ShuDL containers"
    echo -e "  ${GREEN}restart${NC}   Restart all ShuDL containers"
    echo -e "  ${GREEN}status${NC}    Show status of all containers"
    echo -e "  ${GREEN}cleanup${NC}   Remove all containers, networks, and volumes"
    echo -e "  ${GREEN}help${NC}      Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0 start"
    echo -e "  $0 status"
    echo -e "  $0 stop"
    echo
}

# Main script logic
main() {
    case "${1:-help}" in
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            stop_all
            sleep 2
            start_all
            ;;
        status)
            check_status
            ;;
        cleanup)
            cleanup_all
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run the main function with all arguments
main "$@" 