# Loki - Log aggregation system
FROM grafana/loki:2.9.3

LABEL org.opencontainers.image.title="Datalyptica Loki"
LABEL org.opencontainers.image.description="Custom Loki for Datalyptica Data Platform logging"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Copy custom configuration
USER root
COPY config/loki-config.yaml /etc/loki/local-config.yaml
RUN chown -R loki:loki /etc/loki
USER loki

# Expose Loki ports
EXPOSE 3100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1
