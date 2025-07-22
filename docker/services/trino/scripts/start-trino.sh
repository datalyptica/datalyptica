#!/bin/sh
set -e

# Trino Startup Script
# This script handles Trino server startup with proper configuration

# Default values
TRINO_HOME=${TRINO_HOME:-/opt/trino}
TRINO_PORT=${TRINO_PORT:-8080}

# Function to wait for dependencies
wait_for_dependencies() {
    echo "Waiting for dependencies..."
    # Add any dependency waiting logic here if needed
    sleep 2
}

# Function to start Trino
start_trino() {
    echo "Starting Trino server..."
    echo "Home: $TRINO_HOME"
    echo "Port: $TRINO_PORT"
    
    # Start Trino
    exec ${TRINO_HOME}/bin/launcher "$@"
}

# Main execution
main() {
    echo "=== Trino Server Startup ==="
    echo "Version: $(java -version 2>&1 | head -n 1)"
    echo "Time: $(date)"
    
    # Wait for dependencies
    wait_for_dependencies
    
    # Start Trino
    start_trino "$@"
}

# Run main function
main "$@" 