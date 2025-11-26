# ShuDL Platform - Deployment Guide

**Version:** v1.0.0  
**Last Updated:** November 26, 2025  
**Target Audience:** DevOps Engineers, Platform Engineers

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Deployment Steps](#deployment-steps)
5. [Verification](#verification)
6. [Post-Deployment](#post-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers deploying the ShuDL Data Lakehouse platform in different environments (development, staging, production).

### Deployment Environments

| Environment | Purpose                    | Security | HA       | Monitoring |
| ----------- | -------------------------- | -------- | -------- | ---------- |
| Development | Local testing, development | Basic    | No       | Basic      |
| Staging     | Pre-production testing     | Medium   | Optional | Full       |
| Production  | Live workloads             | Full     | Yes      | Full       |

**Current Status:** Platform configured for **development only**

---

## Prerequisites

### System Requirements

#### Hardware

- **CPU:** 8+ cores (16+ recommended for production)
- **RAM:** 16GB minimum (32GB+ recommended for production)
- **Disk:** 100GB+ free space
- **Network:** 1 Gbps+ connectivity

#### Software

- **Docker:** 20.10+ with Compose V2
- **OS:** Linux (Ubuntu 20.04+, RHEL 8+, or similar)
- **Tools:** curl, jq, netstat, docker-compose

#### For macOS Development

```bash
brew install docker coreutils jq
```

#### For Linux Production

```bash
# Ubuntu/Debian
apt-get install docker.io docker-compose-plugin curl jq netstat-nat

# RHEL/CentOS
yum install docker docker-compose curl jq net-tools
```

### Network Requirements

#### Outbound Connectivity

- Docker Hub (pull images): `hub.docker.com`
- GitHub Container Registry: `ghcr.io`
- Package repositories: OS-specific

#### Inbound Ports (Production)

- Load balancer/proxy ports as configured
- Management ports (SSH, monitoring) from admin network

#### Internal Ports

All service ports are internal to Docker networks (see Architecture section)

---

## Environment Setup

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd shudl
```

### Step 2: Prepare Environment File

```bash
cd docker

# Copy template
cp .env.template .env

# Edit configuration
vim .env  # or your preferred editor
```

### Step 3: Configure Secrets

**Development:**

```bash
# Use default values (already in .env.template)
# ⚠️ NOT SECURE FOR PRODUCTION
```

**Production:**

```bash
# Generate secure passwords
export MINIO_PASSWORD=$(openssl rand -base64 32)
export POSTGRES_PASSWORD=$(openssl rand -base64 32)
export GRAFANA_PASSWORD=$(openssl rand -base64 32)
export KEYCLOAK_PASSWORD=$(openssl rand -base64 32)

# Update .env file
sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}/" .env
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" .env
sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASSWORD}/" .env
sed -i "s/KEYCLOAK_ADMIN_PASSWORD=.*/KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_PASSWORD}/" .env

# Store passwords securely
echo "MinIO: ${MINIO_PASSWORD}" >> ~/.shudl_secrets
echo "PostgreSQL: ${POSTGRES_PASSWORD}" >> ~/.shudl_secrets
chmod 600 ~/.shudl_secrets
```

### Step 4: Resource Configuration

Edit `docker-compose.yml` resource limits based on your environment:

```yaml
# Example for small/medium deployment
services:
  trino:
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 4G

# Example for large deployment
  trino:
    deploy:
      resources:
        limits:
          cpus: "8.0"
          memory: 16G
```

---

## Deployment Steps

### Development Deployment

#### 1. Start Core Services (Storage Layer)

```bash
cd docker

# Start only storage services first
docker compose up -d minio postgresql nessie

# Wait for services to be healthy
docker compose ps

# Expected output: all services showing "healthy"
```

#### 2. Start Streaming Layer

```bash
# Start Kafka ecosystem
docker compose up -d zookeeper kafka schema-registry kafka-ui

# Wait 30 seconds for Kafka to initialize
sleep 30

# Verify Kafka
docker exec shudl-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

#### 3. Start Processing Layer

```bash
# Start Spark and Flink
docker compose up -d spark-master spark-worker flink-jobmanager flink-taskmanager

# Verify Spark
curl http://localhost:4040

# Verify Flink
curl http://localhost:8081/overview
```

#### 4. Start Query Layer

```bash
# Start query engines
docker compose up -d trino clickhouse dbt kafka-connect

# Verify Trino
docker exec shudl-trino trino --execute "SHOW CATALOGS"
```

#### 5. Start Observability Stack

```bash
# Start monitoring services
docker compose up -d prometheus grafana loki alloy alertmanager keycloak

# Wait for Grafana
sleep 20

# Access Grafana
open http://localhost:3000
```

#### 6. Verify All Services

```bash
# Check all services are running
docker compose ps

# Run health checks
cd ../tests
./run-tests.sh health
```

### Staging Deployment

Follow development steps, then:

#### 1. Enable Authentication

```bash
# Configure Keycloak
# Access http://localhost:8180
# Create realms and clients for services
```

#### 2. Configure SSL/TLS (Optional for Staging)

```bash
# Generate certificates
cd ../scripts
./generate-certificates.sh

# Update docker-compose.yml to mount certificates
# Restart services
cd ../docker
docker compose down
docker compose up -d
```

### Production Deployment

⚠️ **STOP: Production deployment requires completing Phase 2 & 3 of the action plan**

Prerequisites:

- [ ] SSL/TLS certificates obtained
- [ ] Docker secrets configured
- [ ] High availability configured (Patroni, Kafka cluster)
- [ ] Backup procedures implemented
- [ ] Monitoring alerts configured
- [ ] Security audit completed

See [PRIORITIZED_ACTION_PLAN.md](PRIORITIZED_ACTION_PLAN.md) for details.

---

## Verification

### Health Check Tests

```bash
cd tests

# Quick health check (1-2 minutes)
./run-tests.sh quick

# Expected output
✅ Passed: 21
❌ Failed: 0
📊 Total:  21
```

### Manual Verification

#### 1. Storage Layer

```bash
# MinIO
curl http://localhost:9000/minio/health/live
# Expected: OK

# PostgreSQL
docker exec shudl-postgresql pg_isready -U postgres
# Expected: accepting connections

# Nessie
curl http://localhost:19120/api/v2/config | jq '.defaultBranch'
# Expected: "main"
```

#### 2. Data Flow Test

```bash
# Create test table
docker exec shudl-trino trino --execute "
CREATE SCHEMA IF NOT EXISTS iceberg.test;
CREATE TABLE iceberg.test.verification (
    id BIGINT,
    message VARCHAR,
    created_at TIMESTAMP
) WITH (format = 'PARQUET');"

# Insert data
docker exec shudl-trino trino --execute "
INSERT INTO iceberg.test.verification VALUES
(1, 'Test message', CURRENT_TIMESTAMP);"

# Query data
docker exec shudl-trino trino --execute "
SELECT * FROM iceberg.test.verification;"

# Expected: 1 row returned

# Cleanup
docker exec shudl-trino trino --execute "
DROP TABLE iceberg.test.verification;
DROP SCHEMA iceberg.test;"
```

#### 3. Monitoring Verification

```bash
# Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
# Expected: 6+

# Grafana health
curl http://localhost:3000/api/health
# Expected: {"database": "ok"}

# Loki ready
curl http://localhost:3100/ready
# Expected: ready
```

---

## Post-Deployment

### 1. Create Initial Schemas

```bash
# Create production schemas
docker exec shudl-trino trino --execute "
CREATE SCHEMA IF NOT EXISTS iceberg.raw;
CREATE SCHEMA IF NOT EXISTS iceberg.staging;
CREATE SCHEMA IF NOT EXISTS iceberg.prod;"
```

### 2. Configure Grafana Datasources

1. Access Grafana: `http://localhost:3000`
2. Login: `admin / admin` (change password!)
3. Datasources are auto-configured via provisioning
4. Verify: Configuration → Data Sources

### 3. Set Up Kafka Topics

```bash
# Create standard topics
docker exec shudl-kafka kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --topic events \
    --partitions 3 \
    --replication-factor 1

docker exec shudl-kafka kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --topic cdc \
    --partitions 3 \
    --replication-factor 1
```

### 4. Configure Alerts

```bash
# Review alert rules
cat configs/monitoring/prometheus/alerts.yml

# Test alerts
# Trigger a test alert and verify in Alertmanager
curl http://localhost:9095/#/alerts
```

### 5. Set Up Backup Schedule

```bash
# Add to crontab
0 2 * * * /path/to/shudl/scripts/backup.sh
```

---

## Troubleshooting

### Services Won't Start

**Symptom:** Services fail to start or remain unhealthy

**Diagnosis:**

```bash
# Check Docker resources
docker system df

# Check individual service
docker compose logs <service-name>

# Check dependencies
docker compose ps
```

**Solutions:**

1. **Insufficient Resources:**

   ```bash
   # Increase Docker resources in Docker Desktop/Engine settings
   # Minimum: 16GB RAM, 50GB disk
   ```

2. **Port Conflicts:**

   ```bash
   # Check for conflicts
   netstat -an | grep LISTEN | grep <port>

   # Change port in .env file
   vim .env  # Update port numbers
   docker compose down
   docker compose up -d
   ```

3. **Missing Environment Variables:**

   ```bash
   # Validate .env file
   docker compose config

   # Check for errors in output
   ```

### Connection Errors

**Symptom:** Services can't connect to each other

**Diagnosis:**

```bash
# Check networks
docker network ls | grep shudl

# Inspect network
docker network inspect shudl_storage
```

**Solutions:**

```bash
# Recreate networks
docker compose down
docker network prune -f
docker compose up -d
```

### Performance Issues

**Symptom:** Slow queries or high resource usage

**Solutions:**

1. **Increase Resources:**

   - Edit resource limits in docker-compose.yml
   - Restart affected services

2. **Tune Configuration:**

   - Trino: Increase `TRINO_QUERY_MAX_MEMORY`
   - Spark: Increase `SPARK_EXECUTOR_MEMORY`
   - PostgreSQL: Tune `POSTGRES_SHARED_BUFFERS`

3. **Scale Workers:**
   ```bash
   docker compose up -d --scale spark-worker=3
   docker compose up -d --scale flink-taskmanager=3
   ```

---

## Rollback Procedures

### Rollback to Previous Version

```bash
# Stop services
docker compose down

# Restore previous .env
cp .env.backup .env

# Restore previous docker-compose.yml
git checkout HEAD^ docker/docker-compose.yml

# Restore data from backup
./scripts/restore-backup.sh <backup-date>

# Start services
docker compose up -d
```

### Emergency Shutdown

```bash
# Graceful shutdown (recommended)
docker compose down

# Force shutdown (if services hang)
docker compose kill
docker compose down -v
```

---

## Upgrade Procedures

### Minor Version Upgrade (e.g., v1.0.0 → v1.1.0)

```bash
# 1. Backup current state
./scripts/backup-all.sh

# 2. Pull new images
docker compose pull

# 3. Update configuration
git pull
cp .env .env.backup
# Merge any new variables from .env.template

# 4. Rolling restart
docker compose up -d --no-deps --build <service>

# 5. Verify
./tests/run-tests.sh health
```

### Major Version Upgrade (e.g., v1.x → v2.x)

See version-specific upgrade guides.

---

## Maintenance

### Regular Maintenance Tasks

#### Daily

- Monitor service health
- Check disk usage
- Review error logs

#### Weekly

- Review monitoring dashboards
- Check backup completion
- Review security alerts

#### Monthly

- Update Docker images
- Review and optimize resource usage
- Test disaster recovery procedures

### Cleanup Commands

```bash
# Remove unused volumes
docker volume prune -f

# Remove unused images
docker image prune -af

# Clean build cache
docker builder prune -af
```

---

## Security Considerations

### Development Environment

- ✅ Default passwords acceptable
- ✅ HTTP connections acceptable
- ✅ Open network access acceptable

### Staging Environment

- ⚠️ Change default passwords
- ⚠️ Consider HTTPS for external access
- ⚠️ Restrict network access

### Production Environment

- ✅ All passwords must be unique and strong
- ✅ HTTPS/TLS required for all services
- ✅ Network access strictly controlled
- ✅ Authentication enabled
- ✅ Audit logging enabled
- ✅ Regular security scans

---

## Getting Help

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review service logs: `docker compose logs <service>`
3. Run diagnostics: `./tests/run-tests.sh full`
4. Search GitHub Issues
5. Contact support@shugur.com

---

**Next:** After deployment, see [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) for configuration tuning.

