#!/bin/sh
set -e

# MinIO Entrypoint Script
# This script handles MinIO server startup with proper initialization

# Default values (these should be overridden by environment variables)
MINIO_ROOT_USER=${MINIO_ROOT_USER:-admin}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-""}
MINIO_VOLUMES=${MINIO_VOLUMES:-"/data"}
MINIO_OPTS=${MINIO_OPTS:-"--console-address :9001"}

# Validate required environment variables
if [ -z "$MINIO_ROOT_PASSWORD" ]; then
    echo "ERROR: MINIO_ROOT_PASSWORD environment variable is required"
    echo "Please set MINIO_ROOT_PASSWORD in your environment or docker-compose.yml"
    exit 1
fi

# Function to wait for dependencies
wait_for_dependencies() {
    echo "Waiting for dependencies..."
    # Add any dependency waiting logic here if needed
    sleep 2
}

# Function to create default bucket
create_default_bucket() {
    echo "Creating default bucket 'lakehouse'..."
    
    # Wait for MinIO to be ready
    until mc alias set myminio http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null; do
        echo "Waiting for MinIO to be ready..."
        sleep 2
    done
    
    # Create lakehouse bucket if it doesn't exist
    if ! mc ls myminio/lakehouse >/dev/null 2>&1; then
        echo "Creating lakehouse bucket..."
        mc mb myminio/lakehouse
        echo "Lakehouse bucket created successfully"
    else
        echo "Lakehouse bucket already exists"
    fi
}

# Function to start MinIO server
start_minio() {
    echo "Starting MinIO server..."
    echo "Root User: ${MINIO_ROOT_USER}"
    echo "Volumes: ${MINIO_VOLUMES}"
    echo "Options: ${MINIO_OPTS}"
    
    # Export environment variables for MinIO
    export MINIO_ROOT_USER=${MINIO_ROOT_USER}
    export MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    
    # Start MinIO server in background
    exec minio server ${MINIO_VOLUMES} ${MINIO_OPTS} &
    MINIO_PID=$!
    
    # Wait for MinIO to start
    echo "Waiting for MinIO to start..."
    sleep 5
    
    # Create default bucket
    create_default_bucket
    
    # Wait for MinIO process
    wait $MINIO_PID
}

# Main execution
main() {
    echo "=== MinIO Server Startup ==="
    echo "Version: $(minio version)"
    echo "Time: $(date)"
    
    # Wait for dependencies
    wait_for_dependencies
    
    # Start MinIO server
    start_minio
}

# Run main function
main "$@" 