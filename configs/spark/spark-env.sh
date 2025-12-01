#!/bin/bash
# Spark Environment Configuration
# This file contains environment variables for Apache Spark

# Spark Home
export SPARK_HOME=/opt/spark

# Java Configuration
export JAVA_HOME=/opt/java/openjdk
export PATH=$JAVA_HOME/bin:$PATH

# Spark Configuration
export SPARK_CONF_DIR=/opt/spark/conf
export SPARK_LOG_DIR=/var/log/spark
export SPARK_PID_DIR=/var/run/spark

# Spark Master Configuration (using environment variables from docker-compose)
export SPARK_MASTER_HOST=${SPARK_MASTER_HOST:-spark}
export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7077}
export SPARK_MASTER_WEBUI_PORT=${SPARK_UI_PORT:-4040}

# Spark Worker Configuration (using environment variables from docker-compose)
export SPARK_WORKER_CORES=${SPARK_EXECUTOR_CORES:-2}
export SPARK_WORKER_MEMORY=${SPARK_EXECUTOR_MEMORY:-2g}
export SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT:-8081}

# Spark History Server Configuration (using environment variables from docker-compose)
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=${SPARK_ICEBERG_WAREHOUSE}/spark-history"

# Spark Driver Configuration (using environment variables from docker-compose)
export SPARK_DRIVER_OPTS="-Dspark.driver.memory=${SPARK_DRIVER_MEMORY} -Dspark.driver.maxResultSize=${SPARK_DRIVER_MAX_RESULT_SIZE}"

# Spark Executor Configuration (using environment variables from docker-compose)
export SPARK_EXECUTOR_OPTS="-Dspark.executor.memory=${SPARK_EXECUTOR_MEMORY} -Dspark.executor.cores=${SPARK_EXECUTOR_CORES}"

# Hadoop Configuration
export HADOOP_CONF_DIR=/opt/spark/conf
export HADOOP_HOME=/opt/hadoop

# S3 Configuration (provided via environment variables from docker-compose)
# These values are set in docker-compose.yml from .env file
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# Iceberg Configuration (using environment variables from docker-compose)
export ICEBERG_CATALOG_URI=${SPARK_ICEBERG_URI}
export ICEBERG_CATALOG_REF=${SPARK_ICEBERG_REF}
export ICEBERG_WAREHOUSE=${SPARK_ICEBERG_WAREHOUSE}

# Logging Configuration
export SPARK_LOG_LEVEL=INFO 