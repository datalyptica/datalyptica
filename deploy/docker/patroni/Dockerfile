FROM ghcr.io/datalyptica/datalyptica/postgresql:v1.0.0

# Metadata
LABEL maintainer="devops@datalyptica.com"
LABEL description="PostgreSQL with Patroni for high availability"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="PostgreSQL HA with Patroni"
LABEL org.opencontainers.image.description="PostgreSQL database server with Patroni for high availability deployments"

# Set Patroni-specific environment variables
ENV PATRONI_SCOPE=lakehouse \
    ETCD_HOSTS=etcd:2379

# Switch to root for Patroni installation
USER root

# Install Patroni and dependencies
RUN apk add --no-cache --update \
    python3 \
    py3-pip \
    py3-psycopg2 \
    python3-dev \
    gcc \
    musl-dev \
    libc-dev \
    linux-headers \
    make \
    git \
    && pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore \
        patroni[etcd] \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# Create Patroni directories with proper permissions
RUN mkdir -p /etc/patroni \
    && chown -R postgres:postgres /etc/patroni \
    && chmod 755 /etc/patroni

# Copy Patroni configuration and scripts
COPY ../../configs/patroni/patroni.yml /etc/patroni/patroni.yml
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R postgres:postgres /etc/patroni \
    && chmod 664 /etc/patroni/patroni.yml

# Switch back to postgres user
USER postgres

# Expose Patroni API port
EXPOSE 8008

# Health check for Patroni
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -U postgres || exit 1

# Entrypoint and command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"] 