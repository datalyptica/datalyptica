#!/bin/sh
set -e

# Trino Server Entrypoint Script
echo "=== Trino Server Startup ==="
echo "Version: Trino 458"
echo "Time: $(date)"

# Function to process configuration templates
process_config_templates() {
    echo "Using pre-configured Trino configuration files..."
    echo "Configuration files are mounted as read-only volumes."
    
    # Verify iceberg.properties exists
    if [ -f "/opt/trino/etc/catalog/iceberg.properties" ]; then
        echo "Iceberg catalog configuration found."
    else
        echo "ERROR: iceberg.properties not found in catalog directory"
        exit 1
    fi
}

# Function to validate required environment variables
validate_environment() {
    echo "Using static configuration with hardcoded values for development."
    echo "Note: For production deployment, consider using dynamic configuration with environment variables."
}

# Function to wait for dependencies
wait_for_dependencies() {
    echo "Waiting for Nessie to be ready..."
    
    max_attempts=30
    attempt=1
    nessie_host="nessie"
    nessie_port="19120"
    
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
    echo "Nessie URI: ${NESSIE_URI:-http://nessie:19120/iceberg/main/}"
    echo "S3 Endpoint: ${S3_ENDPOINT:-http://minio:9000}"
    
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
