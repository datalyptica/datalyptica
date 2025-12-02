# Apache Airflow Workflow Orchestration
# Enhanced with comprehensive database connectivity

FROM apache/airflow:3.1.3-python3.13

USER root

# Fix GPG issues and install system dependencies with database clients
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    postgresql-client \
    mariadb-client \
    redis-tools \
    vim \
    gcc \
    g++ \
    libpq-dev \
    libmariadb-dev \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install additional Airflow providers and database connectors
# Do NOT reinstall airflow itself, just add providers
RUN pip install --no-cache-dir \
    # Core Auth Provider for Airflow 3.x with all dependencies
    'apache-airflow-providers-fab>=1.0.0' \
    'Flask-AppBuilder>=4.3.0' \
    # Additional Airflow providers
    apache-airflow-providers-apache-spark \
    apache-airflow-providers-trino \
    # Database connectors not in base image  
    cx-Oracle \
    # Data tools
    pyspark \
    trino \
    'redis>=4.5.2,<5.0.0'

USER root
RUN mkdir -p /opt/airflow/dags /opt/airflow/logs /opt/airflow/plugins /opt/airflow/config \
    && chown -R airflow:root /opt/airflow

USER airflow

# Expose Airflow webserver port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD airflow jobs check --job-type SchedulerJob --hostname "$${HOSTNAME}" || exit 1

# Copy entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/create_user.py /usr/local/bin/create_user.py
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER airflow

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
