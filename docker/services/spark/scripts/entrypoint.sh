#!/bin/sh

# Function to process configuration templates
process_config_templates() {
    echo "Processing configuration templates..."
    
    # Create a writable config directory
    mkdir -p /tmp/spark/conf
    
    # Process spark-defaults.conf template if it exists
    if [ -f "/opt/spark/conf/spark-defaults.conf.template" ]; then
        echo "Processing spark-defaults.conf template..."
        envsubst < /opt/spark/conf/spark-defaults.conf.template > /tmp/spark/conf/spark-defaults.conf
        # Set the config directory for Spark
        export SPARK_CONF_DIR=/tmp/spark/conf
    fi
    
    echo "Configuration templates processed."
}

# Set default AWS environment variables if not provided (for development only)
export AWS_REGION=${AWS_REGION:-us-east-1}

# Validate required environment variables
if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "WARNING: S3_ACCESS_KEY and S3_SECRET_KEY environment variables should be set"
    echo "Using fallback values for development (not secure for production)"
    export S3_ACCESS_KEY=${S3_ACCESS_KEY:-minioadmin}
    export S3_SECRET_KEY=${S3_SECRET_KEY:-"CHANGE_ME"}
fi

# Set AWS credentials from S3 variables for compatibility
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-$S3_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-$S3_SECRET_KEY}

# Install additional Python packages if needed (check if already installed)
install_python_packages() {
    echo "Checking Python package dependencies..."
    
    # Check if packages are installed, install if missing
    python3 -c "import pandas" 2>/dev/null || pip3 install pandas==2.3.0
    python3 -c "import numpy" 2>/dev/null || pip3 install numpy==2.0.2
    python3 -c "import requests" 2>/dev/null || pip3 install requests==2.32.4
    
    echo "Python packages verified/installed."
}

# Run package installation check
install_python_packages

# Function to start Spark master
start_master() {
    echo "Starting Spark master..."
    echo "Web UI Port: ${SPARK_WEBUI_PORT:-4040}"
    echo "RPC Port: 7077"
    echo "Daemon Memory: ${SPARK_DAEMON_MEMORY:-1g}"
    
    # Process configuration templates
    process_config_templates
    
    # Start Spark master directly without daemon scripts
    HADOOP_USER_NAME=spark \
    USER=spark \
    exec ${SPARK_HOME}/bin/spark-class \
        -Xmx${SPARK_DAEMON_MEMORY:-1g} \
        -Dhadoop.security.authentication=simple \
        -Dhadoop.security.authorization=false \
        -Duser.name=spark \
        -DHADOOP_USER_NAME=spark \
        org.apache.spark.deploy.master.Master \
        --host 0.0.0.0 \
        --port 7077 \
        --webui-port ${SPARK_WEBUI_PORT:-4040}
}

# Function to start Spark worker
start_worker() {
    echo "Starting Spark worker..."
    echo "Master: $SPARK_MASTER_URL"
    echo "Cores: ${SPARK_WORKER_CORES:-2}"
    echo "Memory: ${SPARK_WORKER_MEMORY:-2g}"
    echo "Daemon Memory: ${SPARK_DAEMON_MEMORY:-1g}"
    echo "Web UI Port: 4040"
    
    # Process configuration templates
    process_config_templates
    
    # Wait for master to be available
    echo "Waiting for Spark master to be ready..."
    while ! nc -z ${SPARK_MASTER_HOST:-spark-master} 7077; do
        echo "Waiting for Spark master..."
        sleep 2
    done
    echo "Spark master is ready!"
    
    HADOOP_USER_NAME=spark \
    USER=spark \
    exec ${SPARK_HOME}/bin/spark-class \
        -Xmx${SPARK_DAEMON_MEMORY:-1g} \
        -Dhadoop.security.authentication=simple \
        -Dhadoop.security.authorization=false \
        -Duser.name=spark \
        -DHADOOP_USER_NAME=spark \
        org.apache.spark.deploy.worker.Worker \
        --host 0.0.0.0 \
        --cores ${SPARK_WORKER_CORES:-2} \
        --memory ${SPARK_WORKER_MEMORY:-2g} \
        --webui-port 4040 \
        ${SPARK_MASTER_URL}
}

# Function to start Spark shell
start_shell() {
    echo "Starting Spark shell..."
    $SPARK_HOME/bin/spark-shell
}

# Function to start PySpark shell
start_pyspark() {
    echo "Starting PySpark shell..."
    $SPARK_HOME/bin/pyspark
}

# Function to start Spark SQL shell
start_sql() {
    echo "Starting Spark SQL shell..."
    $SPARK_HOME/bin/spark-sql
}

# Main logic
case "${SPARK_MODE:-master}" in
    "master")
        start_master
        ;;
    "worker")
        start_worker
        ;;
    "shell")
        start_shell
        ;;
    "pyspark")
        start_pyspark
        ;;
    "sql")
        start_sql
        ;;
    *)
        echo "Unknown SPARK_MODE: $SPARK_MODE"
        echo "Available modes: master, worker, shell, pyspark, sql"
        exit 1
        ;;
esac
