FROM confluentinc/cp-kafka:7.5.0

LABEL maintainer="Datalyptica Team <devops@datalyptica.com>"
LABEL description="Apache Kafka distributed event streaming platform"
LABEL version="7.5.0"

USER root

# Create necessary directories
RUN mkdir -p /var/lib/kafka/data && \
    chown -R appuser:appuser /var/lib/kafka

USER appuser

EXPOSE 9092 9093

# Health check
HEALTHCHECK --interval=10s --timeout=10s --retries=5 \
    CMD kafka-broker-api-versions --bootstrap-server localhost:9092 || exit 1
