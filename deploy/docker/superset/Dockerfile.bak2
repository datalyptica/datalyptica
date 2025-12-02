# Apache Superset BI Platform

FROM apache/superset:3.0.3

# Switch to root for installations
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    redis-tools \
    curl \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Install comprehensive database drivers for all supported sources
RUN pip install --no-cache-dir \
    # Query engines & lakehouse
    trino \
    sqlalchemy-trino \
    pyhive \
    pyspark \
    # Relational databases
    psycopg2-binary \
    pymysql \
    mysqlclient \
    pyodbc \
    cx-Oracle \
    pymssql \
    # NoSQL databases
    pymongo \
    cassandra-driver \
    # Cloud storage
    boto3 \
    s3fs \
    # Superset dependencies
    redis \
    celery \
    authlib

# Create configuration directory
RUN mkdir -p /app/superset_home/config

# Set environment
ENV SUPERSET_CONFIG_PATH=/app/superset_home/superset_config.py
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
