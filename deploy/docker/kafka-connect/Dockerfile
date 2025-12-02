FROM confluentinc/cp-kafka-connect:7.5.0

LABEL maintainer="Datalyptica Team <devops@datalyptica.com>"
LABEL description="Kafka Connect with comprehensive Debezium CDC connectors and database drivers"
LABEL version="7.5.0"

USER root

# Environment variables for versions
ENV DEBEZIUM_VERSION=2.4.0.Final \
    JDBC_POSTGRES_VERSION=42.7.1 \
    JDBC_MYSQL_VERSION=8.2.0 \
    JDBC_MSSQL_VERSION=12.4.2.jre11 \
    JDBC_ORACLE_VERSION=23.3.0.23.09 \
    MONGODB_DRIVER_VERSION=4.11.1

# Install Debezium connectors for major databases
RUN mkdir -p /usr/share/java/debezium && \
    cd /usr/share/java/debezium && \
    # PostgreSQL connector
    echo "Installing Debezium PostgreSQL connector..." && \
    curl -fsSL -o debezium-connector-postgres.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/${DEBEZIUM_VERSION}/debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xzf debezium-connector-postgres.tar.gz && \
    rm debezium-connector-postgres.tar.gz && \
    # MySQL connector
    echo "Installing Debezium MySQL connector..." && \
    curl -fsSL -o debezium-connector-mysql.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/${DEBEZIUM_VERSION}/debezium-connector-mysql-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xzf debezium-connector-mysql.tar.gz && \
    rm debezium-connector-mysql.tar.gz && \
    # MongoDB connector
    echo "Installing Debezium MongoDB connector..." && \
    curl -fsSL -o debezium-connector-mongodb.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-mongodb/${DEBEZIUM_VERSION}/debezium-connector-mongodb-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xzf debezium-connector-mongodb.tar.gz && \
    rm debezium-connector-mongodb.tar.gz && \
    # SQL Server connector
    echo "Installing Debezium SQL Server connector..." && \
    curl -fsSL -o debezium-connector-sqlserver.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-sqlserver/${DEBEZIUM_VERSION}/debezium-connector-sqlserver-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xzf debezium-connector-sqlserver.tar.gz && \
    rm debezium-connector-sqlserver.tar.gz && \
    # Oracle connector
    echo "Installing Debezium Oracle connector..." && \
    curl -fsSL -o debezium-connector-oracle.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-oracle/${DEBEZIUM_VERSION}/debezium-connector-oracle-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xzf debezium-connector-oracle.tar.gz && \
    rm debezium-connector-oracle.tar.gz && \
    # Db2 connector
    echo "Installing Debezium Db2 connector..." && \
    curl -fsSL -o debezium-connector-db2.tar.gz \
    https://repo1.maven.org/maven2/io/debezium/debezium-connector-db2/${DEBEZIUM_VERSION}/debezium-connector-db2-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xzf debezium-connector-db2.tar.gz && \
    rm debezium-connector-db2.tar.gz

# Install additional JDBC drivers for direct database access
RUN mkdir -p /usr/share/java/jdbc-drivers && \
    cd /usr/share/java/jdbc-drivers && \
    # PostgreSQL JDBC driver
    echo "Installing PostgreSQL JDBC driver..." && \
    curl -sL -o postgresql-${JDBC_POSTGRES_VERSION}.jar \
    https://jdbc.postgresql.org/download/postgresql-${JDBC_POSTGRES_VERSION}.jar && \
    # MySQL JDBC driver
    echo "Installing MySQL JDBC driver..." && \
    curl -sL -o mysql-connector-j-${JDBC_MYSQL_VERSION}.jar \
    https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${JDBC_MYSQL_VERSION}/mysql-connector-j-${JDBC_MYSQL_VERSION}.jar && \
    # SQL Server JDBC driver
    echo "Installing SQL Server JDBC driver..." && \
    curl -sL -o mssql-jdbc-${JDBC_MSSQL_VERSION}.jar \
    https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${JDBC_MSSQL_VERSION}/mssql-jdbc-${JDBC_MSSQL_VERSION}.jar && \
    # MongoDB Java driver
    echo "Installing MongoDB Java driver..." && \
    curl -sL -o mongodb-driver-sync-${MONGODB_DRIVER_VERSION}.jar \
    https://repo1.maven.org/maven2/org/mongodb/mongodb-driver-sync/${MONGODB_DRIVER_VERSION}/mongodb-driver-sync-${MONGODB_DRIVER_VERSION}.jar

# Copy all connectors to plugin path
RUN cp -r /usr/share/java/debezium/* /usr/share/confluent-hub-components/ && \
    cp /usr/share/java/jdbc-drivers/* /usr/share/confluent-hub-components/ || true

# Create necessary directories
RUN mkdir -p /var/lib/kafka-connect /var/log/kafka-connect && \
    chown -R appuser:appuser /var/lib/kafka-connect /var/log/kafka-connect

USER appuser

EXPOSE 8083

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8083/ || exit 1
