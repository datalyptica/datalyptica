FROM apache/flink:2.1.0-scala_2.12-java17

USER root

# Install Python 3 and PyFlink dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-dev && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    pip3 install --no-cache-dir apache-flink==2.1.0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download Flink connectors to /opt/flink/lib/ for automatic classpath
# Per Flink docs: JARs in /opt/flink/lib/ are on classpath for all modes
# Using Flink 2.1.0 with compatible versions:
# - Kafka Connector 3.4.0 (certified for Flink 2.1+)
# - Iceberg 1.10.0 (certified for Flink 2.0+)
# - Hadoop 3.4.1 (required by Iceberg for S3/HDFS operations)
# - Nessie 1.10.0 (Iceberg catalog for versioning)
RUN cd /opt/flink/lib && \
    curl -L -o flink-sql-connector-kafka-3.4.0-2.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-2.0/flink-sql-connector-kafka-3.4.0-2.0.jar && \
    curl -L -o iceberg-flink-runtime-2.0-1.10.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-2.0/1.10.0/iceberg-flink-runtime-2.0-1.10.0.jar && \
    curl -L -o hadoop-common-3.4.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/3.4.1/hadoop-common-3.4.1.jar && \
    curl -L -o hadoop-aws-3.4.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    curl -L -o aws-java-sdk-bundle-1.12.772.jar \
      https://repo.maven.apache.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.772/aws-java-sdk-bundle-1.12.772.jar && \
    curl -L -o iceberg-nessie-1.10.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-nessie/1.10.0/iceberg-nessie-1.10.0.jar && \
    curl -L -o bundle-2.28.11.jar \
      https://repo.maven.apache.org/maven2/org/projectnessie/nessie-client/2.28.11/nessie-client-2.28.11-bundle.jar && \
    echo "Flink connectors installed in /opt/flink/lib/" && \
    ls -lh flink-sql*.jar iceberg*.jar hadoop*.jar aws*.jar bundle*.jar

# Download S3 filesystem plugin
RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop && \
    cd /opt/flink/plugins/s3-fs-hadoop && \
    curl -L -o flink-s3-fs-hadoop-2.1.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/2.1.0/flink-s3-fs-hadoop-2.1.0.jar && \
    ls -lh

# Fix permissions for OpenShift
RUN chmod -R 777 /opt/flink 2>/dev/null || true

# Run as non-root user
USER 1000

WORKDIR /opt/flink
