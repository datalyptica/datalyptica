FROM alpine:3.21.3

# Metadata
LABEL maintainer="devops@shugur.com"
LABEL description="Standard PostgreSQL image for ShuDL lakehouse"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/Shugur-Network/shudl"
LABEL org.opencontainers.image.vendor="Shugur Network"
LABEL org.opencontainers.image.title="PostgreSQL"
LABEL org.opencontainers.image.description="Standard PostgreSQL image for standalone and HA variants"

# Install PostgreSQL and dependencies
RUN apk add --no-cache --update \
        postgresql \
        postgresql-contrib \
        postgresql-client \
        su-exec \
        bash \
        tzdata \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# Setup postgres user and directories (Alpine already creates postgres user)
RUN set -eux; \
    mkdir -p /var/lib/postgresql/data; \
    mkdir -p /var/run/postgresql; \
    mkdir -p /docker-entrypoint-initdb.d; \
    mkdir -p /etc/postgresql; \
    # Set ownership and permissions for all postgres directories
    chown -R postgres:postgres /var/lib/postgresql; \
    chown -R postgres:postgres /var/run/postgresql; \
    chown -R postgres:postgres /etc/postgresql; \
    chown -R postgres:postgres /docker-entrypoint-initdb.d; \
    # Set proper permissions that work with Docker volumes
    chmod 755 /var/run/postgresql; \
    chmod 755 /var/lib/postgresql; \
    chmod 755 /var/lib/postgresql/data; \
    chmod 755 /etc/postgresql; \
    chmod 755 /docker-entrypoint-initdb.d

# Set standard PostgreSQL environment variables
ENV POSTGRES_USER=postgres \
    POSTGRES_DB=postgres \
    PGDATA=/var/lib/postgresql/data \
    POSTGRES_INITDB_ARGS="--encoding=UTF-8 --lc-collate=C --lc-ctype=C"

# Copy entrypoint script and ShuDL initialization
COPY services/postgresql/scripts/docker-entrypoint.sh /usr/local/bin/
COPY services/postgresql/scripts/init-shudl-db.sh /docker-entrypoint-initdb.d/01-init-shudl-db.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /docker-entrypoint-initdb.d/01-init-shudl-db.sh \
    && chown postgres:postgres /usr/local/bin/docker-entrypoint.sh \
    && chown postgres:postgres /docker-entrypoint-initdb.d/01-init-shudl-db.sh

# Declare volumes for configuration and data
VOLUME ["/var/lib/postgresql/data", "/etc/postgresql"]

# Expose standard PostgreSQL port
EXPOSE 5432

# Set working directory
WORKDIR /var/lib/postgresql

# Run as root - entrypoint will switch to postgres user
USER root

# Standard PostgreSQL health check with proper error handling
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -h localhost -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1

# Standard PostgreSQL entrypoint and command
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]