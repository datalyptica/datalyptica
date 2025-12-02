# Alertmanager - Alert handling for Prometheus
FROM prom/alertmanager:v0.27.0

LABEL org.opencontainers.image.title="Datalyptica Alertmanager"
LABEL org.opencontainers.image.description="Custom Alertmanager for Datalyptica Data Lakehouse alerts"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Copy custom configuration
USER root
COPY config/alertmanager.yml /etc/alertmanager/alertmanager.yml
COPY config/templates/ /etc/alertmanager/templates/
# Set ownership (alertmanager image uses nobody user)
RUN chown -R nobody:nobody /etc/alertmanager
USER nobody

# Expose Alertmanager ports
EXPOSE 9093

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9093/-/healthy || exit 1
