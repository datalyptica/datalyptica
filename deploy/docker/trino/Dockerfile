# Extend official Trino image - never rebuild from source
FROM trinodb/trino:476

LABEL maintainer="devops@datalyptica.com"
LABEL description="Extended Trino container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Trino"
LABEL org.opencontainers.image.description="Trino distributed SQL query engine for Datalyptica lakehouse analytics"

# Switch to root to add custom configurations
USER root

# Copy custom entrypoint script (configs will be mounted at runtime)
COPY scripts/entrypoint.sh /opt/trino/bin/custom-entrypoint.sh
RUN chmod +x /opt/trino/bin/custom-entrypoint.sh

# Ensure /data directory has proper ownership for trino user
RUN chown -R trino:trino /data

# Switch back to trino user
USER trino

# Official trinodb/trino image already sets WORKDIR and EXPOSE
# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/v1/status || exit 1

# Use custom entrypoint (official image will be used as fallback)
CMD ["/opt/trino/bin/custom-entrypoint.sh"] 