# PostgreSQL HA Deployment with Crunchy Postgres Operator

This directory contains manifests for deploying PostgreSQL with High Availability using the Crunchy Postgres Operator.

## Overview

**Architecture:**

- 3-node PostgreSQL cluster
- 1 Primary + 2 Replicas
- Automatic failover with Patroni
- Synchronous replication
- 10Gi storage per node (30Gi total)
- Connection pooling with PgBouncer
- Automated backups with pgBackRest

**HA Characteristics:**

- **Availability:** 99.95%
- **RPO:** < 10 seconds (synchronous replication)
- **RTO:** < 30 seconds (automatic failover)
- **Read Scaling:** Load balance reads across replicas

## Prerequisites

1. **Crunchy Postgres Operator installed:**

   ```bash
   oc get csv -n openshift-operators | grep postgresql
   ```

   Should show: `postgresql-operator.v5.x.x` in `Succeeded` phase

2. **Storage class available:**

   ```bash
   oc get sc
   ```

   Note your RWO storage class name

3. **Namespace created:**
   ```bash
   oc get project datalyptica-infra
   ```

## Files

- `postgres-cluster.yaml` - PostgresCluster custom resource (3-node HA)
- `monitoring.yaml` - ServiceMonitor for Prometheus integration
- `pgbouncer-config.yaml` - PgBouncer connection pooling configuration

## Deployment

### Step 1: Update Storage Class (if needed)

If your cluster doesn't use `standard` storage class:

```bash
# Find your storage class
oc get sc

# Update the YAML
export STORAGE_CLASS="your-storage-class-name"
sed -i.bak "s/storageClassName: standard/storageClassName: $STORAGE_CLASS/g" postgres-cluster.yaml
```

### Step 2: Create PostgreSQL Cluster

```bash
# Deploy the cluster
oc apply -f postgres-cluster.yaml

# Watch cluster creation (takes 5-10 minutes)
watch oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# You should see:
# - 3 instance pods (datalyptica-pg-instance1-xxxx)
# - 1 repo-host pod (for backups)
# - 1 pgbouncer pod (for connection pooling)
```

### Step 3: Wait for Cluster to be Ready

```bash
# Check PostgresCluster status
oc get postgrescluster -n datalyptica-infra datalyptica-pg

# When STATUS shows "postgres cluster available", you're ready
```

### Step 4: Verify Cluster Health

```bash
# Get pod names
oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg -l postgres-operator.crunchydata.com/instance

# Check Patroni cluster status (replace pod name)
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-0 -- patronictl list

# Expected output:
# + Cluster: datalyptica-pg-ha (7123456789012345678) --+----+-----------+
# | Member                  | Host         | Role    | State   | TL | Lag in MB |
# +-------------------------+--------------+---------+---------+----+-----------+
# | datalyptica-pg-instance1-... | 10.x.x.x | Leader  | running |  1 |           |
# | datalyptica-pg-instance1-... | 10.x.x.x | Replica | running |  1 |         0 |
# | datalyptica-pg-instance1-... | 10.x.x.x | Replica | running |  1 |         0 |
```

### Step 5: Get Connection Details

```bash
# Get primary service (read-write)
oc get svc -n datalyptica-infra datalyptica-pg-primary

# Get replica service (read-only)
oc get svc -n datalyptica-infra datalyptica-pg-replicas

# Get PgBouncer service (connection pooling)
oc get svc -n datalyptica-infra datalyptica-pg-pgbouncer

# Get credentials
oc get secret -n datalyptica-infra datalyptica-pg-pguser-postgres -o jsonpath='{.data.password}' | base64 -d
echo ""
```

### Step 6: Test Connection

```bash
# Connect to primary (via PgBouncer)
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-0 -- \
  psql -h datalyptica-pg-pgbouncer -U postgres -d postgres -c "SELECT version();"

# Test replication lag
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-0 -- \
  psql -h localhost -U postgres -d postgres -c "SELECT client_addr, state, sync_state, replay_lag FROM pg_stat_replication;"
```

## Connection Strings

For applications connecting to PostgreSQL:

**Primary (Read-Write):**

```
Host: datalyptica-pg-primary.datalyptica-infra.svc.cluster.local
Port: 5432
User: postgres
Password: <from secret>
Database: postgres
```

**Replicas (Read-Only):**

```
Host: datalyptica-pg-replicas.datalyptica-infra.svc.cluster.local
Port: 5432
User: postgres
Password: <from secret>
Database: postgres
```

**PgBouncer (Recommended - Connection Pooling):**

```
Host: datalyptica-pg-pgbouncer.datalyptica-infra.svc.cluster.local
Port: 5432
User: postgres
Password: <from secret>
Database: postgres
```

## Create Application Databases

```bash
# Connect to PostgreSQL
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-0 -- psql -U postgres

# Create databases for each service
CREATE DATABASE nessie;
CREATE DATABASE airflow;
CREATE DATABASE superset;
CREATE DATABASE mlflow;

# Create users with passwords (change these!)
CREATE USER nessie WITH PASSWORD 'nessie-secure-password';
CREATE USER airflow WITH PASSWORD 'airflow-secure-password';
CREATE USER superset WITH PASSWORD 'superset-secure-password';
CREATE USER mlflow WITH PASSWORD 'mlflow-secure-password';

# Grant permissions
GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie;
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;

# Exit
\q
```

## HA Testing

### Test 1: Simulate Primary Failure

```bash
# Get current leader
LEADER=$(oc exec -n datalyptica-infra datalyptica-pg-instance1-xxxx-0 -- \
  patronictl list -f json | jq -r '.[] | select(.Role=="Leader") | .Member')
echo "Current leader: $LEADER"

# Find the leader pod
LEADER_POD=$(oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg | grep $LEADER | awk '{print $1}')

# Delete the leader pod
oc delete pod -n datalyptica-infra $LEADER_POD

# Watch failover (should complete in < 30 seconds)
watch oc exec -n datalyptica-infra datalyptica-pg-instance1-xxxx-1 -- patronictl list

# A replica should be promoted to Leader
```

### Test 2: Verify Synchronous Replication

```bash
# Insert test data on primary
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-0 -- \
  psql -U postgres -d postgres -c "CREATE TABLE ha_test (id INT, ts TIMESTAMP); INSERT INTO ha_test VALUES (1, NOW());"

# Query from replica immediately
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-1 -- \
  psql -U postgres -d postgres -h datalyptica-pg-replicas -c "SELECT * FROM ha_test;"

# Data should be visible immediately (synchronous replication)
```

## Monitoring

### Deploy ServiceMonitor (if Prometheus Operator installed)

```bash
oc apply -f monitoring.yaml
```

### Check Metrics

The Crunchy Postgres Operator exposes metrics on port 9187:

```bash
# Port forward to access metrics locally
oc port-forward -n datalyptica-infra svc/datalyptica-pg-primary 9187:9187

# In another terminal
curl http://localhost:9187/metrics
```

### Key Metrics to Monitor

- `ccp_is_in_recovery` - 0 for primary, 1 for replica
- `ccp_replication_lag_bytes` - Replication lag in bytes
- `ccp_database_size_bytes` - Database size
- `ccp_connection_count` - Active connections
- `ccp_transaction_count` - Transaction rate

## Backups

The Crunchy Postgres Operator automatically configures pgBackRest for backups:

### Check Backup Configuration

```bash
# List backup repo
oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/role=repo-host

# Check backup status
oc exec -n datalyptica-infra -it datalyptica-pg-repo-host-0 -- \
  pgbackrest info --stanza=db
```

### Manual Backup

```bash
# Trigger full backup
oc exec -n datalyptica-infra -it datalyptica-pg-repo-host-0 -- \
  pgbackrest backup --stanza=db --type=full
```

### Restore (if needed)

```bash
# Stop PostgreSQL cluster
oc scale postgrescluster datalyptica-pg -n datalyptica-infra --replicas=0

# Restore from backup
oc exec -n datalyptica-infra -it datalyptica-pg-repo-host-0 -- \
  pgbackrest restore --stanza=db --delta

# Start cluster
oc scale postgrescluster datalyptica-pg -n datalyptica-infra --replicas=3
```

## Troubleshooting

### Pods Not Starting

```bash
# Check events
oc get events -n datalyptica-infra --sort-by='.lastTimestamp' | grep datalyptica-pg

# Check PVC binding
oc get pvc -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# Check pod logs
oc logs -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg --tail=100
```

### Cluster Not Forming

```bash
# Check Patroni logs
oc logs -n datalyptica-infra datalyptica-pg-instance1-xxxx-0 -c database

# Check DCS (etcd/consul) connectivity
oc exec -n datalyptica-infra datalyptica-pg-instance1-xxxx-0 -- patronictl list
```

### Replication Lag

```bash
# Check replication status
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx-0 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check network latency between pods
oc exec -n datalyptica-infra datalyptica-pg-instance1-xxxx-0 -- \
  ping datalyptica-pg-instance1-xxxx-1
```

### Failover Not Working

```bash
# Check Patroni configuration
oc exec -n datalyptica-infra datalyptica-pg-instance1-xxxx-0 -- \
  cat /pgdata/patroni.yaml

# Check operator logs
oc logs -n openshift-operators -l name=postgres-operator --tail=100

# Force switchover
oc exec -n datalyptica-infra datalyptica-pg-instance1-xxxx-0 -- \
  patronictl switchover --master <current-leader> --candidate <target-replica> --force
```

## Scaling

### Add More Replicas (up to 5 recommended)

Edit `postgres-cluster.yaml` and change:

```yaml
spec:
  instances:
    - replicas: 4 # Change from 3 to 4
```

Apply:

```bash
oc apply -f postgres-cluster.yaml
```

### Increase Storage

Storage can be increased (but not decreased):

```yaml
spec:
  instances:
    - dataVolumeClaimSpec:
        resources:
          requests:
            storage: 20Gi # Increase from 10Gi
```

Apply and restart pods for changes to take effect.

## Cleanup

**Warning:** This will delete all data!

```bash
# Delete the cluster
oc delete -f postgres-cluster.yaml

# Delete PVCs
oc delete pvc -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# Verify deletion
oc get pods -n datalyptica-infra | grep postgres
```

## Next Steps

Once PostgreSQL HA is running:

1. ✅ Document connection strings
2. ✅ Save admin credentials securely
3. ✅ Create application databases (Nessie, Airflow, Superset, MLflow)
4. ✅ Configure backup schedule
5. ➡️ Proceed to Redis HA deployment (../02-redis-ha/)
