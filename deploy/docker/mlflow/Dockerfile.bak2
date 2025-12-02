# MLflow Tracking Server

FROM python:3.11-slim

# Set working directory
WORKDIR /opt/mlflow

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    postgresql-client \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install MLflow and comprehensive database drivers
RUN pip install --no-cache-dir \
    'mlflow[extras]' \
    # Database backends
    psycopg2-binary \
    pymysql \
    pymongo \
    # Cloud storage
    boto3 \
    s3fs \
    # Data manipulation
    pandas \
    numpy \
    pyarrow \
    # Lakehouse integration
    trino \
    pyspark \
    scikit-learn

# Create non-root user
RUN groupadd -r -g 1000 shusr && \
    useradd -r -u 1000 -g shusr -s /bin/bash -m shusr && \
    mkdir -p /opt/mlflow/data /opt/mlflow/artifacts && \
    chown -R shusr:shusr /opt/mlflow

# Expose MLflow ports
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Copy entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER shusr
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mlflow", "server"]
