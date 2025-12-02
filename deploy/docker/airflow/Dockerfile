# Apache Airflow Workflow Orchestration
# Enhanced with comprehensive database connectivity

FROM apache/airflow:2.8.0-python3.11

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

# Install comprehensive Airflow providers and database connectors
RUN pip install --no-cache-dir \
    # Airflow providers
    apache-airflow-providers-postgres \
    apache-airflow-providers-mysql \
    apache-airflow-providers-mongo \
    apache-airflow-providers-microsoft-mssql \
    apache-airflow-providers-oracle \
    apache-airflow-providers-amazon \
    apache-airflow-providers-apache-spark \
    apache-airflow-providers-trino \
    apache-airflow-providers-redis \
    apache-airflow-providers-docker \
    apache-airflow-providers-apache-kafka \
    # Database connectors
    psycopg2-binary \
    pymysql \
    pymongo \
    cx-Oracle \
    pyodbc \
    # Data tools
    boto3 \
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
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER airflow

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
