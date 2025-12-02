# Extend official Spark image - never rebuild from source
FROM apache/spark:3.5.1-scala2.12-java17-python3-ubuntu

LABEL maintainer="devops@datalyptica.com"
LABEL description="Extended Spark with Iceberg container for data stack"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"
LABEL org.opencontainers.image.vendor="Datalyptica"
LABEL org.opencontainers.image.title="Spark"
LABEL org.opencontainers.image.description="Apache Spark with Iceberg support for Datalyptica lakehouse batch processing"

# Set environment variables
ENV ICEBERG_VERSION=1.9.1
ENV SPARK_HOME=/opt/spark

# Switch to root to add Iceberg JARs
USER root

# Official apache/spark image already includes Spark binaries
# Only download Iceberg extension JARs (pre-built, not compiled)
RUN mkdir -p ${SPARK_HOME}/jars/iceberg && cd ${SPARK_HOME}/jars/iceberg \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-nessie/${ICEBERG_VERSION}/iceberg-nessie-${ICEBERG_VERSION}.jar \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar \
        -P ${SPARK_HOME}/jars/ \
    && chown -R spark:spark ${SPARK_HOME}/jars/iceberg

# Download additional AWS and Hadoop JARs (pre-built, not compiled)
RUN wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar \
        -P ${SPARK_HOME}/jars/ \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.3.4/hadoop-common-3.3.4.jar \
        -P ${SPARK_HOME}/jars/ \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client/3.3.4/hadoop-client-3.3.4.jar \
        -P ${SPARK_HOME}/jars/ \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.20.162/bundle-2.20.162.jar \
        -P ${SPARK_HOME}/jars/ \
    && wget --tries=5 --timeout=60 --waitretry=10 \
        https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.20.162/url-connection-client-2.20.162.jar \
        -P ${SPARK_HOME}/jars/ \
    && cp ${SPARK_HOME}/jars/iceberg/*.jar ${SPARK_HOME}/jars/ \
    && chown -R spark:spark ${SPARK_HOME}/jars

# Install additional Python packages
RUN pip install --no-cache-dir \
        pandas \
        numpy \
        requests

# Official apache/spark image already has spark user and directories
# Create additional directories as needed
RUN mkdir -p /tmp/spark-events \
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