FROM python:3.11-slim

LABEL maintainer="ShuDL Team <devops@shugur.com>"
LABEL description="dbt for SQL transformations on data lakehouse"
LABEL version="1.7"

USER root

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install dbt with Trino and Spark adapters
RUN pip install --no-cache-dir \
    dbt-core==1.7.4 \
    dbt-trino==1.7.1 \
    dbt-spark[PyHive]==1.7.1

# Create dbt user and directories
RUN useradd -m -u 1000 dbt && \
    mkdir -p /dbt /root/.dbt && \
    chown -R dbt:dbt /dbt /root/.dbt

# Copy profiles template
COPY services/dbt/config/profiles.yml /root/.dbt/profiles.yml

WORKDIR /dbt

USER dbt

EXPOSE 8580

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD dbt --version || exit 1

CMD ["dbt", "docs", "generate", "&&", "dbt", "docs", "serve", "--port", "8580"]
