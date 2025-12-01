# Grafana - Analytics and monitoring platform
FROM grafana/grafana:10.2.2

LABEL org.opencontainers.image.title="Datalyptica Grafana"
LABEL org.opencontainers.image.description="Custom Grafana for Datalyptica Data Lakehouse visualization"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Install additional plugins
USER root
RUN grafana-cli plugins install grafana-piechart-panel && \
    grafana-cli plugins install grafana-clock-panel && \
    grafana-cli plugins install grafana-simple-json-datasource

# Copy custom provisioning
COPY provisioning/ /etc/grafana/provisioning/
COPY dashboards/ /var/lib/grafana/dashboards/

# Set ownership
RUN chown -R grafana:grafana /etc/grafana /var/lib/grafana

USER grafana

# Expose Grafana port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1
