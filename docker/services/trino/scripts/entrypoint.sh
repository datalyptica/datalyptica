#!/bin/sh
set -e

# Trino Server Entrypoint Script
echo "=== Trino Server Startup ==="
echo "Version: Trino 476"
echo "Time: $(date)"

# Function to substitute environment variables in a template
envsubst_template() {
    local template_file="$1"
    local output_file="$2"
    
    # Use shell parameter expansion to substitute variables
    while IFS= read -r line; do
        # Replace ${VAR} and ${VAR:-default} patterns
        echo "$line" | sed 's/\${[^}]*}/'"$(eval "echo \"$line\"")"'/g'
    done < "$template_file" > "$output_file"
}

# Function to generate dynamic configuration from environment variables
generate_config_properties() {
    echo "Generating config.properties from environment variables..."
    
    cat > /opt/trino/etc/config.properties << EOF
coordinator=${TRINO_COORDINATOR:-true}
node-scheduler.include-coordinator=${TRINO_NODE_SCHEDULER_INCLUDE_COORDINATOR:-true}
http-server.http.port=${TRINO_HTTP_SERVER_PORT:-8080}
discovery.uri=${TRINO_DISCOVERY_URI:-http://trino:8080}
query.max-memory=${TRINO_QUERY_MAX_MEMORY:-2GB}
memory.heap-headroom-per-node=${TRINO_MEMORY_HEAP_HEADROOM_PER_NODE:-512MB}
EOF
}

# Function to generate node.properties from environment variables
generate_node_properties() {
    echo "Generating node.properties from environment variables..."
    
    cat > /opt/trino/etc/node.properties << EOF
node.environment=${TRINO_NODE_ENVIRONMENT:-dev}
node.data-dir=${TRINO_NODE_DATA_DIR:-/data}
node.id=${TRINO_NODE_ID:-coordinator1}
EOF
}

# Function to generate JVM config from environment variables
generate_jvm_config() {
    echo "Generating jvm.config from environment variables..."
    
    # Handle boolean JVM flags properly
    local use_gc_overhead=""
    if [ "${TRINO_JVM_USE_GC_OVERHEAD_LIMIT:-true}" = "true" ]; then
        use_gc_overhead="-XX:+UseGCOverheadLimit"
    else
        use_gc_overhead="-XX:-UseGCOverheadLimit"
    fi
    
    local exit_on_oom=""
    if [ "${TRINO_JVM_EXIT_ON_OOM:-true}" = "true" ]; then
        exit_on_oom="-XX:+ExitOnOutOfMemoryError"
    else
        exit_on_oom="-XX:-ExitOnOutOfMemoryError"
    fi
    
    local allow_attach_self=""
    if [ "${TRINO_JVM_ALLOW_ATTACH_SELF:-true}" = "true" ]; then
        allow_attach_self="-Djdk.attach.allowAttachSelf=true"
    else
        allow_attach_self="-Djdk.attach.allowAttachSelf=false"
    fi
    
    cat > /opt/trino/etc/jvm.config << EOF
-server
-Xmx${TRINO_JVM_XMX:-2G}
-XX:+${TRINO_JVM_GC:-UseG1GC}
-XX:G1HeapRegionSize=${TRINO_JVM_G1_HEAP_REGION_SIZE:-32M}
${exit_on_oom}
${use_gc_overhead}
-XX:ReservedCodeCacheSize=512M
-XX:PerMethodRecompilationCutoff=10000
-XX:PerBytecodeRecompilationCutoff=10000
${allow_attach_self}
-Djdk.nio.maxCachedBufferSize=${TRINO_JVM_NIO_MAX_CACHED_BUFFER_SIZE:-2000000}
EOF
}

# Function to generate log.properties from environment variables
generate_log_properties() {
    echo "Generating log.properties from environment variables..."
    
    cat > /opt/trino/etc/log.properties << EOF
io.trino=${TRINO_LOG_LEVEL_ROOT:-INFO}
io.trino.server=${TRINO_LOG_LEVEL_SERVER:-INFO}
io.trino.execution=${TRINO_LOG_LEVEL_EXECUTION:-INFO}
io.trino.metadata=${TRINO_LOG_LEVEL_METADATA:-INFO}
io.trino.security=${TRINO_LOG_LEVEL_SECURITY:-INFO}
io.trino.spi=${TRINO_LOG_LEVEL_SPI:-INFO}
io.trino.sql=${TRINO_LOG_LEVEL_SQL:-INFO}
io.trino.transaction=${TRINO_LOG_LEVEL_TRANSACTION:-INFO}
io.trino.type=${TRINO_LOG_LEVEL_TYPE:-INFO}
io.trino.util=${TRINO_LOG_LEVEL_UTIL:-INFO}
EOF
}

# Function to generate iceberg catalog configuration from environment variables
generate_iceberg_catalog() {
    echo "Generating iceberg.properties from environment variables..."
    
    cat > /opt/trino/etc/catalog/iceberg.properties << EOF
connector.name=iceberg
iceberg.catalog.type=${TRINO_CATALOG_ICEBERG_CATALOG_TYPE:-nessie}
iceberg.nessie-catalog.uri=${TRINO_CATALOG_ICEBERG_REST_CATALOG_URI:-http://shudl-nessie:19120/api/v2}
iceberg.nessie-catalog.default-warehouse-dir=${TRINO_CATALOG_ICEBERG_REST_CATALOG_WAREHOUSE:-s3://lakehouse/}
iceberg.nessie-catalog.ref=${TRINO_ICEBERG_REF:-main}
fs.native-s3.enabled=${FS_NATIVE_S3_ENABLED:-true}
s3.endpoint=${TRINO_CATALOG_ICEBERG_S3_ENDPOINT:-http://shudl-minio:9000}
s3.region=${TRINO_CATALOG_ICEBERG_S3_REGION:-us-east-1}
s3.aws-access-key=${TRINO_CATALOG_ICEBERG_S3_ACCESS_KEY:-admin}
s3.aws-secret-key=${TRINO_CATALOG_ICEBERG_S3_SECRET_KEY:-password123}
s3.path-style-access=${TRINO_CATALOG_ICEBERG_S3_PATH_STYLE_ACCESS:-true}
iceberg.file-format=${ICEBERG_FILE_FORMAT:-PARQUET}
iceberg.compression-codec=${ICEBERG_COMPRESSION_CODEC:-SNAPPY}
EOF
}

# Function to process configuration templates
process_config_templates() {
    echo "Using dynamic configuration with environment variables..."
    
    # Generate all configuration files from environment variables
    generate_config_properties
    generate_node_properties
    generate_jvm_config
    generate_log_properties
    generate_iceberg_catalog
    
    echo "Configuration files generated successfully."
}

# Function to validate required environment variables
validate_environment() {
    echo "Using dynamic configuration with environment variables for production deployment."
    echo "All configuration files will be generated from environment variables."
}

# Function to wait for dependencies
wait_for_dependencies() {
    echo "Waiting for Nessie to be ready..."
    
    max_attempts=30
    attempt=1
    nessie_host="${NESSIE_HOST:-nessie}"
    nessie_port="${NESSIE_PORT:-19120}"
    
    while [ $attempt -le $max_attempts ]; do
        # Use wget instead of nc for compatibility
        if wget -q --timeout=2 --tries=1 -O /dev/null "http://$nessie_host:$nessie_port/api/v2/config" >/dev/null 2>&1; then
            echo "Nessie is ready!"
            return 0
        fi
        
        echo "Nessie is not ready yet. Attempt $attempt/$max_attempts. Waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "WARNING: Nessie failed to become ready after $max_attempts attempts"
    echo "Continuing with Trino startup..."
}

# Function to start Trino server
start_trino() {
    echo "Starting Trino server..."
    echo "Coordinator: ${TRINO_COORDINATOR:-true}"
    echo "Discovery URI: ${TRINO_DISCOVERY_URI:-http://trino:8080}"
    echo "Nessie URI: ${NESSIE_URI:-http://shudl-nessie:19120/iceberg/main/}"
    echo "S3 Endpoint: ${S3_ENDPOINT:-http://shudl-minio:9000}"
    
    cd /opt/trino
    
    # Start Trino server
    exec ./bin/launcher run
}

# Main execution
main() {
    # Validate environment variables
    validate_environment
    
    # Process configuration templates
    process_config_templates
    
    # Wait for dependencies
    wait_for_dependencies
    
    # Start Trino server
    start_trino
}

# Run main function
main "$@"
