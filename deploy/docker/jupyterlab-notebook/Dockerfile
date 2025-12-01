# JupyterLab Notebook Image for JupyterHub Spawner
# Multi-stage build to reduce final image size

# Build stage: Install dependencies
FROM jupyter/scipy-notebook:python-3.11 AS builder

USER root

# Install build dependencies and Java
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

USER jovyan

# Install Python packages in builder stage
RUN pip install --no-cache-dir --user \
    psycopg2-binary==2.9.9 \
    boto3==1.34.19 \
    trino==0.328.0 \
    pyspark==3.5.0 \
    great-expectations==0.18.19 \
    mlflow==2.9.2 \
    pyiceberg[sql-postgres,s3fs]==0.5.1 \
    dbt-core==1.7.4 \
    dbt-trino==1.7.1 \
    sqlalchemy==2.0.23 \
    pandas==2.1.4 \
    numpy==1.26.3 \
    pyarrow==14.0.2 \
    plotly==5.18.0 \
    seaborn==0.13.1 \
    scikit-learn==1.4.0

# Final stage: Runtime image
FROM jupyter/scipy-notebook:python-3.11

USER root

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    postgresql-client \
    vim \
    openjdk-11-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME for PySpark
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV SPARK_HOME=/usr/local/spark
ENV PATH=$PATH:$SPARK_HOME/bin

USER jovyan

# Copy installed packages from builder
COPY --from=builder --chown=jovyan:users /home/jovyan/.local /home/jovyan/.local

# Create work directory
RUN mkdir -p /home/jovyan/work

WORKDIR /home/jovyan/work
