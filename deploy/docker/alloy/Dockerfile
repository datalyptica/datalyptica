# Grafana Alloy - Telemetry collector
FROM grafana/alloy:v1.0.0

LABEL org.opencontainers.image.title="Datalyptica Alloy"
LABEL org.opencontainers.image.description="Custom Grafana Alloy for Datalyptica Data Platform telemetry"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Copy custom configuration
USER root
COPY config/alloy-config.alloy /etc/alloy/config.alloy
RUN chown -R alloy:alloy /etc/alloy
USER alloy

# Expose Alloy ports
EXPOSE 12345 12346

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:12345/-/healthy || exit 1
