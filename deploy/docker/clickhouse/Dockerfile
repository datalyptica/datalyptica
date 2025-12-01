FROM clickhouse/clickhouse-server:23.8

LABEL maintainer="Datalyptica Team <devops@datalyptica.com>"
LABEL description="ClickHouse OLAP database for real-time analytics"
LABEL version="23.11"

USER root

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/lib/clickhouse /var/log/clickhouse-server && \
    chown -R clickhouse:clickhouse /var/lib/clickhouse /var/log/clickhouse-server

# Configuration will be mounted at runtime
# COPY ../../configs/clickhouse/users.xml /etc/clickhouse-server/users.d/
# COPY ../../configs/clickhouse/config.xml /etc/clickhouse-server/config.d/

USER clickhouse

EXPOSE 8123 9000 9009

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD clickhouse-client --query "SELECT 1" || exit 1
