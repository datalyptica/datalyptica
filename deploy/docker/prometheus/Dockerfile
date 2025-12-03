# Prometheus - Monitoring and alerting toolkit
# Version: 3.8.0 (verified Nov 28, 2025)
FROM prom/prometheus:v3.8.0

LABEL org.opencontainers.image.title="Datalyptica Prometheus"
LABEL org.opencontainers.image.description="Custom Prometheus for Datalyptica Data Platform monitoring"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Copy custom configuration
COPY config/prometheus.yml /etc/prometheus/prometheus.yml
COPY config/alerts/ /etc/prometheus/alerts/

# Set ownership (prometheus image uses nobody user)
USER root
RUN chown -R nobody:nobody /etc/prometheus
USER nobody

# Expose Prometheus port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1
