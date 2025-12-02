FROM apache/kafka:4.1.1

LABEL maintainer="Datalyptica Team <devops@datalyptica.com>"
LABEL description="Apache Kafka distributed event streaming platform"
LABEL version="4.1.1"

USER root

# Install netcat for healthchecks
RUN microdnf install -y nc && microdnf clean all

# Create necessary directories
RUN mkdir -p /var/lib/kafka/data && \
    chown -R kafka:kafka /var/lib/kafka

USER kafka

EXPOSE 9092 9094

# Health check will be defined in docker-compose.yml
