FROM apache/spark:3.5.7-scala2.12-java17-python3-ubuntu

USER root

# Download Iceberg and AWS JARs directly into main jars directory
# Using Spark 3.5.7 with compatible versions:
# - Iceberg 1.10.0 (latest stable for Spark 3.5.x)
# - Hadoop 3.4.1 (certified for Spark 3.5.x)
# - AWS SDK v2 (required by Iceberg 1.10.0 S3FileIO)
# - AWS SDK v1 (for Hadoop S3A compatibility)
#
# Strategy: Place JARs directly in /opt/spark/jars/ for automatic classpath inclusion
# This works for both Standalone mode (explicit --jars) and K8s native mode (automatic)
RUN cd /opt/spark/jars && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.10.0/iceberg-spark-runtime-3.5_2.12-1.10.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-nessie/1.10.0/iceberg-nessie-1.10.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.4.1/hadoop-common-3.4.1.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.772/aws-java-sdk-bundle-1.12.772.jar && \
    wget -q https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.28.11/bundle-2.28.11.jar && \
    wget -q https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.28.11/url-connection-client-2.28.11.jar && \
    echo "Iceberg JARs downloaded to /opt/spark/jars/" && \
    ls -lh iceberg*.jar hadoop*.jar aws*.jar bundle*.jar url*.jar

# Fix permissions for OpenShift (uses random UIDs)
# Per Spark K8s docs: Use UID 185 as the default unprivileged user
# This user must include root group (GID 0) in supplementary groups for Spark executables
RUN mkdir -p /tmp/spark-work /tmp/spark-events && \
    chmod -R 777 /tmp/spark-work /tmp/spark-events /opt/spark/work 2>/dev/null || true

# Run as non-root user (UID 185 per Spark K8s security guidelines)
USER 185

WORKDIR /opt/spark