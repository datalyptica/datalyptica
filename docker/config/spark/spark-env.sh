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

# Spark Master Configuration
export SPARK_MASTER_HOST=spark
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=8080

# Spark Worker Configuration
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=2g
export SPARK_WORKER_WEBUI_PORT=8081

# Spark History Server Configuration
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=s3a://lakehouse/spark-history"

# Spark Driver Configuration
export SPARK_DRIVER_OPTS="-Dspark.driver.memory=2g -Dspark.driver.maxResultSize=1g"

# Spark Executor Configuration
export SPARK_EXECUTOR_OPTS="-Dspark.executor.memory=2g -Dspark.executor.cores=2"

# Hadoop Configuration
export HADOOP_CONF_DIR=/opt/spark/conf
export HADOOP_HOME=/opt/hadoop

# S3 Configuration (provided via environment variables at runtime)
# These values are set in docker-compose.yml from .env file
# DO NOT hardcode credentials here - use environment variables
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-minioadmin}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-CHANGE_ME_SECURE_PASSWORD}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-${MINIO_REGION:-us-east-1}}

# Iceberg Configuration (using environment variables)
export ICEBERG_CATALOG_URI=${NESSIE_URI:-http://nessie:19120/api/v2}
export ICEBERG_CATALOG_REF=main
export ICEBERG_WAREHOUSE=${WAREHOUSE_LOCATION:-s3a://lakehouse/}

# Logging Configuration
export SPARK_LOG_LEVEL=INFO 