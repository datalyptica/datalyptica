FROM confluentinc/cp-zookeeper:7.5.0

LABEL maintainer="Datalyptica Team <devops@datalyptica.com>"
LABEL description="Zookeeper for Apache Kafka coordination"
LABEL version="7.5.0"

USER root

# Create necessary directories
RUN mkdir -p /var/lib/zookeeper/data /var/lib/zookeeper/log && \
    chown -R appuser:appuser /var/lib/zookeeper

USER appuser

EXPOSE 2181

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD nc -z localhost 2181 || exit 1
