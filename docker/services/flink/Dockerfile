FROM flink:1.18-scala_2.12-java11

LABEL maintainer="ShuDL Team <devops@shugur.com>"
LABEL description="Apache Flink stream processing framework"
LABEL version="1.18"

USER root

# Download Flink connectors (curl is already in base image)
RUN mkdir -p /opt/flink/lib/connectors && \
    # Kafka connector
    curl -L -o /opt/flink/lib/connectors/flink-sql-connector-kafka.jar \
    https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.18.0/flink-sql-connector-kafka-1.18.0.jar && \
    # Iceberg connector
    curl -L -o /opt/flink/lib/connectors/iceberg-flink-runtime.jar \
    https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.18/1.4.3/iceberg-flink-runtime-1.18-1.4.3.jar

# Copy connectors to lib directory
RUN cp /opt/flink/lib/connectors/*.jar /opt/flink/lib/

# Create necessary directories
RUN mkdir -p /opt/flink/checkpoints /opt/flink/savepoints && \
    chown -R flink:flink /opt/flink

USER flink

EXPOSE 8081 6123

# Health check - using wget since curl may not be available
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD wget --spider -q http://localhost:8081/overview || exit 1
