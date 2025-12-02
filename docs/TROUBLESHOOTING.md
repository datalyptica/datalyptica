# Datalyptica Platform - Troubleshooting Guide

**Version:** v1.0.0  
**Last Updated:** November 26, 2025

---

## 📋 Quick Diagnostic Commands

```bash
# Check all services status
docker compose ps

# View logs for specific service
docker compose logs -f <service-name>

# Check Docker resources
docker system df

# Run health checks
cd tests && ./run-tests.sh health

# Check network connectivity
docker network inspect datalyptica_data
```

---

## Common Issues

### 1. Kafka Keeps Restarting

#### Issue: Kafka container repeatedly restarts during initialization

**Root Cause:** Insufficient host resources (CPU/RAM) during KRaft metadata initialization

**Symptoms:**

```bash
docker compose ps
# Shows kafka with high RestartCount

docker compose logs kafka
# May show:
# - "DUPLICATE_BROKER_REGISTRATION" errors
# - Slow startup times (>180s)
# - Healthcheck timeouts
```

**Solution:**

```bash
# Check host resource usage
docker stats

# Increase Docker resource limits (Docker Desktop):
# Settings → Resources:
# - CPUs: Minimum 4 cores (8+ recommended for full platform)
# - Memory: Minimum 8GB (16GB+ recommended)
# - Swap: 2GB minimum

# Stop other resource-intensive applications
# Clear Docker cache if needed
docker system prune -a --volumes

# Restart with clean slate
make down
make up
```

**Prevention:**

- Ensure adequate host resources before starting platform
- Monitor resource usage: `docker stats`
- Use `make ps` to check service health
- Consider reducing parallel service startup with `--scale`

**Note:** Kafka in KRaft mode requires significant CPU during first-time metadata formatting and initialization. Once running, resource usage normalizes.

---

### 2. Services Won't Start

#### Issue: Container exits immediately

**Symptoms:**

```bash
docker compose ps
# Shows service as "Exited (1)"
```

**Diagnosis:**

```bash
# Check logs
docker compose logs <service-name>

# Common error messages:
# - "variable not set"
# - "connection refused"
# - "port already in use"
```

**Solutions:**

**A. Missing Environment Variables**

```bash
# Verify .env file exists
ls -la docker/.env

# If missing, create it
cd docker
cp .env.template .env

# Restart services
docker compose up -d
```

**B. Port Conflicts**

```bash
# Find process using port
lsof -i :8080  # Replace with your port

# Kill conflicting process
kill -9 <PID>

# Or change port in .env
vim docker/.env
# Update port number
docker compose down
docker compose up -d
```

**C. Insufficient Docker Resources**

```bash
# Check available resources
docker system df

# Solution: Increase Docker resources
# Docker Desktop → Settings → Resources
# Minimum: 16GB RAM, 50GB disk

# Clean up if needed
docker system prune -af
docker volume prune -f
```

---

### 2. Service Health Check Failures

#### Issue: Service running but unhealthy

**Symptoms:**

```bash
docker compose ps
# Shows "(unhealthy)" status
```

**Diagnosis:**

```bash
# Check health check command
docker inspect datalyptica-<service> | jq '.[0].State.Health'

# View health check logs
docker inspect datalyptica-<service> | jq '.[0].State.Health.Log'
```

**Solutions:**

**A. Service Not Ready**

```bash
# Wait longer for service to initialize
# Some services take 60-120 seconds

# Check again after 2 minutes
sleep 120
docker compose ps
```

**B. Dependencies Not Ready**

```bash
# Check dependency health
docker compose ps | grep -E "(postgresql|nessie|minio)"

# Restart in correct order
docker compose restart postgresql
sleep 30
docker compose restart nessie
sleep 30
docker compose restart trino
```

**C. Configuration Error**

```bash
# Check service logs for errors
docker compose logs <service> | grep -i error

# Common fixes:
# - Update .env file
# - Check file permissions
# - Verify network connectivity
```

---

### 3. Connection Errors Between Services

#### Issue: Service A can't connect to Service B

**Symptoms:**

```
Error: Connection refused
Error: Name or service not known
Error: No route to host
```

**Diagnosis:**

```bash
# Check if both services are on same network
docker inspect datalyptica-service-a | jq '.[0].NetworkSettings.Networks'
docker inspect datalyptica-service-b | jq '.[0].NetworkSettings.Networks'

# Test connectivity
docker exec datalyptica-service-a ping service-b
docker exec datalyptica-service-a curl http://service-b:port/health
```

**Solutions:**

**A. Network Misconfiguration**

```bash
# Recreate networks
docker compose down
docker network prune -f
docker compose up -d
```

**B. Wrong Service Name**

```bash
# Use Docker service names, not container names
# ✅ Correct: http://nessie:19120
# ❌ Wrong: http://datalyptica-nessie:19120

# Verify service names in docker-compose.yml
grep "services:" docker/docker-compose.yml -A 1
```

**C. Firewall/Network Policy**

```bash
# Check Docker network
docker network inspect datalyptica_data

# Verify service is on correct network
# Update docker-compose.yml if needed
```

---

### 4. Trino Query Failures

#### Issue: Trino queries fail or timeout

**Symptoms:**

```
Query failed: HIVE_METASTORE_ERROR
Query failed: insufficient memory
Connection timeout
```

**Diagnosis:**

```bash
# Test Trino connectivity
curl http://localhost:8080/v1/info

# Check catalogs
docker exec datalyptica-trino trino --execute "SHOW CATALOGS"

# Check Trino logs
docker compose logs trino | tail -100
```

**Solutions:**

**A. Nessie Connection Issues**

```bash
# Verify Nessie is healthy
curl http://localhost:19120/api/v2/config

# Check Nessie catalog in Trino
docker exec datalyptica-trino trino --execute "SHOW SCHEMAS IN iceberg"

# If failing, restart both services
docker compose restart nessie
sleep 30
docker compose restart trino
```

**B. Memory Issues**

```bash
# Increase Trino memory in .env
vim docker/.env
# Update: TRINO_QUERY_MAX_MEMORY=8GB

# Restart Trino
docker compose restart trino
```

**C. S3/MinIO Connection Issues**

```bash
# Test MinIO connectivity
curl http://localhost:9000/minio/health/live

# Verify S3 credentials match
grep -E "(S3_ACCESS_KEY|MINIO_ROOT_USER)" docker/.env

# Check bucket exists
docker exec datalyptica-minio mc ls local/lakehouse
```

---

### 5. Kafka/Streaming Issues

#### Issue: Messages not flowing through Kafka

**Symptoms:**

```
Error: No leader found
Error: Connection to node -1 failed
Consumer group not found
```

**Diagnosis:**

```bash
# Check Kafka status
docker exec datalyptica-kafka kafka-broker-api-versions \
    --bootstrap-server localhost:9092

# List topics
docker exec datalyptica-kafka kafka-topics \
    --bootstrap-server localhost:9092 --list

# Check Kafka cluster status (KRaft mode)
docker exec datalyptica-kafka kafka-metadata.sh \
    --snapshot /var/lib/kafka/data/__cluster_metadata-0/00000000000000000000.log --print
```

**Solutions:**

**A. Kafka Not Ready**

```bash
# Kafka runs in KRaft mode (no ZooKeeper needed)
docker compose restart kafka
sleep 60

# Verify
docker exec datalyptica-kafka kafka-topics \
    --bootstrap-server localhost:9092 --list
```

**B. Topic Configuration Issues**

```bash
# Describe topic to see errors
docker exec datalyptica-kafka kafka-topics \
    --bootstrap-server localhost:9092 \
    --describe --topic <topic-name>

# Delete and recreate topic
docker exec datalyptica-kafka kafka-topics \
    --bootstrap-server localhost:9092 \
    --delete --topic <topic-name>

docker exec datalyptica-kafka kafka-topics \
    --bootstrap-server localhost:9092 \
    --create --topic <topic-name> \
    --partitions 3 --replication-factor 1
```

**C. Schema Registry Issues**

```bash
# Check Schema Registry health
curl http://localhost:8085/subjects

# If failing, check logs
docker compose logs schema-registry

# Restart Schema Registry
docker compose restart schema-registry
```

---

### 6. PostgreSQL Connection Issues

#### Issue: Can't connect to PostgreSQL

**Symptoms:**

```
FATAL: password authentication failed
FATAL: database does not exist
could not connect to server
```

**Diagnosis:**

```bash
# Test PostgreSQL
docker exec datalyptica-postgresql pg_isready -U postgres

# Check logs
docker compose logs postgresql | tail -50

# Try connecting
docker exec -it datalyptica-postgresql psql -U postgres
```

**Solutions:**

**A. Authentication Issues**

```bash
# Verify credentials in .env
grep POSTGRES docker/.env

# Reset password
docker exec -it datalyptica-postgresql psql -U postgres -c \
    "ALTER USER postgres WITH PASSWORD 'newpassword';"

# Update .env
vim docker/.env
# Update POSTGRES_PASSWORD
```

**B. Database Not Created**

```bash
# List databases
docker exec datalyptica-postgresql psql -U postgres -c "\l"

# Create missing database
docker exec datalyptica-postgresql psql -U postgres -c \
    "CREATE DATABASE nessie;"
```

**C. Connection Limit Reached**

```bash
# Check connections
docker exec datalyptica-postgresql psql -U postgres -c \
    "SELECT count(*) FROM pg_stat_activity;"

# Increase max connections in .env
vim docker/.env
# Update: POSTGRES_MAX_CONNECTIONS=300

docker compose restart postgresql
```

---

### 7. MinIO/S3 Issues

#### Issue: Can't access MinIO or buckets

**Symptoms:**

```
AccessDenied
NoSuchBucket
Connection timeout
```

**Diagnosis:**

```bash
# Test MinIO API
curl http://localhost:9000/minio/health/live

# Check console
open http://localhost:9001

# List buckets
docker exec datalyptica-minio mc ls local/
```

**Solutions:**

**A. Credentials Mismatch**

```bash
# Verify S3 credentials match MinIO
grep -E "(MINIO_ROOT|S3_)" docker/.env

# Ensure:
# S3_ACCESS_KEY = MINIO_ROOT_USER
# S3_SECRET_KEY = MINIO_ROOT_PASSWORD

# Update and restart
docker compose restart minio nessie trino spark-master
```

**B. Bucket Doesn't Exist**

```bash
# Create bucket
docker exec datalyptica-minio mc mb local/lakehouse

# Verify
docker exec datalyptica-minio mc ls local/
```

**C. Permission Issues**

```bash
# Check bucket policy
docker exec datalyptica-minio mc policy get local/lakehouse

# Set public policy (development only)
docker exec datalyptica-minio mc policy set public local/lakehouse
```

---

### 8. Monitoring/Observability Issues

#### Issue: Grafana/Prometheus not working

**Symptoms:**

```
Dashboards show no data
Prometheus targets down
Loki not receiving logs
```

**Diagnosis:**

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'

# Check Grafana datasources
curl -u admin:admin http://localhost:3000/api/datasources

# Check Loki
curl http://localhost:3100/ready
```

**Solutions:**

**A. Prometheus Can't Scrape Targets**

```bash
# Check Prometheus config
docker exec datalyptica-prometheus cat /etc/prometheus/prometheus.yml

# Verify target services are healthy
docker compose ps

# Check network connectivity
docker exec datalyptica-prometheus wget -O- http://nessie:19120/q/metrics
```

**B. Grafana Datasource Issues**

```bash
# Restart Grafana
docker compose restart grafana

# Check provisioning
docker exec datalyptica-grafana ls /etc/grafana/provisioning/datasources/

# Manually add datasource if needed
# Login to Grafana UI → Configuration → Data Sources
```

**C. Loki Not Receiving Logs**

```bash
# Check Alloy (log collector)
docker compose logs alloy

# Restart log collection
docker compose restart alloy loki
```

---

### 9. Performance Issues

#### Issue: Slow queries or high resource usage

**Symptoms:**

```
Queries timeout
High CPU/memory usage
Docker sluggish
```

**Diagnosis:**

```bash
# Check resource usage
docker stats --no-stream

# Check individual services
docker stats datalyptica-trino datalyptica-spark-master

# Check system resources
df -h  # Disk space
free -h  # Memory
top  # CPU usage
```

**Solutions:**

**A. Insufficient Resources**

```bash
# Increase Docker resources
# Docker Desktop → Settings → Resources
# Recommended: 32GB RAM, 100GB disk

# Restart Docker after changes
```

**B. Tune Service Configuration**

```bash
# Increase Trino memory
vim docker/.env
# TRINO_QUERY_MAX_MEMORY=8GB
# TRINO_JVM_XMX=16G

# Increase Spark memory
# SPARK_EXECUTOR_MEMORY=4g
# SPARK_DRIVER_MEMORY=4g

# Restart affected services
docker compose restart trino spark-master spark-worker
```

**C. Scale Workers**

```bash
# Add more Spark workers
docker compose up -d --scale spark-worker=3

# Add more Flink TaskManagers
docker compose up -d --scale flink-taskmanager=3
```

---

### 10. Data Consistency Issues

#### Issue: Data not appearing or inconsistent

**Symptoms:**

```
Query returns no results
Stale data
Missing records
```

**Diagnosis:**

```bash
# Check Nessie commits
curl http://localhost:19120/api/v2/trees/tree/main/log | jq

# Check table metadata
docker exec datalyptica-trino trino --execute \
    "SELECT * FROM iceberg.information_schema.tables"

# Check MinIO files
docker exec datalyptica-minio mc ls --recursive local/lakehouse/
```

**Solutions:**

**A. Transaction Not Committed**

```bash
# Ensure transactions are committed
# Check application logs for commit errors

# Verify in Nessie
curl http://localhost:19120/api/v2/trees/tree/main | jq '.hash'
```

**B. Cache Issues**

```bash
# Clear Trino cache
docker compose restart trino

# Clear Spark cache
docker compose restart spark-master spark-worker
```

**C. Schema Evolution**

```bash
# Check table schema
docker exec datalyptica-trino trino --execute \
    "DESCRIBE iceberg.schema.table"

# Update schema if needed
docker exec datalyptica-trino trino --execute \
    "ALTER TABLE iceberg.schema.table ADD COLUMN new_col VARCHAR"
```

---

## Diagnostic Scripts

### Complete Health Check

```bash
#!/bin/bash
# Save as: diagnostic.sh

echo "=== Datalyptica Platform Diagnostics ==="
echo

echo "1. Docker Info"
docker version
docker-compose version
echo

echo "2. Resource Usage"
docker system df
echo

echo "3. Service Status"
cd docker
docker compose ps
echo

echo "4. Network Status"
docker network ls | grep datalyptica
echo

echo "5. Volume Usage"
docker volume ls | grep datalyptica
echo

echo "6. Recent Errors (last 50 lines per service)"
for service in minio postgresql nessie trino kafka; do
    echo "--- $service ---"
    docker compose logs --tail=50 $service | grep -i error
    echo
done
```

### Log Collector

```bash
#!/bin/bash
# Save as: collect-logs.sh

OUTPUT_DIR="logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTPUT_DIR

cd docker

echo "Collecting logs..."
for service in $(docker compose ps --services); do
    echo "- $service"
    docker compose logs $service > "$OUTPUT_DIR/${service}.log" 2>&1
done

echo "Collecting system info..."
docker version > "$OUTPUT_DIR/docker-version.txt"
docker compose ps > "$OUTPUT_DIR/services-status.txt"
docker network inspect datalyptica_data > "$OUTPUT_DIR/network-data.json"

echo "Logs collected in: $OUTPUT_DIR"
tar -czf "${OUTPUT_DIR}.tar.gz" $OUTPUT_DIR
echo "Archive created: ${OUTPUT_DIR}.tar.gz"
```

---

## Getting Additional Help

### Before Asking for Help

1. ✅ Run full diagnostic: `./tests/run-tests.sh full`
2. ✅ Collect logs: Run `collect-logs.sh` script above
3. ✅ Check this guide for similar issues
4. ✅ Search GitHub Issues

### Reporting Issues

Include in your report:

- Platform version (`cat docker/VERSION`)
- Operating system and version
- Docker version (`docker version`)
- Relevant logs from failed services
- Steps to reproduce
- Expected vs actual behavior

### Support Channels

- **GitHub Issues:** For bugs and feature requests
- **Documentation:** Check all docs in repository
- **Email Support:** support@datalyptica.com

---

**Last Resort: Complete Reset**

⚠️ **WARNING: This will delete all data!**

```bash
# Stop all services
cd docker
docker compose down -v

# Remove all Datalyptica volumes
docker volume ls | grep datalyptica | awk '{print $2}' | xargs docker volume rm

# Remove all Datalyptica networks
docker network ls | grep datalyptica | awk '{print $2}' | xargs docker network rm

# Restart from clean state
docker compose up -d
```

---

**See Also:**

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment procedures
- [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) - Configuration reference
- [README.md](README.md) - Platform overview
