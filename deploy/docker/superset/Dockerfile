# Apache Superset BI Platform

FROM apache/superset:3.0.3

# Switch to root for installations
USER root

# Install additional dependencies
RUN pip install --no-cache-dir \
    trino==0.328.0 \
    psycopg2-binary==2.9.9 \
    redis==5.0.1 \
    celery==5.3.4 \
    authlib==1.3.0 \
    pyhive==0.7.0 \
    sqlalchemy-trino==0.5.0

# Create configuration directory
RUN mkdir -p /app/superset_home/config

# Set environment
ENV SUPERSET_CONFIG_PATH=/app/superset_home/config/superset_config.py
ENV SUPERSET_HOME=/app/superset_home

# Copy entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to superset user
USER superset

# Expose Superset port
EXPOSE 8088

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8088/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8088", "superset.app:create_app()"]
