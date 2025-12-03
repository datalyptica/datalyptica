# Grafana - Analytics and monitoring platform
# Version: 12.3.0 (verified Nov 19, 2025) ⚠️ MAJOR UPDATE: 11.x→12.x
# Breaking: New SQLite backend, CVE-2025-41115 fix
FROM grafana/grafana:12.3.0

LABEL org.opencontainers.image.title="Datalyptica Grafana"
LABEL org.opencontainers.image.description="Custom Grafana for Datalyptica Data Platform visualization"
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

# Set ownership (grafana image uses uid 472)
RUN chown -R 472:472 /etc/grafana /var/lib/grafana

USER 472

# Expose Grafana port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1
