FROM apache/flink:1.20.3-scala_2.12-java11

USER root

# Install Python 3 and PyFlink dependencies (optional for Python jobs)
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-dev && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    pip3 install --no-cache-dir apache-flink==1.20.3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download Flink connectors to /opt/flink/lib/ for automatic classpath
# Using Flink 1.20.3 LTS with proven stable versions
RUN cd /opt/flink/lib && \
    curl -L -o flink-sql-connector-kafka-3.4.0-1.20.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-1.20/flink-sql-connector-kafka-3.4.0-1.20.jar && \
    curl -L -o iceberg-flink-runtime-1.20-1.7.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.20/1.7.1/iceberg-flink-runtime-1.20-1.7.1.jar && \
    curl -L -o flink-sql-connector-hive-2.3.9_2.12-1.20.3.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-hive-2.3.9_2.12/1.20.3/flink-sql-connector-hive-2.3.9_2.12-1.20.3.jar && \
    curl -L -o hadoop-common-2.8.3.jar \
      https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/2.8.3/hadoop-common-2.8.3.jar && \
    curl -L -o flink-shaded-hadoop-2-uber-2.8.3-10.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar && \
    curl -L -o bundle-2.29.39.jar \
      https://repo.maven.apache.org/maven2/software/amazon/awssdk/bundle/2.29.39/bundle-2.29.39.jar && \
    curl -L -o s3-2.29.39.jar \
      https://repo.maven.apache.org/maven2/software/amazon/awssdk/s3/2.29.39/s3-2.29.39.jar && \
    curl -L -o kafka_2.13-3.9.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/kafka/kafka_2.13/3.9.0/kafka_2.13-3.9.0.jar && \
    curl -L -o kafka-clients-3.9.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/kafka/kafka-clients/3.9.0/kafka-clients-3.9.0.jar && \
    curl -L -o flink-parquet-1.20.3.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-parquet/1.20.3/flink-parquet-1.20.3.jar && \
    curl -L -o avro-1.11.3.jar \
      https://repo.maven.apache.org/maven2/org/apache/avro/avro/1.11.3/avro-1.11.3.jar && \
    curl -L -o parquet-hadoop-1.13.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/parquet/parquet-hadoop/1.13.1/parquet-hadoop-1.13.1.jar && \
    curl -L -o parquet-avro-1.13.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/parquet/parquet-avro/1.13.1/parquet-avro-1.13.1.jar && \
    curl -L -o parquet-column-1.13.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/parquet/parquet-column/1.13.1/parquet-column-1.13.1.jar && \
    curl -L -o parquet-common-1.13.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/parquet/parquet-common/1.13.1/parquet-common-1.13.1.jar && \
    echo "Flink connectors installed successfully" && \
    ls -lh

# Download S3 filesystem plugin
RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop && \
    cd /opt/flink/plugins/s3-fs-hadoop && \
    curl -L -o flink-s3-fs-hadoop-1.20.3.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.3/flink-s3-fs-hadoop-1.20.3.jar && \
    ls -lh

# Fix permissions for OpenShift
RUN chmod -R 777 /opt/flink 2>/dev/null || true

# Run as non-root user
USER 1000

WORKDIR /opt/flink
