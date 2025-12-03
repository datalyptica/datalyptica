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

# Set AWS credentials from S3 variables for compatibility (no fallbacks - must be provided via docker-compose)
export AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY}
export AWS_REGION=${S3_REGION}

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
    echo "Web UI Port: ${SPARK_WORKER_UI_PORT:-4040}"
    
    # Process configuration templates
    process_config_templates
    
    # Docker Compose handles dependency ordering via depends_on
    echo "Starting Spark worker..."
    
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
        --webui-port ${SPARK_WORKER_UI_PORT:-4040} \
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
