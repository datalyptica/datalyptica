# Extend official Nessie image - never rebuild from source
FROM ghcr.io/projectnessie/nessie:0.104.3

LABEL maintainer="devops@datalyptica.com"
LABEL description="Extended Nessie container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Nessie"
LABEL org.opencontainers.image.description="Project Nessie Git-like catalog for Apache Iceberg tables"

# Official nessie image already includes the Nessie server JAR, user, and configuration
# Copy custom entrypoint script for environment-specific configuration
USER root
COPY scripts/entrypoint.sh /opt/nessie/custom-entrypoint.sh
RUN chmod +x /opt/nessie/custom-entrypoint.sh

# Switch to nessie user (official image user is numeric: 10001)
USER 10001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:19120/api/v2/config || exit 1

# Use custom entrypoint
CMD ["sh", "/opt/nessie/custom-entrypoint.sh"] 