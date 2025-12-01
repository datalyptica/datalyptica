# Apache Airflow Workflow Orchestration
# Multi-stage build to reduce final image size

# Build stage: Install dependencies
FROM apache/airflow:2.8.0-python3.11 AS builder

USER root

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install Python packages in builder stage
RUN pip install --no-cache-dir --user \
    apache-airflow-providers-postgres==5.10.0 \
    apache-airflow-providers-amazon==8.16.0 \
    apache-airflow-providers-apache-spark==4.6.0 \
    apache-airflow-providers-trino==5.6.0 \
    apache-airflow-providers-redis==3.5.0 \
    apache-airflow-providers-docker==3.9.0 \
    great-expectations==0.18.19 \
    mlflow==2.9.2 \
    psycopg2-binary==2.9.9 \
    boto3==1.34.19 \
    pyspark==3.5.0 \
    trino==0.328.0 \
    'redis>=4.5.2,<5.0.0'

# Final stage: Runtime image
FROM apache/airflow:2.8.0-python3.11

USER root

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/airflow/dags /opt/airflow/logs /opt/airflow/plugins /opt/airflow/config \
    && chown -R airflow:root /opt/airflow

USER airflow

# Copy installed packages from builder
COPY --from=builder --chown=airflow:root /home/airflow/.local /home/airflow/.local

# Expose Airflow webserver port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD airflow jobs check --job-type SchedulerJob --hostname "$${HOSTNAME}" || exit 1

# Copy entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER airflow

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
