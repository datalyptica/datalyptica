# ShuDL Platform Troubleshooting Guide

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Service-Specific Issues](#service-specific-issues)
- [Common Problems](#common-problems)
- [Performance Issues](#performance-issues)
- [Data Issues](#data-issues)
- [Network & Connectivity](#network--connectivity)
- [Recovery Procedures](#recovery-procedures)

---

## Quick Diagnostics

### Check All Services Status

```bash
cd /path/to/shudl/docker
docker compose ps

# Or get detailed status
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

### Check Service Logs

```bash
# View logs for a specific service
docker logs docker-nessie --tail 100 --follow

# View all logs
docker compose logs --tail=50

# Check for errors across all services
docker compose logs | grep -i "error\|exception\|failed"
```

### Check Resource Usage

```bash
# Container resource usage
docker stats

# Disk usage
docker system df

# Volume usage
docker volume ls
du -sh /var/lib/docker/volumes/*
```

### Quick Health Check Script

```bash
#!/bin/bash
# Save as check-health.sh

SERVICES="minio postgresql nessie trino spark-master spark-worker kafka zookeeper schema-registry"

echo "🏥 ShuDL Health Check"
echo "===================="

for service in $SERVICES; do
    if docker ps | grep -q "docker-$service"; then
        echo "✅ $service - Running"
    else
        echo "❌ $service - Not Running"
    fi
done

echo ""
echo "🔍 Checking service health..."
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

---

## Service-Specific Issues

### MinIO Object Storage

#### Issue: MinIO Container Won't Start

**Symptoms:**

- Container exits immediately after start
- Error: "Unable to write to the backend"

**Diagnosis:**

```bash
docker logs docker-minio
```

**Solutions:**

1. **Volume Permission Issues:**

   ```bash
   # Stop services and remove volumes
   docker compose down -v

   # Restart with fresh volumes
   docker compose up -d minio
   ```

2. **Port Conflicts:**

   ```bash
   # Check if ports 9000 or 9001 are in use
   lsof -i :9000
   lsof -i :9001

   # Update .env file to use different ports
   MINIO_API_PORT=9010
   MINIO_CONSOLE_PORT=9011
   ```

3. **Insufficient Disk Space:**
   ```bash
   df -h
   # Clean up Docker system
   docker system prune -a --volumes
   ```

#### Issue: Cannot Access MinIO Console

**Symptoms:**

- Console not loading at http://localhost:9001
- Connection refused errors

**Solutions:**

1. Check container is running and healthy:

   ```bash
   docker ps | grep minio
   docker inspect docker-minio | grep -A 5 Health
   ```

2. Check network connectivity:

   ```bash
   docker exec docker-minio curl -f http://localhost:9000/minio/health/live
   ```

3. Verify credentials in `.env` file match what you're using to log in

---

### PostgreSQL Database

#### Issue: Connection Refused

**Symptoms:**

- Error: "FATAL: password authentication failed"
- Error: "connection refused"

**Diagnosis:**

```bash
docker logs docker-postgresql --tail 50

# Test connection from host
psql -h localhost -p 5432 -U postgres -d shudl

# Test from within container
docker exec docker-postgresql psql -U postgres -d shudl -c "SELECT version();"
```

**Solutions:**

1. **Authentication Issues:**

   ```bash
   # Check pg_hba.conf settings
   docker exec docker-postgresql cat /var/lib/postgresql/data/pgdata/pg_hba.conf

   # Verify password in .env matches
   grep POSTGRES_PASSWORD docker/.env
   ```

2. **Database Not Initialized:**

   ```bash
   # Check database logs for initialization errors
   docker logs docker-postgresql | grep -i "database system is ready"

   # Reinitialize if needed
   docker compose down postgresql
   docker volume rm docker_postgresql_data
   docker compose up -d postgresql
   ```

3. **Port Conflicts:**

   ```bash
   # Check if port 5432 is already in use
   lsof -i :5432

   # Change port in .env
   POSTGRES_PORT=5433
   ```

#### Issue: High CPU/Memory Usage

**Symptoms:**

- PostgreSQL consuming > 80% CPU
- Out of memory errors

**Diagnosis:**

```bash
# Check current connections
docker exec docker-postgresql psql -U postgres -d shudl -c "
  SELECT count(*) FROM pg_stat_activity;
"

# Check long-running queries
docker exec docker-postgresql psql -U postgres -d shudl -c "
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query
  FROM pg_stat_activity
  WHERE state = 'active' AND now() - pg_stat_activity.query_start > interval '1 minute'
  ORDER BY duration DESC;
"
```

**Solutions:**

1. Kill long-running queries:

   ```sql
   SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <PID>;
   ```

2. Increase resource limits in `.env`:

   ```bash
   POSTGRES_SHARED_BUFFERS=256MB  # Increase from 64MB
   POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
   POSTGRES_WORK_MEM=16MB
   ```

3. Add connection pooling via pgBouncer (advanced)

---

### Nessie Catalog

#### Issue: Nessie Not Starting

**Symptoms:**

- Container exits with error
- Error: "Failed to connect to database"

**Diagnosis:**

```bash
docker logs docker-nessie --tail 100
```

**Solutions:**

1. **Database Connection Issues:**

   ```bash
   # Verify PostgreSQL is healthy
   docker exec docker-postgresql pg_isready -U postgres

   # Check network connectivity
   docker exec docker-nessie ping -c 3 postgresql

   # Verify database exists
   docker exec docker-postgresql psql -U postgres -c "\l" | grep shudl
   ```

2. **Port Conflicts:**

   ```bash
   lsof -i :19120
   # Change NESSIE_PORT in .env if needed
   ```

3. **Configuration Errors:**

   ```bash
   # Check environment variables
   docker exec docker-nessie env | grep QUARKUS

   # Restart with fresh config
   docker compose restart nessie
   ```

#### Issue: Tables Not Visible in Catalog

**Symptoms:**

- Trino/Spark queries return empty results
- Tables created but don't appear in Nessie

**Diagnosis:**

```bash
# Check Nessie catalog contents via API
curl http://localhost:19120/api/v2/trees/tree/main/entries | jq

# Check Nessie references
curl http://localhost:19120/api/v2/trees | jq
```

**Solutions:**

1. Verify catalog configuration in Trino/Spark matches Nessie URI
2. Check if using correct Nessie branch (default: `main`)
3. Verify S3/MinIO connectivity from Nessie

---

### Trino Query Engine

#### Issue: Trino Queries Failing

**Symptoms:**

- Error: "Catalog 'iceberg' does not exist"
- Error: "Unable to create catalog"

**Diagnosis:**

```bash
docker logs docker-trino --tail 100 | grep -i error

# Check catalog configuration
docker exec docker-trino ls -la /etc/trino/catalog/

# Test connectivity to Nessie
docker exec docker-trino curl -f http://nessie:19120/api/v2/config
```

**Solutions:**

1. **Catalog Configuration:**

   ```bash
   # Verify iceberg.properties exists
   docker exec docker-trino cat /etc/trino/catalog/iceberg.properties

   # Restart Trino to reload catalogs
   docker compose restart trino
   ```

2. **Memory Issues:**

   ```bash
   # Check JVM memory settings
   docker exec docker-trino env | grep TRINO_JVM_XMX

   # Increase if needed in .env
   TRINO_JVM_XMX=4G  # Default is 2G
   ```

3. **Nessie Connectivity:**
   ```bash
   # Verify Nessie is reachable
   docker exec docker-trino curl -v http://nessie:19120/api/v2/config
   ```

#### Issue: Query Timeout

**Symptoms:**

- Queries fail with timeout errors
- Long-running queries getting killed

**Solutions:**

1. Increase query timeouts in `.env`:

   ```bash
   TRINO_QUERY_MAX_MEMORY=10GB  # Increase from 5GB
   TRINO_QUERY_MAX_MEMORY_PER_NODE=2GB
   ```

2. Check query explain plan:

   ```sql
   EXPLAIN SELECT * FROM iceberg.default.my_table;
   ```

3. Optimize table partitioning and sorting

---

### Apache Spark

#### Issue: Spark Jobs Failing

**Symptoms:**

- Executor lost errors
- Out of memory errors
- Jobs stuck in pending state

**Diagnosis:**

```bash
# Check Spark Master logs
docker logs docker-spark-master --tail 100

# Check Spark Worker logs
docker logs docker-spark-worker --tail 100

# Check Spark UI
curl http://localhost:4040
```

**Solutions:**

1. **Executor Memory Issues:**

   ```bash
   # Increase executor memory in .env
   SPARK_EXECUTOR_MEMORY=4g  # Increase from 2g
   SPARK_DRIVER_MEMORY=4g
   ```

2. **S3/MinIO Connectivity:**

   ```bash
   # Test S3 access from Spark
   docker exec docker-spark-master curl http://minio:9000/minio/health/live

   # Verify credentials
   docker exec docker-spark-master env | grep S3_
   ```

3. **Worker Not Connecting:**

   ```bash
   # Check worker registration
   docker exec docker-spark-master curl http://localhost:4040/api/v1/applications

   # Restart worker
   docker compose restart spark-worker
   ```

---

### Kafka & Schema Registry

#### Issue: Kafka Not Accepting Connections

**Symptoms:**

- Producers/consumers can't connect
- Error: "Connection to node -1 could not be established"

**Diagnosis:**

```bash
docker logs docker-kafka --tail 50
docker logs docker-zookeeper --tail 50

# Check if Kafka is listening
docker exec docker-kafka netstat -tuln | grep 9092
```

**Solutions:**

1. **Zookeeper Issues:**

   ```bash
   # Verify Zookeeper is healthy
   docker exec docker-zookeeper bash -c "echo ruok | nc localhost 2181"

   # Should return "imok"
   ```

2. **Listener Configuration:**

   ```bash
   # Check Kafka listeners
   docker exec docker-kafka env | grep KAFKA_ADVERTISED_LISTENERS

   # Should show: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9093
   ```

3. **Network Issues:**
   ```bash
   # Test connectivity from another container
   docker exec docker-schema-registry telnet kafka 9092
   ```

#### Issue: Schema Registry Schema Not Found

**Symptoms:**

- Error: "Subject not found"
- Avro serialization failures

**Diagnosis:**

```bash
# List all schemas
curl http://localhost:8085/subjects

# Get specific schema
curl http://localhost:8085/subjects/my-topic-value/versions/latest
```

**Solutions:**

1. Register schema manually:

   ```bash
   curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     --data '{"schema": "{\"type\":\"record\",\"name\":\"MyRecord\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"}]}"}' \
     http://localhost:8085/subjects/my-topic-value/versions
   ```

2. Check compatibility mode:

   ```bash
   curl http://localhost:8085/config
   # Should return {"compatibilityLevel":"BACKWARD"}
   ```

3. Verify Kafka connectivity:
   ```bash
   docker logs docker-schema-registry | grep -i "kafka"
   ```

---

## Common Problems

### Docker Compose Issues

#### Issue: Services Not Starting in Correct Order

**Symptom:** Services fail because dependencies aren't ready

**Solution:**

```bash
# Stop everything
docker compose down

# Start in order
docker compose up -d minio postgresql
sleep 30
docker compose up -d nessie
sleep 20
docker compose up -d trino spark-master zookeeper
sleep 20
docker compose up -d kafka schema-registry spark-worker
sleep 20
docker compose up -d kafka-ui flink-jobmanager kafka-connect clickhouse dbt
```

#### Issue: Port Already in Use

**Symptoms:**

- Error: "Bind for 0.0.0.0:PORT failed: port is already allocated"

**Solution:**

```bash
# Find process using the port
lsof -i :PORT
# Or on Linux
netstat -tuln | grep PORT

# Kill the process
kill -9 PID

# Or change ports in .env file
```

### Volume & Storage Issues

#### Issue: Disk Space Full

**Symptoms:**

- Containers failing with I/O errors
- Cannot create files

**Diagnosis:**

```bash
df -h
docker system df
```

**Solutions:**

```bash
# Clean up stopped containers
docker container prune

# Clean up unused images
docker image prune -a

# Clean up volumes (CAREFUL - data loss!)
docker volume prune

# Remove old logs
docker compose logs --tail=0 > /dev/null
```

### Network Issues

#### Issue: Services Can't Communicate

**Symptoms:**

- Connection refused between services
- DNS resolution failures

**Diagnosis:**

```bash
# Check network exists
docker network ls | grep shunetwork

# Inspect network
docker network inspect docker_shunetwork

# Test DNS resolution
docker exec docker-nessie ping -c 3 postgresql
docker exec docker-trino nslookup nessie
```

**Solutions:**

```bash
# Recreate network
docker compose down
docker network rm docker_shunetwork
docker compose up -d

# Or specify custom network in .env
NETWORK_NAME=shunetwork
```

---

## Performance Issues

### Slow Query Performance

**Diagnosis Steps:**

1. Check resource usage: `docker stats`
2. Check for table scans in query plans
3. Review partition strategy
4. Check index usage

**Solutions:**

1. Optimize table partitioning:

   ```sql
   CREATE TABLE iceberg.default.my_table (
     id BIGINT,
     timestamp TIMESTAMP,
     data VARCHAR
   ) PARTITIONED BY (day(timestamp));
   ```

2. Add sorting for better file pruning:

   ```sql
   ALTER TABLE iceberg.default.my_table
   SET PROPERTIES('write.object-storage.enabled'='true');
   ```

3. Increase parallelism:

   ```bash
   # Trino
   TRINO_QUERY_MAX_MEMORY_PER_NODE=2GB

   # Spark
   SPARK_SQL_SHUFFLE_PARTITIONS=400
   ```

### High Memory Usage

**Diagnosis:**

```bash
# Check memory usage
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# Check JVM memory in logs
docker logs docker-trino | grep -i "OutOfMemory"
```

**Solutions:**

1. Increase resource limits in docker-compose.yml (already added)
2. Tune JVM settings:

   ```bash
   TRINO_JVM_XMX=8G
   SPARK_DRIVER_MEMORY=4g
   SPARK_EXECUTOR_MEMORY=4g
   ```

3. Reduce concurrent queries/jobs

---

## Data Issues

### Data Corruption

#### Symptoms:

- Queries return inconsistent results
- File not found errors
- Checksum mismatches

#### Recovery:

```bash
# For Iceberg tables, use table maintenance
docker exec docker-trino trino --execute "
  CALL iceberg.system.expire_snapshots(
    'default', 'my_table',
    TIMESTAMP '2025-01-01 00:00:00'
  );
"

# Remove orphan files
docker exec docker-trino trino --execute "
  CALL iceberg.system.remove_orphan_files(
    'default', 'my_table'
  );
"
```

### Lost Data After Restart

#### Prevention:

- Always use named volumes (already configured)
- Regular backups of PostgreSQL, MinIO, and Nessie
- Document recovery procedures

#### Recovery:

```bash
# Restore from backup (see backup-recovery.md)
./scripts/backup.sh restore --date 2025-11-25

# Or restore specific volumes
docker volume create --name docker_postgresql_data
docker run --rm -v docker_postgresql_data:/data -v /backup:/backup alpine \
  sh -c "cd /data && tar xvf /backup/postgresql_20251125.tar.gz"
```

---

## Recovery Procedures

### Complete System Restart

```bash
# 1. Stop all services gracefully
docker compose down

# 2. Check no containers running
docker ps -a

# 3. Start core services first
docker compose up -d minio postgresql
docker compose logs -f minio postgresql

# 4. Wait for healthy status
docker compose ps

# 5. Start catalog and compute
docker compose up -d nessie trino spark-master zookeeper

# 6. Start streaming
docker compose up -d kafka schema-registry

# 7. Start remaining services
docker compose up -d
```

### Emergency Shutdown

```bash
# Graceful shutdown with 30s timeout
docker compose down -t 30

# Force kill if needed
docker compose kill
docker compose down -v  # Only if you want to delete data!
```

### Service-Specific Restart

```bash
# Restart single service
docker compose restart <service-name>

# Restart with recreate
docker compose up -d --force-recreate <service-name>

# Restart with logs
docker compose restart <service-name> && docker compose logs -f <service-name>
```

---

## Getting Help

### Collect Diagnostic Information

```bash
#!/bin/bash
# Save as collect-diagnostics.sh

echo "Collecting ShuDL diagnostics..."

mkdir -p diagnostics/$(date +%Y%m%d_%H%M%S)
cd diagnostics/$(date +%Y%m%d_%H%M%S)

# Service status
docker compose ps > service-status.txt

# Container stats
docker stats --no-stream > container-stats.txt

# Logs for all services
for service in minio postgresql nessie trino spark-master kafka schema-registry; do
    docker logs docker-$service --tail 200 > ${service}-logs.txt 2>&1
done

# System info
docker system df > docker-df.txt
df -h > disk-usage.txt
free -h > memory-usage.txt

# Network info
docker network inspect docker_shunetwork > network-config.json

echo "Diagnostics collected in: $(pwd)"
echo "Compress and share: tar -czf diagnostics.tar.gz ."
```

### Support Channels

- **Documentation:** https://github.com/Shugur-Network/shudl/docs
- **Issues:** https://github.com/Shugur-Network/shudl/issues
- **Discussions:** https://github.com/Shugur-Network/shudl/discussions
- **Email:** devops@shugur.com

---

## Appendix

### Useful Commands Cheat Sheet

```bash
# View all logs
docker compose logs -f

# Restart specific service
docker compose restart <service>

# Check service health
docker compose ps

# Execute command in container
docker exec -it docker-<service> bash

# View resource usage
docker stats

# Clean up
docker system prune -a --volumes

# Export logs
docker compose logs > shudl-logs-$(date +%Y%m%d).txt

# Check network
docker network inspect docker_shunetwork | jq

# List volumes
docker volume ls | grep docker_

# Backup volume
docker run --rm -v docker_postgresql_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/postgres-backup.tar.gz -C /data .
```

### Environment Variables Quick Reference

See [`docs/reference/environment-variables.md`](../reference/environment-variables.md) for complete list.

Key variables for troubleshooting:

- `COMPOSE_PROJECT_NAME` - Prefix for container names
- `NETWORK_NAME` - Docker network name
- `*_PORT` - Service ports
- `*_MEMORY` - Memory allocations
- `*_PASSWORD` - Authentication credentials
