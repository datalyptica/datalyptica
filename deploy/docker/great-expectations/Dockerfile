FROM python:3.11-slim

LABEL maintainer="devops@datalyptica.com"
LABEL description="Great Expectations for Datalyptica data quality validation"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Great Expectations"
LABEL org.opencontainers.image.description="Data quality and validation framework for Datalyptica data platform"

# Set environment variables
ENV GREAT_EXPECTATIONS_VERSION=0.18.19
ENV PYTHONUNBUFFERED=1
ENV GE_HOME=/opt/great_expectations

# Switch to root for installation
USER root

# Install system dependencies, create directories, install packages, and create user in combined layers
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    gcc \
    g++ \
    postgresql-client \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p ${GE_HOME}/checkpoints ${GE_HOME}/expectations ${GE_HOME}/uncommitted ${GE_HOME}/plugins ${GE_HOME}/data_docs /var/log/ge

# Install Great Expectations and connectors
RUN pip install --no-cache-dir \
    great-expectations==${GREAT_EXPECTATIONS_VERSION} \
    great-expectations-experimental \
    psycopg2-binary \
    boto3 \
    sqlalchemy \
    trino[sqlalchemy] \
    pyspark==3.5.0 \
    pyarrow \
    pandas \
    numpy \
    jupyterlab \
    ipython \
    requests \
    && groupadd -r shusr -g 1000 \
    && useradd -r -u 1000 -g shusr -d ${GE_HOME} -s /bin/bash shusr \
    && chown -R shusr:shusr ${GE_HOME} /var/log/ge

# Copy entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown shusr:shusr /entrypoint.sh

# Switch to non-root user
USER shusr

WORKDIR ${GE_HOME}

# Expose ports
EXPOSE 8888 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD python -c "import great_expectations; print('healthy')" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
