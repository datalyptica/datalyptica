#!/bin/sh
set -e

# Nessie Server Entrypoint Script
echo "=== Nessie Server Startup ==="
echo "Version: $(java -version 2>&1 | head -n 1)"
echo "Time: $(date)"

# Function to process configuration templates
process_config_templates() {
    echo "Processing Nessie configuration templates..."
    
    # Process application.properties template if it exists
    if [ -f "/opt/nessie/config/application.properties.template" ]; then
        echo "Processing application.properties template..."
        envsubst < /opt/nessie/config/application.properties.template > /opt/nessie/config/application.properties
        echo "Configuration template processed successfully."
    else
        echo "No application.properties template found, using default configuration"
    fi
}

# Function to load secrets from files
load_secrets() {
    echo "Loading secrets from files..."
    
    # Load database password from secret file if exists
    if [ -f "/run/secrets/nessie_password" ]; then
        export QUARKUS_DATASOURCE_PASSWORD=$(cat /run/secrets/nessie_password)
        echo "✓ Loaded database password from secret file"
    elif [ -n "$NESSIE_PASSWORD_FILE" ] && [ -f "$NESSIE_PASSWORD_FILE" ]; then
        export QUARKUS_DATASOURCE_PASSWORD=$(cat "$NESSIE_PASSWORD_FILE")
        echo "✓ Loaded database password from $NESSIE_PASSWORD_FILE"
    elif [ -z "$QUARKUS_DATASOURCE_PASSWORD" ]; then
        echo "WARNING: No database password found in secrets or environment"
    fi
}

# Function to validate required environment variables
validate_environment() {
    echo "Validating required environment variables..."
    
    local missing_vars=""
    
    # Check for required database variables
    [ -z "$QUARKUS_DATASOURCE_USERNAME" ] && missing_vars="$missing_vars QUARKUS_DATASOURCE_USERNAME"
    [ -z "$POSTGRES_DB" ] && missing_vars="$missing_vars POSTGRES_DB"
    
    # Check for required S3 variables
    [ -z "$S3_ACCESS_KEY" ] && missing_vars="$missing_vars S3_ACCESS_KEY"
    [ -z "$S3_SECRET_KEY" ] && missing_vars="$missing_vars S3_SECRET_KEY"
    
    if [ -n "$missing_vars" ]; then
        echo "ERROR: Missing required environment variables:$missing_vars"
        echo "Please set these variables in your docker-compose.yml or .env file"
        exit 1
    fi
    
    # Check password after loading secrets
    if [ -z "$QUARKUS_DATASOURCE_PASSWORD" ]; then
        echo "ERROR: Database password not found. Check secrets configuration."
        exit 1
    fi
    
    echo "Environment validation passed."
}

# Function to wait for PostgreSQL
wait_for_postgresql() {
    echo "Waiting for PostgreSQL to be ready..."
    
    local max_attempts=30
    local attempt=1
    local host="${POSTGRES_HOST:-postgresql}"
    local port="${POSTGRES_PORT:-5432}"
    
    while [ $attempt -le $max_attempts ]; do
        # Use nc (netcat) or timeout+sh to check if port is open
        if timeout 1 sh -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
            echo "PostgreSQL is ready!"
            return 0
        fi
        
        echo "PostgreSQL is not ready yet. Attempt $attempt/$max_attempts. Waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: PostgreSQL failed to become ready after $max_attempts attempts"
    exit 1
}

# Function to start Nessie server
start_nessie() {
    echo "Starting Nessie server..."
    echo "Database: jdbc:postgresql://${POSTGRES_HOST:-postgresql}:5432/$POSTGRES_DB"
    echo "User: $QUARKUS_DATASOURCE_USERNAME"
    echo "S3 Endpoint: ${S3_ENDPOINT:-http://minio:9000}"
    echo "Warehouse: ${WAREHOUSE_LOCATION:-s3://lakehouse/}"
    
    # Use the official Nessie entrypoint
    exec java -jar /deployments/quarkus-run.jar
}

# Main execution
main() {
    # Load secrets from files first
    load_secrets
    
    # Validate environment variables
    validate_environment
    
    # Process configuration templates
    process_config_templates
    
    # Wait for dependencies
    wait_for_postgresql
    
    # Start Nessie server
    start_nessie
}

# Run main function
main "$@"
