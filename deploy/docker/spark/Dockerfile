FROM eclipse-temurin:17-jre

LABEL maintainer="devops@datalyptica.com"
LABEL description="Custom Spark with Iceberg container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Spark"
LABEL org.opencontainers.image.description="Apache Spark with Iceberg support for Datalyptica lakehouse batch processing"

# Set environment variables
ENV SPARK_VERSION=3.5.6
ENV HADOOP_VERSION=3
ENV ICEBERG_VERSION=1.9.1
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=$JAVA_HOME/bin:$SPARK_HOME/bin:$PATH

# AWS region will be set via environment variables from docker-compose

# Switch to root for installation
USER root

# Install system dependencies, Python packages, and download all components in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    python3 \
    python3-pip \
    netcat-openbsd \
    gettext \
    bash \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --break-system-packages --no-cache-dir \
        pyspark==3.5.1 \
        pandas==2.3.0 \
        numpy==2.0.2 \
        requests==2.32.4 \
        py4j==0.10.9.7 \
    && wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar -xzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mkdir -p ${SPARK_HOME}/jars/iceberg \
    && cd ${SPARK_HOME}/jars/iceberg \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-nessie/${ICEBERG_VERSION}/iceberg-nessie-${ICEBERG_VERSION}.jar || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar -P ${SPARK_HOME}/jars/ || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar -P ${SPARK_HOME}/jars/ || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.3.4/hadoop-common-3.3.4.jar -P ${SPARK_HOME}/jars/ || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client/3.3.4/hadoop-client-3.3.4.jar -P ${SPARK_HOME}/jars/ || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.20.162/bundle-2.20.162.jar -P ${SPARK_HOME}/jars/ || exit 1 \
    && wget --tries=3 --timeout=30 https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.20.162/url-connection-client-2.20.162.jar -P ${SPARK_HOME}/jars/ || exit 1 \
    && cp ${SPARK_HOME}/jars/iceberg/*.jar ${SPARK_HOME}/jars/ \
    && groupadd -g 185 spark \
    && useradd -u 185 -g spark -m -d /opt/spark -s /bin/sh spark \
    && mkdir -p /tmp/spark-events

# Configuration will be mounted at runtime
# Static spark-defaults.conf removed - using template-based configuration only
# COPY ../../configs/spark/spark-defaults.conf.template ${SPARK_HOME}/conf/spark-defaults.conf.template
# COPY ../../configs/spark/spark-env.sh ${SPARK_HOME}/conf/spark-env.sh
# RUN chmod +x ${SPARK_HOME}/conf/spark-env.sh

# Set ownership for spark user
RUN chown -R spark:spark ${SPARK_HOME} \
    && chown -R spark:spark /tmp/spark-events

# Copy entrypoint script
COPY scripts/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh && \
    chown spark:spark /opt/entrypoint.sh

# Switch to spark user
USER spark

# Expose ports (master: 4040, 7077; worker: 4040; history server: 18080)
EXPOSE 4040 7077 8081 18080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4040 || exit 1

WORKDIR ${SPARK_HOME}

ENTRYPOINT ["/opt/entrypoint.sh"]