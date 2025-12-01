FROM alpine:3.21.3

# Metadata
LABEL maintainer="devops@datalyptica.com"
LABEL description="MinIO object storage server"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="MinIO"
LABEL org.opencontainers.image.description="MinIO object storage server for Datalyptica lakehouse data storage"

# Set build arguments for architecture
ARG TARGETARCH

# Set environment variables (credentials provided via docker-compose)
ENV MINIO_VOLUMES="/data" \
    MINIO_OPTS="--console-address :9001"

# Switch to root for installation
USER root

# Install dependencies, create user, download binaries, and setup directories in one layer
RUN apk add --no-cache curl \
    && addgroup -g 1001 -S minio \
    && adduser -u 1001 -S -G minio -h /home/minio -s /bin/sh minio \
    && set -eux; \
    if [ "$TARGETARCH" = "amd64" ]; then \
      MINIO_URL="https://dl.min.io/server/minio/release/linux-amd64/minio"; \
      MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      MINIO_URL="https://dl.min.io/server/minio/release/linux-arm64/minio"; \
      MC_URL="https://dl.min.io/client/mc/release/linux-arm64/mc"; \
    else \
      echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi; \
    wget -O /usr/local/bin/minio "$MINIO_URL" || (echo "Failed to download $MINIO_URL" && exit 1); \
    chmod +x /usr/local/bin/minio; \
    wget -O /usr/local/bin/mc "$MC_URL" || (echo "Failed to download $MC_URL" && exit 1); \
    chmod +x /usr/local/bin/mc; \
    rm -rf /tmp/* \
    && mkdir -p /data /home/minio/.minio \
    && chown -R minio:minio /data /home/minio

# Copy MinIO scripts
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to minio user
USER minio

# Expose ports
EXPOSE 9000 9001

# Set working directory
WORKDIR /data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/minio/health/live || exit 1

# Entrypoint and command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["server", "/data", "--console-address", ":9001"] 