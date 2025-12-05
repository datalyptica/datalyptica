FROM apache/spark:3.5.1-scala2.12-java17-python3-ubuntu

USER root

# Download Iceberg and AWS JARs during build (no compilation, just download)
RUN mkdir -p /opt/spark/jars/iceberg && \
    cd /opt/spark/jars/iceberg && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.9.1/iceberg-spark-runtime-3.5_2.12-1.9.1.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-nessie/1.9.1/iceberg-nessie-1.9.1.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    ls -lh

# Fix permissions for OpenShift (uses random UIDs)
RUN mkdir -p /tmp/spark-work /tmp/spark-events && \
    chmod -R 777 /tmp/spark-work /tmp/spark-events /opt/spark/work 2>/dev/null || true

# Run as non-root user
USER 1000

WORKDIR /opt/spark