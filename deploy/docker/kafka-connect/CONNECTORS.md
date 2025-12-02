# Kafka Connect - Debezium Connectors & Database Drivers

## Overview

This Kafka Connect image includes comprehensive Debezium CDC connectors and JDBC drivers for connecting to virtually all major database systems.

## Debezium CDC Connectors (Version 2.4.0.Final)

### Included Connectors

1. **PostgreSQL** - `debezium-connector-postgres`

   - Captures row-level changes from PostgreSQL databases
   - Supports logical replication
   - Full schema evolution support

2. **MySQL** - `debezium-connector-mysql`

   - Captures binlog changes from MySQL/MariaDB
   - Supports GTID-based replication
   - Compatible with MySQL 5.7, 8.0+

3. **MongoDB** - `debezium-connector-mongodb`

   - Captures change streams from MongoDB
   - Supports replica sets and sharded clusters
   - Works with MongoDB 4.0+

4. **SQL Server** - `debezium-connector-sqlserver`

   - Captures changes from SQL Server transaction log
   - Supports SQL Server 2017, 2019, 2022
   - Requires SQL Server CDC enabled

5. **Oracle** - `debezium-connector-oracle`

   - Captures changes using Oracle LogMiner or XStream
   - Supports Oracle 12c, 19c, 21c
   - Handles DDL and DML changes

6. **Db2** - `debezium-connector-db2`

   - Captures changes from IBM Db2 databases
   - Supports Db2 11.5+
   - Uses Db2 SQL Replication

7. **Cassandra** - `debezium-connector-cassandra`

   - Captures changes from Apache Cassandra
   - Supports Cassandra 3.x, 4.x
   - Uses CommitLog reader

8. **Vitess** - `debezium-connector-vitess`
   - Captures changes from Vitess (MySQL sharding)
   - Supports horizontal scaling scenarios
   - VStream-based change capture

## JDBC Drivers

### Included Drivers

1. **PostgreSQL JDBC** - `postgresql-42.7.1.jar`

   - For direct PostgreSQL database access
   - Used by JDBC sink connectors

2. **MySQL Connector/J** - `mysql-connector-j-8.2.0.jar`

   - For MySQL and MariaDB connections
   - Latest GA version

3. **SQL Server JDBC** - `mssql-jdbc-12.4.2.jre11.jar`

   - For Microsoft SQL Server connections
   - Supports SQL Server 2016+

4. **MongoDB Java Driver** - `mongodb-driver-sync-4.11.1.jar`
   - For MongoDB connections
   - Synchronous driver

## Confluent Hub Connectors

### Additional Connectors

1. **JDBC Sink Connector** - `confluentinc/kafka-connect-jdbc:10.7.4`

   - Write data from Kafka to any JDBC-compatible database
   - Supports batch inserts, upserts, deletes
   - Auto-creation of tables

2. **S3 Sink Connector** - `confluentinc/kafka-connect-s3:10.5.7`

   - Write data from Kafka to S3/MinIO
   - Parquet, Avro, JSON formats
   - Partitioning support

3. **Elasticsearch Sink Connector** - `confluentinc/kafka-connect-elasticsearch:14.0.10`
   - Write data from Kafka to Elasticsearch
   - Bulk operations support
   - Schema evolution

## Usage Examples

### PostgreSQL CDC Configuration

```json
{
  "name": "postgres-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgresql",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "debezium_password",
    "database.dbname": "your_database",
    "database.server.name": "postgres_server",
    "table.include.list": "public.customers,public.orders",
    "plugin.name": "pgoutput",
    "publication.name": "dbz_publication",
    "slot.name": "debezium_slot"
  }
}
```

### MySQL CDC Configuration

```json
{
  "name": "mysql-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "debezium_password",
    "database.server.id": "184054",
    "database.server.name": "mysql_server",
    "table.include.list": "inventory.customers,inventory.orders",
    "include.schema.changes": "true",
    "snapshot.mode": "initial"
  }
}
```

### MongoDB CDC Configuration

```json
{
  "name": "mongodb-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.mongodb.MongoDbConnector",
    "mongodb.connection.string": "mongodb://mongodb:27017/?replicaSet=rs0",
    "mongodb.user": "debezium",
    "mongodb.password": "debezium_password",
    "topic.prefix": "mongodb_server",
    "collection.include.list": "inventory.customers,inventory.orders"
  }
}
```

### SQL Server CDC Configuration

```json
{
  "name": "sqlserver-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "database.hostname": "sqlserver",
    "database.port": "1433",
    "database.user": "sa",
    "database.password": "YourPassword123",
    "database.names": "testDB",
    "database.server.name": "sqlserver_server",
    "table.include.list": "dbo.customers,dbo.orders",
    "database.encrypt": "false"
  }
}
```

### Oracle CDC Configuration

```json
{
  "name": "oracle-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.oracle.OracleConnector",
    "database.hostname": "oracle",
    "database.port": "1521",
    "database.user": "c##dbzuser",
    "database.password": "dbz",
    "database.dbname": "ORCLCDB",
    "database.server.name": "oracle_server",
    "table.include.list": "INVENTORY.CUSTOMERS,INVENTORY.ORDERS",
    "database.connection.adapter": "logminer"
  }
}
```

### JDBC Sink Configuration (PostgreSQL Example)

```json
{
  "name": "jdbc-sink-postgres",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "connection.url": "jdbc:postgresql://postgresql:5432/target_db",
    "connection.user": "sink_user",
    "connection.password": "sink_password",
    "topics": "postgres_server.public.customers",
    "auto.create": "true",
    "auto.evolve": "true",
    "insert.mode": "upsert",
    "pk.mode": "record_key",
    "table.name.format": "sink_${topic}"
  }
}
```

## Supported Data Sources Summary

| Database      | CDC Connector | JDBC Driver | Sink Support | Notes                                |
| ------------- | ------------- | ----------- | ------------ | ------------------------------------ |
| PostgreSQL    | ✅            | ✅          | ✅           | Logical replication, pgoutput plugin |
| MySQL         | ✅            | ✅          | ✅           | Binlog-based, GTID support           |
| MongoDB       | ✅            | ✅          | ❌           | Change streams, replica sets         |
| SQL Server    | ✅            | ✅          | ✅           | Transaction log CDC                  |
| Oracle        | ✅            | ❌          | ✅           | LogMiner/XStream                     |
| Db2           | ✅            | ❌          | ✅           | SQL Replication                      |
| Cassandra     | ✅            | ❌          | ❌           | CommitLog reader                     |
| Vitess        | ✅            | ❌          | ❌           | VStream API                          |
| MariaDB       | ✅            | ✅          | ✅           | Via MySQL connector                  |
| S3/MinIO      | ❌            | ❌          | ✅           | Sink only                            |
| Elasticsearch | ❌            | ❌          | ✅           | Sink only                            |

## API Endpoints

### List Installed Connectors

```bash
curl http://kafka-connect:8083/connector-plugins | jq
```

### Create Connector

```bash
curl -X POST http://kafka-connect:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json
```

### List Active Connectors

```bash
curl http://kafka-connect:8083/connectors | jq
```

### Get Connector Status

```bash
curl http://kafka-connect:8083/connectors/connector-name/status | jq
```

### Delete Connector

```bash
curl -X DELETE http://kafka-connect:8083/connectors/connector-name
```

## Best Practices

### 1. Database User Permissions

**PostgreSQL:**

```sql
CREATE ROLE debezium WITH LOGIN REPLICATION PASSWORD 'debezium_password';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER USER debezium WITH SUPERUSER;  -- For slot creation
```

**MySQL:**

```sql
CREATE USER 'debezium'@'%' IDENTIFIED BY 'debezium_password';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'debezium'@'%';
FLUSH PRIVILEGES;
```

**MongoDB:**

```javascript
use admin
db.createUser({
  user: "debezium",
  pwd: "debezium_password",
  roles: [
    { role: "read", db: "config" },
    { role: "read", db: "local" },
    { role: "read", db: "inventory" }
  ]
})
```

### 2. Production Configurations

- **Set appropriate snapshot modes**: `initial`, `schema_only`, `never`
- **Configure tombstone events**: For proper deletion handling
- **Set heartbeat intervals**: For low-traffic tables
- **Use schema history topics**: For DDL change tracking
- **Configure transforms**: For data masking and routing

### 3. Performance Tuning

```properties
# Kafka Connect worker configuration
connector.client.config.override.policy=All
offset.flush.interval.ms=10000
offset.flush.timeout.ms=5000

# Connector-specific tuning
max.batch.size=2048
max.queue.size=8192
poll.interval.ms=500
```

### 4. Monitoring

Monitor these metrics:

- Connector status and tasks
- Source record poll rate
- Sink record send rate
- Offset lag
- Error counts

## Troubleshooting

### Common Issues

**Issue: "Insufficient permissions"**

- Solution: Grant proper database permissions to CDC user

**Issue: "Slot already exists"**

- Solution: Drop and recreate replication slot or use different slot name

**Issue: "Connector fails to start"**

- Solution: Check database connectivity, credentials, and CDC enablement

**Issue: "High lag"**

- Solution: Increase parallelism, tune batch sizes, check network

## Version Compatibility

- Debezium: 2.4.0.Final
- Kafka Connect: 7.5.0 (Confluent Platform)
- Kafka: 3.5.x
- Java: 11

## References

- [Debezium Documentation](https://debezium.io/documentation/)
- [Confluent Hub](https://www.confluent.io/hub/)
- [Kafka Connect REST API](https://docs.confluent.io/platform/current/connect/references/restapi.html)
