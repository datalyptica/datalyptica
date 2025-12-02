# Extend official MinIO image - never rebuild from source
FROM minio/minio:RELEASE.2024-11-07T00-52-20Z

# Metadata
LABEL maintainer="devops@datalyptica.com"
LABEL description="Extended MinIO object storage server"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="MinIO"
LABEL org.opencontainers.image.description="MinIO object storage server for Datalyptica lakehouse data storage"

# Official minio image already includes minio and mc binaries, user, and ports
# Copy custom entrypoint if needed for initialization
USER root
COPY scripts/entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Switch to minio-user (official image user)
USER minio-user

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/minio/health/live || exit 1

# Use custom entrypoint (will call official minio server)
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"] 