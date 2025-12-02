# Redis - In-memory data structure store
FROM redis:7.2-alpine

LABEL org.opencontainers.image.title="Datalyptica Redis"
LABEL org.opencontainers.image.description="Custom Redis for Datalyptica Data Lakehouse caching"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Copy custom configuration
COPY config/redis.conf /usr/local/etc/redis/redis.conf

# Create data directory
RUN mkdir -p /data && chown -R redis:redis /data

USER redis

# Expose Redis port
EXPOSE 6379

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD redis-cli ping || exit 1

# Start Redis with custom config
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
