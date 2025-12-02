# JupyterLab Notebook Image for JupyterHub Spawner
# Optimized for data platform with comprehensive database connectivity

FROM jupyter/scipy-notebook:python-3.11

USER root

# Fix potential GPG issues and install system dependencies
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    postgresql-client \
    mariadb-client \
    vim \
    openjdk-11-jdk-headless \
    build-essential \
    pkg-config \
    libpq-dev \
    libmariadb-dev \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

USER jovyan

# Install comprehensive Python packages for data engineering
RUN pip install --no-cache-dir \
    # Database connectors
    psycopg2-binary \
    pymysql \
    mysqlclient \
    pymongo \
    pyodbc \
    cx-Oracle \
    # Cloud storage
    boto3 \
    s3fs \
    # Data lakehouse
    trino \
    pyspark \
    # Data manipulation
    sqlalchemy \
    pandas \
    numpy \
    pyarrow \
    polars \
    'dask[complete]' \
    # Visualization
    plotly \
    seaborn \
    matplotlib \
    altair \
    # ML/AI
    scikit-learn \
    xgboost \
    lightgbm \
    # Utilities
    jupyterlab-git \
    ipywidgets \
    nbconvert

USER root

# Set JAVA_HOME for PySpark
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV SPARK_HOME=/usr/local/spark
ENV PATH=$PATH:$SPARK_HOME/bin

USER jovyan

# Create work directory
RUN mkdir -p /home/jovyan/work

WORKDIR /home/jovyan/work
