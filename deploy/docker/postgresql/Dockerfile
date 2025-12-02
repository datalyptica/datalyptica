# Extend official PostgreSQL image - never rebuild from source
FROM postgres:17-alpine

# Metadata
LABEL maintainer="devops@datalyptica.com"
LABEL description="Extended PostgreSQL image for Datalyptica lakehouse"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="PostgreSQL"
LABEL org.opencontainers.image.description="Extended PostgreSQL image for standalone and HA variants"

# Official postgres image already has all PostgreSQL components
# Just add our custom initialization scripts
COPY scripts/init-shudl-db.sh /docker-entrypoint-initdb.d/01-init-datalyptica-db.sh
RUN chmod +x /docker-entrypoint-initdb.d/01-init-datalyptica-db.sh

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