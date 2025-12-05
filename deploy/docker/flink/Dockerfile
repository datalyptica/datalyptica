FROM flink:2.1.0-scala_2.12-java17

USER root

# Download Flink connectors during build (no compilation, just download)
# Using Flink 2.1 with compatible versions:
# - Kafka Connector 3.4.0 (certified for Flink 2.1)
# - Iceberg 1.8.0 (certified for Flink 2.1)
RUN mkdir -p /opt/flink/lib/connectors && \
    cd /opt/flink/lib/connectors && \
    curl -L -o flink-sql-connector-kafka-3.4.0-2.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-2.1/flink-sql-connector-kafka-3.4.0-2.1.jar && \
    curl -L -o iceberg-flink-runtime-2.1-1.8.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-2.1/1.8.0/iceberg-flink-runtime-2.1-1.8.0.jar && \
    ls -lh

# Download S3 filesystem plugin
RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop && \
    cd /opt/flink/plugins/s3-fs-hadoop && \
    curl -L -o flink-s3-fs-hadoop-2.1.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/2.1.0/flink-s3-fs-hadoop-2.1.0.jar && \
    ls -lh

# Fix permissions for OpenShift
RUN chmod -R 777 /opt/flink 2>/dev/null || true

# Run as non-root user
USER 1000

WORKDIR /opt/flink
