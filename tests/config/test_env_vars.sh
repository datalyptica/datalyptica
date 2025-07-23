#!/bin/bash

# Test: Environment Variables Validation
# Validates that all required environment variables are set correctly

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Environment Variables Validation"

# Required environment variables
declare -a REQUIRED_VARS=(
    # Global
    "COMPOSE_PROJECT_NAME"
    "NETWORK_NAME"
    
    # PostgreSQL
    "POSTGRES_DB"
    "POSTGRES_USER" 
    "POSTGRES_PASSWORD"
    "POSTGRES_PORT"
    
    # MinIO
    "MINIO_ROOT_USER"
    "MINIO_ROOT_PASSWORD"
    "MINIO_API_PORT"
    "MINIO_CONSOLE_PORT"
    "MINIO_BUCKET_NAME"
    "MINIO_REGION"
    
    # S3 Configuration
    "S3_ENDPOINT"
    "S3_ACCESS_KEY"
    "S3_SECRET_KEY"
    "S3_REGION"
    "S3_PATH_STYLE_ACCESS"
    
    # Nessie
    "NESSIE_PORT"
    "NESSIE_HOST"
    "NESSIE_VERSION_STORE_TYPE"
    "NESSIE_WAREHOUSE_LOCATION"
    "WAREHOUSE_LOCATION"
    
    # Trino
    "TRINO_PORT"
    "TRINO_COORDINATOR"
    "TRINO_INCLUDE_COORDINATOR"
    "TRINO_NODE_ENVIRONMENT"
    "TRINO_QUERY_MAX_MEMORY"
    "TRINO_CATALOG_ICEBERG_CATALOG_TYPE"
    "TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI"
    
    # Spark
    "SPARK_UI_PORT"
    "SPARK_MASTER_PORT"
    "SPARK_MASTER_URL"
    "SPARK_DRIVER_MEMORY"
    "SPARK_EXECUTOR_MEMORY"
    "SPARK_ICEBERG_CATALOG_NAME"
    "SPARK_ICEBERG_URI"
    "SPARK_HADOOP_FS_S3A_ENDPOINT"
    "SPARK_HADOOP_FS_S3A_ACCESS_KEY"
    "SPARK_HADOOP_FS_S3A_SECRET_KEY"
)

check_env_var() {
    local var_name="$1"
    if [[ -z "${!var_name:-}" ]]; then
        test_error "Environment variable $var_name is not set or empty"
        return 1
    else
        test_info "✓ $var_name = ${!var_name}"
        return 0
    fi
}

# Main test logic
cd "${SCRIPT_DIR}/../../"

# Load .env file
if [[ -f "docker/.env" ]]; then
    test_info "Loading docker/.env file..."
    set -a  # automatically export all variables
    source docker/.env
    set +a
else
    test_error "docker/.env file not found"
    exit 1
fi

test_step "Checking required environment variables..."

failed_vars=0
for var in "${REQUIRED_VARS[@]}"; do
    if ! check_env_var "$var"; then
        failed_vars=$((failed_vars + 1))
    fi
done

if [[ $failed_vars -gt 0 ]]; then
    test_error "$failed_vars required environment variables are missing or empty"
    exit 1
fi

test_step "Validating environment variable values..."

# Validate specific values
if [[ "$TRINO_CATALOG_ICEBERG_CATALOG_TYPE" != "nessie" ]]; then
    test_error "TRINO_CATALOG_ICEBERG_CATALOG_TYPE should be 'nessie', got: $TRINO_CATALOG_ICEBERG_CATALOG_TYPE"
    exit 1
fi

if [[ "$S3_PATH_STYLE_ACCESS" != "true" ]]; then
    test_error "S3_PATH_STYLE_ACCESS should be 'true' for MinIO, got: $S3_PATH_STYLE_ACCESS"
    exit 1
fi

if [[ "$NESSIE_VERSION_STORE_TYPE" != "JDBC2" ]]; then
    test_error "NESSIE_VERSION_STORE_TYPE should be 'JDBC2', got: $NESSIE_VERSION_STORE_TYPE"
    exit 1
fi

# Check port conflicts
declare -A PORTS
PORTS["PostgreSQL"]="$POSTGRES_PORT"
PORTS["MinIO API"]="$MINIO_API_PORT"
PORTS["MinIO Console"]="$MINIO_CONSOLE_PORT"
PORTS["Nessie"]="$NESSIE_PORT"
PORTS["Trino"]="$TRINO_PORT"
PORTS["Spark UI"]="$SPARK_UI_PORT"
PORTS["Spark Master"]="$SPARK_MASTER_PORT"

test_step "Checking for port conflicts..."
declare -A used_ports
for service in "${!PORTS[@]}"; do
    port="${PORTS[$service]}"
    if [[ -n "${used_ports[$port]:-}" ]]; then
        test_error "Port conflict: $service and ${used_ports[$port]} both use port $port"
        exit 1
    fi
    used_ports[$port]="$service"
    test_info "✓ $service using port $port"
done

test_step "Validating URI formats..."

# Validate URIs
if [[ "$TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI" != "http://nessie:19120/api/v2" ]]; then
    test_warning "Unexpected Nessie URI format: $TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI"
fi

if [[ "$S3_ENDPOINT" != "http://minio:9000" ]]; then
    test_warning "Unexpected S3 endpoint format: $S3_ENDPOINT"
fi

test_success "All environment variables are properly configured" 