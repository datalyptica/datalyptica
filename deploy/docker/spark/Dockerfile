FROM apache/spark:3.5.7-scala2.12-java17-python3-ubuntu

USER root

# Download Iceberg and AWS JARs during build (no compilation, just download)
# Using Spark 3.5.7 with compatible versions:
# - Iceberg 1.10.0 (latest stable for Spark 3.5.x)
# - Hadoop 3.4.1 (certified for Spark 3.5.x)
# - AWS SDK v2 (required by Iceberg 1.10.0 S3FileIO)
# - AWS SDK v1 (for Hadoop S3A compatibility)
#
# Strategy: Download to iceberg/ subdirectory for Standalone mode compatibility
# Then symlink to main jars/ directory for K8s native mode automatic classpath
RUN mkdir -p /opt/spark/jars/iceberg && \
    cd /opt/spark/jars/iceberg && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.10.0/iceberg-spark-runtime-3.5_2.12-1.10.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-nessie/1.10.0/iceberg-nessie-1.10.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.772/aws-java-sdk-bundle-1.12.772.jar && \
    wget -q https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.28.11/bundle-2.28.11.jar && \
    wget -q https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.28.11/url-connection-client-2.28.11.jar && \
    ls -lh && \
    echo "Creating symlinks in main jars directory for K8s native mode..." && \
    cd /opt/spark/jars && \
    ln -s iceberg/iceberg-spark-runtime-3.5_2.12-1.10.0.jar . && \
    ln -s iceberg/iceberg-nessie-1.10.0.jar . && \
    ln -s iceberg/hadoop-aws-3.4.1.jar . && \
    ln -s iceberg/aws-java-sdk-bundle-1.12.772.jar . && \
    ln -s iceberg/bundle-2.28.11.jar . && \
    ln -s iceberg/url-connection-client-2.28.11.jar . && \
    ls -lh *.jar | tail -10

# Fix permissions for OpenShift (uses random UIDs)
RUN mkdir -p /tmp/spark-work /tmp/spark-events && \
    chmod -R 777 /tmp/spark-work /tmp/spark-events /opt/spark/work 2>/dev/null || true

# Run as non-root user
USER 1000

WORKDIR /opt/spark