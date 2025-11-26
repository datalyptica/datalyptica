# ShuDL Backup and Disaster Recovery Guide

## Table of Contents

- [Overview](#overview)
- [Backup Strategy](#backup-strategy)
- [Backup Procedures](#backup-procedures)
- [Restore Procedures](#restore-procedures)
- [Disaster Recovery](#disaster-recovery)
- [Automated Backup](#automated-backup)
- [Testing & Validation](#testing--validation)
- [Best Practices](#best-practices)

---

## Overview

This guide covers comprehensive backup and disaster recovery procedures for the ShuDL data lakehouse platform. Regular backups are critical for protecting against data loss from hardware failures, human errors, or disasters.

### RPO & RTO Targets

| Service                 | RPO (Recovery Point Objective) | RTO (Recovery Time Objective) |
| ----------------------- | ------------------------------ | ----------------------------- |
| **PostgreSQL**          | 15 minutes                     | 30 minutes                    |
| **MinIO**               | 1 hour                         | 1 hour                        |
| **Nessie Catalog**      | 15 minutes                     | 30 minutes                    |
| **Kafka Topics**        | 1 hour                         | 1 hour                        |
| **Schema Registry**     | 1 hour                         | 30 minutes                    |
| **Configuration Files** | Daily                          | 15 minutes                    |

### What to Backup

✅ **Critical (Daily):**

- PostgreSQL databases (Nessie catalog, metadata)
- MinIO buckets (data lake storage)
- Docker volumes
- Configuration files

✅ **Important (Weekly):**

- Kafka topics and offsets
- Schema Registry schemas
- Grafana dashboards
- Prometheus data (optional)

✅ **Essential (On Change):**

- Docker Compose files
- Environment variables (.env)
- Custom configurations
- SSL certificates

---

## Backup Strategy

### 3-2-1 Backup Rule

Follow the industry-standard 3-2-1 rule:

- **3** copies of data (original + 2 backups)
- **2** different media types (local disk + cloud/tape)
- **1** offsite copy (cloud storage, remote datacenter)

### Backup Locations

```
/backup/
├── daily/
│   ├── postgresql/
│   │   └── shudl_20251126_0300.sql.gz
│   ├── minio/
│   │   └── lakehouse_20251126_0300.tar.gz
│   └── volumes/
│       └── all_volumes_20251126_0300.tar.gz
├── weekly/
│   ├── kafka/
│   └── configs/
├── monthly/
│   └── full_system/
└── offsite/
    └── sync_to_s3_or_cloud/
```

### Retention Policy

| Backup Type         | Retention            |
| ------------------- | -------------------- |
| **Daily Backups**   | 7 days               |
| **Weekly Backups**  | 4 weeks              |
| **Monthly Backups** | 12 months            |
| **Yearly Backups**  | 7 years (compliance) |

---

## Backup Procedures

### 1. PostgreSQL Database Backup

#### Manual Backup

```bash
#!/bin/bash
# Backup PostgreSQL database

BACKUP_DIR="/backup/daily/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="shudl_${TIMESTAMP}.sql.gz"

mkdir -p $BACKUP_DIR

# Dump database
docker exec docker-postgresql pg_dump \
  -U postgres \
  -d shudl \
  --clean \
  --if-exists \
  --verbose \
  | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

echo "✅ PostgreSQL backup completed: ${BACKUP_FILE}"
echo "   Size: $(du -h ${BACKUP_DIR}/${BACKUP_FILE} | cut -f1)"
```

#### Include All Databases

```bash
# Backup all databases
docker exec docker-postgresql pg_dumpall \
  -U postgres \
  --clean \
  --if-exists \
  | gzip > "${BACKUP_DIR}/all_databases_${TIMESTAMP}.sql.gz"
```

#### Backup with Roles and Permissions

```bash
# Backup roles separately
docker exec docker-postgresql pg_dumpall \
  -U postgres \
  --roles-only \
  | gzip > "${BACKUP_DIR}/roles_${TIMESTAMP}.sql.gz"
```

### 2. MinIO Object Storage Backup

#### Using MinIO Client (mc)

```bash
#!/bin/bash
# Backup MinIO buckets

BACKUP_DIR="/backup/daily/minio"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Configure mc alias
docker exec docker-minio mc alias set local \
  http://localhost:9000 \
  ${MINIO_ROOT_USER} \
  ${MINIO_ROOT_PASSWORD}

# Mirror entire lakehouse bucket
docker exec docker-minio mc mirror \
  --preserve \
  --overwrite \
  local/lakehouse \
  /backup/lakehouse_${TIMESTAMP}

# Compress backup
cd /backup && tar czf \
  "${BACKUP_DIR}/lakehouse_${TIMESTAMP}.tar.gz" \
  "lakehouse_${TIMESTAMP}"

rm -rf "lakehouse_${TIMESTAMP}"

echo "✅ MinIO backup completed: lakehouse_${TIMESTAMP}.tar.gz"
```

#### Selective Bucket Backup

```bash
# Backup specific prefix/folder
docker exec docker-minio mc mirror \
  --newer-than 7d \
  local/lakehouse/warehouse/ \
  /backup/warehouse_incremental_${TIMESTAMP}
```

### 3. Nessie Catalog Backup

Nessie catalog is stored in PostgreSQL, so it's backed up with the database. However, you can also export Nessie metadata:

```bash
#!/bin/bash
# Export Nessie references and commits

BACKUP_DIR="/backup/daily/nessie"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Export all references
curl -s http://localhost:19120/api/v2/trees \
  | jq '.' > "${BACKUP_DIR}/references_${TIMESTAMP}.json"

# Export main branch history
curl -s "http://localhost:19120/api/v2/trees/tree/main/history" \
  | jq '.' > "${BACKUP_DIR}/main_history_${TIMESTAMP}.json"

# Export all table entries
curl -s "http://localhost:19120/api/v2/trees/tree/main/entries" \
  | jq '.' > "${BACKUP_DIR}/table_entries_${TIMESTAMP}.json"

echo "✅ Nessie metadata exported"
```

### 4. Docker Volumes Backup

#### All Volumes

```bash
#!/bin/bash
# Backup all Docker volumes

BACKUP_DIR="/backup/daily/volumes"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# List of volumes to backup
VOLUMES=(
  "docker_postgresql_data"
  "docker_minio_data"
  "docker_kafka_data"
  "docker_zookeeper_data"
  "docker_schema_registry_data"
  "docker_clickhouse_data"
)

for VOLUME in "${VOLUMES[@]}"; do
  echo "Backing up $VOLUME..."

  docker run --rm \
    -v ${VOLUME}:/data \
    -v ${BACKUP_DIR}:/backup \
    alpine \
    tar czf /backup/${VOLUME}_${TIMESTAMP}.tar.gz -C /data .

  echo "  ✅ ${VOLUME} backed up"
done

echo "✅ All volumes backed up"
```

#### Single Volume Backup

```bash
# Backup specific volume
docker run --rm \
  -v docker_postgresql_data:/data \
  -v /backup:/backup \
  alpine \
  sh -c "cd /data && tar czf /backup/postgres_$(date +%Y%m%d).tar.gz ."
```

### 5. Configuration Files Backup

```bash
#!/bin/bash
# Backup configuration files

BACKUP_DIR="/backup/daily/configs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/path/to/shudl"

mkdir -p $BACKUP_DIR

# Backup docker compose and configs
tar czf "${BACKUP_DIR}/configs_${TIMESTAMP}.tar.gz" \
  -C ${PROJECT_DIR} \
  docker/docker-compose.yml \
  docker/.env \
  docker/config/ \
  configs/

# Backup scripts
tar czf "${BACKUP_DIR}/scripts_${TIMESTAMP}.tar.gz" \
  -C ${PROJECT_DIR} \
  scripts/

echo "✅ Configuration files backed up"
```

### 6. Kafka Topics Backup

```bash
#!/bin/bash
# Export Kafka topics

BACKUP_DIR="/backup/weekly/kafka"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Export topic data using kafka-console-consumer
docker exec docker-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic _schemas \
  --from-beginning \
  --timeout-ms 30000 \
  > "${BACKUP_DIR}/schemas_topic_${TIMESTAMP}.json"

# Export consumer group offsets
docker exec docker-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --all-groups \
  --describe \
  > "${BACKUP_DIR}/consumer_groups_${TIMESTAMP}.txt"

echo "✅ Kafka topics exported"
```

### 7. Schema Registry Backup

```bash
#!/bin/bash
# Backup Schema Registry schemas

BACKUP_DIR="/backup/weekly/schema-registry"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Export all subjects and schemas
SUBJECTS=$(curl -s http://localhost:8085/subjects | jq -r '.[]')

for SUBJECT in $SUBJECTS; do
  echo "Exporting $SUBJECT..."

  # Get all versions
  VERSIONS=$(curl -s "http://localhost:8085/subjects/${SUBJECT}/versions" | jq -r '.[]')

  for VERSION in $VERSIONS; do
    curl -s "http://localhost:8085/subjects/${SUBJECT}/versions/${VERSION}" \
      > "${BACKUP_DIR}/${SUBJECT}_v${VERSION}_${TIMESTAMP}.json"
  done
done

# Export compatibility config
curl -s http://localhost:8085/config \
  > "${BACKUP_DIR}/compatibility_config_${TIMESTAMP}.json"

echo "✅ Schema Registry schemas exported"
```

---

## Restore Procedures

### 1. Restore PostgreSQL Database

#### Full Database Restore

```bash
#!/bin/bash
# Restore PostgreSQL from backup

BACKUP_FILE="/backup/daily/postgresql/shudl_20251126_0300.sql.gz"

# Stop dependent services
docker compose stop nessie trino spark-master

# Restore database
gunzip -c $BACKUP_FILE | docker exec -i docker-postgresql psql -U postgres -d shudl

# Restart services
docker compose start nessie trino spark-master

echo "✅ PostgreSQL restored"
```

#### Restore All Databases

```bash
# Restore all databases including roles
gunzip -c /backup/daily/postgresql/all_databases_20251126.sql.gz \
  | docker exec -i docker-postgresql psql -U postgres
```

#### Point-in-Time Recovery (if WAL archiving enabled)

```bash
# Restore base backup
gunzip -c base_backup.tar.gz | docker exec -i docker-postgresql tar xzf -C /var/lib/postgresql/data

# Apply WAL files
# Configure recovery.conf and restart PostgreSQL
```

### 2. Restore MinIO Data

#### Full Bucket Restore

```bash
#!/bin/bash
# Restore MinIO bucket

BACKUP_FILE="/backup/daily/minio/lakehouse_20251126_0300.tar.gz"
RESTORE_DIR="/tmp/restore_minio"

# Extract backup
mkdir -p $RESTORE_DIR
tar xzf $BACKUP_FILE -C $RESTORE_DIR

# Configure mc
docker exec docker-minio mc alias set local \
  http://localhost:9000 \
  ${MINIO_ROOT_USER} \
  ${MINIO_ROOT_PASSWORD}

# Restore bucket
docker exec docker-minio mc mirror \
  --overwrite \
  ${RESTORE_DIR}/lakehouse \
  local/lakehouse

rm -rf $RESTORE_DIR

echo "✅ MinIO bucket restored"
```

### 3. Restore Docker Volumes

```bash
#!/bin/bash
# Restore Docker volume

VOLUME_NAME="docker_postgresql_data"
BACKUP_FILE="/backup/daily/volumes/${VOLUME_NAME}_20251126.tar.gz"

# Stop services using the volume
docker compose stop postgresql

# Remove old volume
docker volume rm $VOLUME_NAME

# Create new volume
docker volume create $VOLUME_NAME

# Restore data
docker run --rm \
  -v ${VOLUME_NAME}:/data \
  -v $(dirname $BACKUP_FILE):/backup \
  alpine \
  sh -c "cd /data && tar xzf /backup/$(basename $BACKUP_FILE)"

# Restart services
docker compose start postgresql

echo "✅ Volume ${VOLUME_NAME} restored"
```

### 4. Restore Configuration Files

```bash
#!/bin/bash
# Restore configuration

BACKUP_FILE="/backup/daily/configs/configs_20251126.tar.gz"
PROJECT_DIR="/path/to/shudl"

# Extract configurations
tar xzf $BACKUP_FILE -C $PROJECT_DIR

# Restart services to apply config
docker compose down
docker compose up -d

echo "✅ Configuration restored"
```

### 5. Restore Schema Registry Schemas

```bash
#!/bin/bash
# Restore Schema Registry schemas

BACKUP_DIR="/backup/weekly/schema-registry"

# Find latest backup files
LATEST_BACKUP=$(ls -t ${BACKUP_DIR}/*_config_*.json | head -1)
TIMESTAMP=$(echo $LATEST_BACKUP | grep -oP '\d{8}_\d{6}')

# Restore compatibility config
curl -X PUT -H "Content-Type: application/json" \
  --data @${BACKUP_DIR}/compatibility_config_${TIMESTAMP}.json \
  http://localhost:8085/config

# Restore schemas
for SCHEMA_FILE in ${BACKUP_DIR}/*_${TIMESTAMP}.json; do
  if [[ $SCHEMA_FILE != *"compatibility_config"* ]]; then
    SUBJECT=$(basename $SCHEMA_FILE | cut -d'_' -f1)

    curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data @${SCHEMA_FILE} \
      http://localhost:8085/subjects/${SUBJECT}/versions
  fi
done

echo "✅ Schema Registry restored"
```

---

## Disaster Recovery

### Complete System Recovery

#### Scenario: Total System Failure

**Steps:**

1. **Provision New Infrastructure**

   ```bash
   # Install Docker and Docker Compose
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

2. **Clone Repository**

   ```bash
   git clone https://github.com/Shugur-Network/shudl.git
   cd shudl
   ```

3. **Restore Configuration**

   ```bash
   # Copy backed up configs
   tar xzf /backup/configs_latest.tar.gz -C .

   # Update .env with current values
   cp docker/.env.example docker/.env
   nano docker/.env
   ```

4. **Restore Docker Volumes**

   ```bash
   # Create volumes
   docker compose up --no-start

   # Restore each volume
   for VOLUME in postgresql_data minio_data kafka_data; do
     docker run --rm \
       -v docker_${VOLUME}:/data \
       -v /backup:/backup \
       alpine \
       tar xzf /backup/docker_${VOLUME}_latest.tar.gz -C /data
   done
   ```

5. **Restore Databases**

   ```bash
   # Start PostgreSQL
   docker compose up -d postgresql
   sleep 30

   # Restore database
   gunzip -c /backup/postgresql/shudl_latest.sql.gz \
     | docker exec -i docker-postgresql psql -U postgres -d shudl
   ```

6. **Restore MinIO Data**

   ```bash
   # Start MinIO
   docker compose up -d minio
   sleep 20

   # Restore buckets
   tar xzf /backup/minio/lakehouse_latest.tar.gz -C /tmp
   docker exec docker-minio mc mirror /tmp/lakehouse local/lakehouse
   ```

7. **Start All Services**

   ```bash
   docker compose up -d

   # Verify
   docker compose ps
   ```

8. **Validate Data Integrity**

   ```bash
   # Check PostgreSQL
   docker exec docker-postgresql psql -U postgres -d shudl -c "\dt"

   # Check MinIO
   docker exec docker-minio mc ls local/lakehouse/

   # Check Nessie
   curl http://localhost:19120/api/v2/trees
   ```

### Service-Specific Recovery

#### PostgreSQL Corruption

```bash
# 1. Stop service
docker compose stop postgresql

# 2. Backup corrupted data
docker run --rm -v docker_postgresql_data:/data -v /backup:/backup alpine \
  tar czf /backup/corrupted_$(date +%Y%m%d).tar.gz -C /data .

# 3. Remove corrupted volume
docker volume rm docker_postgresql_data

# 4. Restore from backup (see restore procedures)

# 5. Restart
docker compose up -d postgresql
```

#### MinIO Data Loss

```bash
# 1. Identify missing/corrupted objects
docker exec docker-minio mc ls --recursive local/lakehouse/

# 2. Restore from backup
docker exec docker-minio mc mirror \
  /backup/minio/lakehouse_latest/ \
  local/lakehouse/

# 3. Verify integrity
docker exec docker-minio mc admin heal local/lakehouse
```

---

## Automated Backup

### Complete Backup Script

Create `/scripts/backup-all.sh`:

```bash
#!/bin/bash
#
# ShuDL Complete Backup Script
# Run daily via cron: 0 3 * * * /path/to/shudl/scripts/backup-all.sh
#

set -e

# Configuration
BACKUP_ROOT="/backup"
PROJECT_DIR="/path/to/shudl"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y%m%d)

# Backup directories
DAILY_DIR="${BACKUP_ROOT}/daily/${DATE}"
mkdir -p ${DAILY_DIR}/{postgresql,minio,volumes,configs,logs}

# Logging
LOG_FILE="${DAILY_DIR}/logs/backup_${TIMESTAMP}.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=================================================="
echo "ShuDL Backup Started: $(date)"
echo "=================================================="

# 1. Backup PostgreSQL
echo ""
echo "📦 Backing up PostgreSQL..."
docker exec docker-postgresql pg_dumpall -U postgres --clean --if-exists \
  | gzip > "${DAILY_DIR}/postgresql/all_databases.sql.gz"
echo "   ✅ PostgreSQL backup complete ($(du -h ${DAILY_DIR}/postgresql/all_databases.sql.gz | cut -f1))"

# 2. Backup MinIO
echo ""
echo "📦 Backing up MinIO..."
docker exec docker-minio mc alias set local http://localhost:9000 \
  ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null

docker run --rm \
  --network docker_shunetwork \
  -v ${DAILY_DIR}/minio:/backup \
  minio/mc \
  mirror --preserve local/lakehouse /backup/lakehouse

cd ${DAILY_DIR}/minio && tar czf lakehouse.tar.gz lakehouse && rm -rf lakehouse
echo "   ✅ MinIO backup complete ($(du -h ${DAILY_DIR}/minio/lakehouse.tar.gz | cut -f1))"

# 3. Backup Docker Volumes
echo ""
echo "📦 Backing up Docker volumes..."
VOLUMES=("postgresql_data" "kafka_data" "zookeeper_data" "clickhouse_data")

for VOL in "${VOLUMES[@]}"; do
  echo "   Backing up docker_${VOL}..."
  docker run --rm \
    -v docker_${VOL}:/data \
    -v ${DAILY_DIR}/volumes:/backup \
    alpine \
    tar czf /backup/${VOL}.tar.gz -C /data . 2>/dev/null
done
echo "   ✅ Volumes backup complete"

# 4. Backup Configurations
echo ""
echo "📦 Backing up configurations..."
tar czf ${DAILY_DIR}/configs/shudl_configs.tar.gz \
  -C ${PROJECT_DIR} \
  docker/docker-compose.yml \
  docker/.env \
  docker/config/ \
  configs/ \
  scripts/ \
  docs/ 2>/dev/null
echo "   ✅ Configurations backup complete ($(du -h ${DAILY_DIR}/configs/shudl_configs.tar.gz | cut -f1))"

# 5. Backup Schema Registry
echo ""
echo "📦 Backing up Schema Registry..."
SUBJECTS=$(curl -s http://localhost:8085/subjects 2>/dev/null | jq -r '.[]')
SCHEMA_DIR="${DAILY_DIR}/schema-registry"
mkdir -p ${SCHEMA_DIR}

for SUBJECT in $SUBJECTS; do
  curl -s "http://localhost:8085/subjects/${SUBJECT}/versions/latest" \
    > "${SCHEMA_DIR}/${SUBJECT}.json" 2>/dev/null
done
curl -s http://localhost:8085/config > "${SCHEMA_DIR}/config.json" 2>/dev/null
echo "   ✅ Schema Registry backup complete"

# 6. Create backup manifest
echo ""
echo "📋 Creating backup manifest..."
cat > ${DAILY_DIR}/MANIFEST.txt << EOF
ShuDL Backup Manifest
=====================
Date: $(date)
Backup ID: ${DATE}_${TIMESTAMP}

Contents:
- PostgreSQL: all_databases.sql.gz
- MinIO: lakehouse.tar.gz
- Volumes: $(ls ${DAILY_DIR}/volumes/*.tar.gz | wc -l) volume(s)
- Configs: shudl_configs.tar.gz
- Schema Registry: $(ls ${SCHEMA_DIR}/*.json 2>/dev/null | wc -l) schema(s)

Total Size: $(du -sh ${DAILY_DIR} | cut -f1)

Verification:
$(md5sum ${DAILY_DIR}/*/*.{gz,json} 2>/dev/null | head -10)

EOF

# 7. Cleanup old backups
echo ""
echo "🧹 Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
find ${BACKUP_ROOT}/daily -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} + 2>/dev/null || true
echo "   ✅ Cleanup complete"

# 8. Summary
echo ""
echo "=================================================="
echo "Backup Summary:"
echo "=================================================="
echo "Location: ${DAILY_DIR}"
echo "Total Size: $(du -sh ${DAILY_DIR} | cut -f1)"
echo "Files:"
ls -lh ${DAILY_DIR}/*/* 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "✅ Backup completed successfully: $(date)"
echo "=================================================="

# Optional: Send notification (email, Slack, etc.)
# curl -X POST -H 'Content-type: application/json' \
#   --data "{\"text\":\"ShuDL backup completed: ${DATE}\"}" \
#   ${SLACK_WEBHOOK_URL}
```

### Cron Schedule

```bash
# Edit crontab
crontab -e

# Add backup schedule
# Daily backup at 3 AM
0 3 * * * /path/to/shudl/scripts/backup-all.sh

# Weekly full backup on Sunday at 2 AM
0 2 * * 0 /path/to/shudl/scripts/backup-all.sh --full

# Monthly backup on 1st day at 1 AM
0 1 1 * * /path/to/shudl/scripts/backup-all.sh --monthly
```

### Offsite Backup

```bash
#!/bin/bash
# Sync backups to S3/Cloud

# AWS S3
aws s3 sync /backup/daily/ s3://shudl-backups/daily/ \
  --exclude "*.log" \
  --storage-class STANDARD_IA

# Or Google Cloud Storage
gsutil -m rsync -r -d /backup/daily/ gs://shudl-backups/daily/

# Or rsync to remote server
rsync -avz --delete \
  /backup/daily/ \
  backup-server:/backups/shudl/daily/
```

---

## Testing & Validation

### Monthly Backup Testing

```bash
#!/bin/bash
# Test backup restoration (run monthly)

TEST_DIR="/tmp/shudl_restore_test_$(date +%Y%m%d)"
mkdir -p $TEST_DIR

echo "🧪 Testing backup restoration..."

# 1. Test PostgreSQL restore
echo "Testing PostgreSQL backup..."
gunzip -c /backup/daily/latest/postgresql/all_databases.sql.gz | head -100
echo "   ✅ PostgreSQL backup readable"

# 2. Test MinIO backup
echo "Testing MinIO backup..."
tar tzf /backup/daily/latest/minio/lakehouse.tar.gz | head -20
echo "   ✅ MinIO backup readable"

# 3. Test volume backup
echo "Testing volume backups..."
for VOL in /backup/daily/latest/volumes/*.tar.gz; do
  tar tzf $VOL > /dev/null && echo "   ✅ $(basename $VOL) OK"
done

# 4. Verify checksums
echo "Verifying checksums..."
md5sum -c /backup/daily/latest/checksums.md5
echo "   ✅ Checksums verified"

echo ""
echo "✅ Backup validation complete"
```

### Restoration Dry Run

```bash
# Quarterly full restoration test
# Create isolated test environment

docker compose -f docker-compose.test.yml up -d
# Restore backups to test environment
# Validate data integrity
# Tear down test environment
```

---

## Best Practices

### 1. Backup Before Changes

```bash
# Always backup before major changes
./scripts/backup-all.sh --pre-upgrade
docker compose down
# Perform upgrade
docker compose up -d
```

### 2. Verify Backups

```bash
# Test one backup per month
# Ensure backups are readable
# Validate data integrity
```

### 3. Document Recovery Times

```bash
# Track actual recovery times
# Update RTO targets based on reality
# Practice makes perfect
```

### 4. Monitor Backup Success

```bash
# Check backup logs daily
# Alert on backup failures
# Monitor backup size trends
```

### 5. Secure Backup Storage

```bash
# Encrypt backups at rest
# Restrict access permissions
# Use separate credentials
```

### 6. Test Recovery Procedures

```bash
# Document actual steps taken
# Update procedures based on lessons learned
# Train team on recovery
```

---

## Checklist

### Daily Tasks

- [ ] Verify backup completed successfully
- [ ] Check backup size (watch for anomalies)
- [ ] Review backup logs for errors

### Weekly Tasks

- [ ] Test random backup restore
- [ ] Verify offsite sync completed
- [ ] Review disk space usage

### Monthly Tasks

- [ ] Full restoration test
- [ ] Update documentation
- [ ] Review and adjust retention policies

### Quarterly Tasks

- [ ] Disaster recovery drill
- [ ] Review RTO/RPO targets
- [ ] Update runbooks

---

## Emergency Contacts

**Backup Issues:**

- Primary: DevOps Team (devops@shugur.com)
- Secondary: Platform Team Lead
- Escalation: CTO

**Storage Issues:**

- Storage Admin Team
- Cloud Provider Support

**After-Hours Emergency:**

- On-call rotation (see PagerDuty)

---

## References

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [MinIO Backup Guide](https://min.io/docs/minio/linux/operations/backup.html)
- [Docker Volume Backup](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes)

For troubleshooting, see [`troubleshooting.md`](./troubleshooting.md).
