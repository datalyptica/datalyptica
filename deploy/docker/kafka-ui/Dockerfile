# Kafka UI - Web interface for managing and monitoring Apache Kafka
FROM provectuslabs/kafka-ui:v0.7.2

LABEL org.opencontainers.image.title="Datalyptica Kafka UI"
LABEL org.opencontainers.image.description="Custom Kafka UI for Datalyptica Data Platform"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Expose Kafka UI port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
