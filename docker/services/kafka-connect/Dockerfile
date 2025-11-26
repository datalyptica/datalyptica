FROM confluentinc/cp-kafka-connect:7.5.0

LABEL maintainer="ShuDL Team <devops@shugur.com>"
LABEL description="Kafka Connect with Debezium CDC connectors"
LABEL version="7.5.0"

USER root

# Install Debezium connectors
RUN mkdir -p /usr/share/java/debezium && \
    cd /usr/share/java/debezium && \
    # PostgreSQL connector
    curl -o debezium-connector-postgres.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.4.0.Final/debezium-connector-postgres-2.4.0.Final-plugin.tar.gz && \
    tar -xzf debezium-connector-postgres.tar.gz && \
    rm debezium-connector-postgres.tar.gz && \
    # MySQL connector
    curl -o debezium-connector-mysql.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.4.0.Final/debezium-connector-mysql-2.4.0.Final-plugin.tar.gz && \
    tar -xzf debezium-connector-mysql.tar.gz && \
    rm debezium-connector-mysql.tar.gz && \
    # MongoDB connector
    curl -o debezium-connector-mongodb.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-mongodb/2.4.0.Final/debezium-connector-mongodb-2.4.0.Final-plugin.tar.gz && \
    tar -xzf debezium-connector-mongodb.tar.gz && \
    rm debezium-connector-mongodb.tar.gz

# Copy connectors to plugin path
RUN cp -r /usr/share/java/debezium/* /usr/share/confluent-hub-components/

# Create necessary directories
RUN mkdir -p /var/lib/kafka-connect && \
    chown -R appuser:appuser /var/lib/kafka-connect

USER appuser

EXPOSE 8083

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8083/ || exit 1
