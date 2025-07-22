#!/bin/sh
set -e

# Spark Startup Script
# This script handles Spark server startup with proper configuration

# Default values
SPARK_HOME=${SPARK_HOME:-/opt/spark}
SPARK_MODE=${SPARK_MODE:-master}
SPARK_RPC_PORT=${SPARK_RPC_PORT:-7077}
SPARK_WEBUI_PORT=${SPARK_WEBUI_PORT:-8080}

# Function to wait for dependencies
wait_for_dependencies() {
    echo "Waiting for dependencies..."
    # Add any dependency waiting logic here if needed
    sleep 2
}

# Function to start Spark master directly
start_master() {
    echo "Starting Spark master..."
    echo "RPC Port: $SPARK_RPC_PORT"
    echo "Web UI Port: $SPARK_WEBUI_PORT"
    
    # Start Spark master directly without daemon scripts
    exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.master.Master \
        --host 0.0.0.0 \
        --webui-port $SPARK_WEBUI_PORT
}

# Function to start Spark worker
start_worker() {
    echo "Starting Spark worker..."
    echo "Master: $SPARK_MASTER_URL"
    echo "Cores: $SPARK_WORKER_CORES"
    echo "Memory: $SPARK_WORKER_MEMORY"
    
    exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.worker.Worker \
        --host 0.0.0.0 \
        --webui-port 4040 \
        $SPARK_MASTER_URL
}

# Function to start Spark history server
start_history() {
    echo "Starting Spark history server..."
    echo "Log Directory: s3a://lakehouse/spark-history"
    
    exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.history.HistoryServer
}

# Function to start Spark based on mode
start_spark() {
    case $SPARK_MODE in
        master)
            start_master
            ;;
        worker)
            start_worker
            ;;
        history)
            start_history
            ;;
        *)
            echo "Unknown Spark mode: $SPARK_MODE"
            echo "Supported modes: master, worker, history"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    echo "=== Spark Server Startup ==="
    echo "Mode: $SPARK_MODE"
    echo "Home: $SPARK_HOME"
    echo "Time: $(date)"
    
    # Wait for dependencies
    wait_for_dependencies
    
    # Start Spark
    start_spark
}

# Run main function
main "$@" 