# HA Deployment Order - Step by Step

This document provides the exact order and steps to deploy the Datalyptica Data Platform with High Availability.

## Phase 0: Prerequisites (30 minutes)

### Step 0.1: Verify Cluster Requirements

```bash
# Check OpenShift version (must be 4.10+)
oc version

# Check cluster resources
oc adm top nodes

# Count worker nodes (need at least 10 for proper HA)
oc get nodes -l node-role.kubernetes.io/worker= --no-headers | wc -l

# Check storage classes
oc get sc
# You need at least one RWO storage class
# RWX is optional but recommended
```

**Decision Point:** Do you have sufficient resources?

- ✅ YES → Continue to Step 0.2
- ❌ NO → Scale up cluster or adjust deployment for smaller footprint

---

### Step 0.2: Create Projects/Namespaces

```bash
# Create projects
oc apply -f 00-prerequisites/namespaces.yaml

# Verify creation
oc get projects | grep datalyptica

# Expected output:
# datalyptica-infra      Active
# datalyptica-data       Active
# datalyptica-apps       Active
# datalyptica-monitoring Active
```

**Validation:** All 4 projects should be in Active state.

---

### Step 0.3: Install Operators

```bash
# Subscribe to all required operators
oc apply -f 00-prerequisites/operator-subscriptions.yaml

# Watch installation (takes 5-10 minutes)
watch oc get csv -n openshift-operators

# Wait until all operators show "Succeeded" in PHASE column
```

**Expected Operators:**

- ✅ Crunchy Postgres Operator (or equivalent)
- ✅ Redis Enterprise Operator
- ✅ MinIO Operator
- ✅ Strimzi Kafka Operator
- ✅ Flink Kubernetes Operator (optional for Phase 4)

**Validation:** Run `oc get csv -n openshift-operators` and verify all show `Succeeded`.

---

### Step 0.4: Configure Storage

```bash
# Review available storage classes
oc get sc

# Update storage class names in all YAML files if needed
# Default assumes 'standard' for RWO

# If your cluster uses a different name, run:
export STORAGE_CLASS="<your-storage-class-name>"

# Update all files (we'll do this per phase)
```

**Note:** Save your storage class name - you'll need it in each phase.

---

## Phase 1: Core Infrastructure (45 minutes)

### Step 1.1: Deploy PostgreSQL HA with Patroni

**Time: 20 minutes**

```bash
cd 01-postgresql-ha

# Review the README
cat README.md

# Option A: Using Crunchy Postgres Operator
oc apply -f operator-install.yaml
oc apply -f postgres-cluster.yaml

# Option B: Using Patroni Operator (if Crunchy not available)
# Follow specific instructions in 01-postgresql-ha/README.md

# Watch cluster creation
watch oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# Wait for 3 pods to be Running (1 primary + 2 replicas)
```

**Validation:**

```bash
# Check cluster status
oc exec -n datalyptica-infra -it datalyptica-pg-instance1-xxxx -- patronictl list

# Expected output shows:
# + Cluster: datalyptica-pg (7123456789012345678) -----+----+-----------+
# | Member                 | Host         | Role    | State   | TL | Lag in MB |
# +------------------------+--------------+---------+---------+----+-----------+
# | datalyptica-pg-instance1-0 | 10.x.x.x | Leader  | running |  1 |           |
# | datalyptica-pg-instance1-1 | 10.x.x.x | Replica | running |  1 |         0 |
# | datalyptica-pg-instance1-2 | 10.x.x.x | Replica | running |  1 |         0 |
```

**Troubleshooting:**

- If pods are Pending: Check PVC binding and storage class
- If pods are CrashLooping: Check logs with `oc logs -n datalyptica-infra <pod-name>`
- If cluster doesn't form: Check network policies and pod-to-pod communication

✅ **Checkpoint:** 3 PostgreSQL pods running, 1 leader + 2 replicas

---

### Step 1.2: Deploy Redis HA with Sentinel

**Time: 15 minutes**

```bash
cd ../02-redis-ha

# Deploy Redis Sentinel configuration
oc apply -f redis-sentinel.yaml

# Watch deployment
watch oc get pods -n datalyptica-infra -l app=redis

# Wait for 6 pods total:
# - 3 Redis pods (1 master + 2 replicas)
# - 3 Sentinel pods
```

**Validation:**

```bash
# Check Redis master
oc exec -n datalyptica-infra -it redis-0 -- redis-cli INFO replication

# Expected output includes:
# role:master
# connected_slaves:2

# Check Sentinel status
oc exec -n datalyptica-infra -it redis-sentinel-0 -- redis-cli -p 26379 SENTINEL masters

# Should show 1 master being monitored with 2 slaves
```

✅ **Checkpoint:** 6 pods running (3 Redis + 3 Sentinel), master elected

---

### Step 1.3: Deploy etcd HA Cluster

**Time: 10 minutes**

```bash
cd ../03-etcd-ha

# Deploy etcd cluster
oc apply -f etcd-cluster.yaml

# Watch cluster formation
watch oc get pods -n datalyptica-infra -l app=etcd

# Wait for 3 etcd pods
```

**Validation:**

```bash
# Check cluster health
oc exec -n datalyptica-infra -it etcd-0 -- etcdctl \
  --endpoints=http://etcd-0.etcd-headless:2379,http://etcd-1.etcd-headless:2379,http://etcd-2.etcd-headless:2379 \
  endpoint health

# All 3 endpoints should show "healthy"
```

✅ **Checkpoint:** 3 etcd pods running, cluster healthy

---

## Phase 2: Object Storage (30 minutes)

### Step 2.1: Deploy MinIO Distributed

**Time: 30 minutes**

```bash
cd ../04-minio-ha

# Install MinIO Operator (if not already done)
oc apply -f operator-install.yaml

# Wait for operator to be ready
oc get pods -n minio-operator

# Deploy MinIO tenant (4-node distributed)
oc apply -f minio-tenant.yaml

# Watch tenant creation (takes 10-15 minutes)
watch oc get pods -n datalyptica-infra -l app=minio

# Wait for 4 MinIO pods to be Running
```

**Validation:**

```bash
# Get MinIO console route
MINIO_CONSOLE=$(oc get route -n datalyptica-infra minio-console -o jsonpath='{.spec.host}')
echo "MinIO Console: https://$MINIO_CONSOLE"

# Log in using credentials from secret
oc get secret -n datalyptica-infra datalyptica-minio-creds-secret -o jsonpath='{.data.accesskey}' | base64 -d
oc get secret -n datalyptica-infra datalyptica-minio-creds-secret -o jsonpath='{.data.secretkey}' | base64 -d

# Check cluster status via console or CLI
oc exec -n datalyptica-infra -it minio-pool-0-0 -- mc admin info local

# Should show:
# - 4 servers online
# - Total capacity across 4 nodes
# - Erasure coding: EC:2 (N/2)
```

**Create Buckets:**

```bash
# Create required buckets
oc exec -n datalyptica-infra -it minio-pool-0-0 -- sh -c '
mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
mc mb local/lakehouse
mc mb local/warehouse
mc mb local/bronze
mc mb local/silver
mc mb local/gold
mc mb local/backups
mc ls local
'
```

✅ **Checkpoint:** 4 MinIO pods running, all buckets created, erasure coding enabled

---

## Phase 3: Catalog Service (15 minutes)

### Step 3.1: Deploy Nessie with HA Backend

**Time: 15 minutes**

```bash
cd ../05-nessie

# Deploy Nessie (connects to PostgreSQL HA cluster)
oc apply -f nessie-deployment.yaml

# Watch deployment
watch oc get pods -n datalyptica-data -l app=nessie

# Wait for 2 Nessie pods (for redundancy)
```

**Validation:**

```bash
# Get Nessie route
NESSIE_URL=$(oc get route -n datalyptica-data nessie-api -o jsonpath='{.spec.host}')
echo "Nessie API: https://$NESSIE_URL"

# Initialize default branch
curl -X POST https://$NESSIE_URL/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"main","type":"BRANCH"}'

# List branches
curl https://$NESSIE_URL/api/v2/trees

# Should return JSON with "main" branch
```

✅ **Checkpoint:** 2 Nessie pods running, API accessible, default branch created

---

## Phase 1 Completion Check

At this point, you should have:

```bash
# Check all core infrastructure pods
oc get pods -n datalyptica-infra

# Expected:
# PostgreSQL: 3 pods (datalyptica-pg-instance1-0, -1, -2)
# Redis: 3 pods (redis-0, redis-1, redis-2)
# Sentinel: 3 pods (redis-sentinel-0, -1, -2)
# etcd: 3 pods (etcd-0, etcd-1, etcd-2)
# MinIO: 4 pods (minio-pool-0-0, -1, -2, -3)

# Check data layer
oc get pods -n datalyptica-data
# Expected:
# Nessie: 2 pods (nessie-xxxx, nessie-yyyy)

# Total: 18 pods running across infrastructure and data layers
```

**Decision Point:** Are all Phase 1 services healthy?

- ✅ YES → Proceed to Phase 4 (Streaming & Processing)
- ❌ NO → Review troubleshooting section in each component's README

---

## Phase 4: Streaming & Processing (45 minutes)

**Note:** This phase will be detailed in separate documents for:

- Kafka (Strimzi operator)
- Flink (Flink Kubernetes Operator)

---

## Phase 5: Query & Analytics (60 minutes)

**Note:** This phase will be detailed in separate documents for:

- Trino (custom HA deployment)
- Spark (Spark Operator)
- ClickHouse (ClickHouse Operator)

---

## Phase 6: Orchestration & BI (45 minutes)

**Note:** This phase will be detailed in separate documents for:

- Airflow (custom HA with CeleryExecutor)
- Superset (with PostgreSQL backend)

---

## Post-Deployment Validation

### Overall Health Check

```bash
# Check all namespaces
oc get pods --all-namespaces | grep datalyptica

# Check PVCs
oc get pvc -n datalyptica-infra
oc get pvc -n datalyptica-data
oc get pvc -n datalyptica-apps

# Check services
oc get svc -n datalyptica-infra
oc get svc -n datalyptica-data
oc get svc -n datalyptica-apps

# Check routes
oc get routes --all-namespaces | grep datalyptica
```

### HA Validation Tests

**Test 1: PostgreSQL Failover**

```bash
# Simulate primary failure
oc delete pod -n datalyptica-infra datalyptica-pg-instance1-0

# Watch automatic failover (should take < 30 seconds)
watch oc exec -n datalyptica-infra -it datalyptica-pg-instance1-1 -- patronictl list

# One of the replicas should become the new leader
```

**Test 2: Redis Failover**

```bash
# Get current master
REDIS_MASTER=$(oc exec -n datalyptica-infra redis-sentinel-0 -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster | head -1)
echo "Current master: $REDIS_MASTER"

# Delete master pod
oc delete pod -n datalyptica-infra redis-0

# Watch sentinel elect new master (should take < 20 seconds)
watch oc exec -n datalyptica-infra redis-sentinel-0 -- redis-cli -p 26379 SENTINEL masters
```

**Test 3: MinIO Node Failure**

```bash
# Delete one MinIO pod
oc delete pod -n datalyptica-infra minio-pool-0-0

# MinIO should continue serving requests (no downtime)
# Upload test file
oc exec -n datalyptica-infra minio-pool-0-1 -- mc cp /etc/hosts local/lakehouse/test.txt

# Verify file accessible after pod restarts
sleep 30
oc exec -n datalyptica-infra minio-pool-0-0 -- mc cat local/lakehouse/test.txt
```

---

## Rollback Procedures

If something goes wrong, rollback in reverse order:

### Rollback Phase 3 (Nessie)

```bash
oc delete -f 05-nessie/nessie-deployment.yaml
```

### Rollback Phase 2 (MinIO)

```bash
oc delete -f 04-minio-ha/minio-tenant.yaml
# Wait for all pods to terminate
oc delete pvc -n datalyptica-infra -l app=minio
```

### Rollback Phase 1 (Core Infrastructure)

```bash
# etcd
oc delete -f 03-etcd-ha/etcd-cluster.yaml
oc delete pvc -n datalyptica-infra -l app=etcd

# Redis
oc delete -f 02-redis-ha/redis-sentinel.yaml
oc delete pvc -n datalyptica-infra -l app=redis

# PostgreSQL
oc delete -f 01-postgresql-ha/postgres-cluster.yaml
oc delete pvc -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg
```

---

## Next Steps

Once Phase 1 (Core Infrastructure) is complete and validated:

1. **Document your deployment:**

   - Storage class used
   - Any customizations made
   - Routes/URLs for each service
   - Credentials location

2. **Set up monitoring:**

   - Deploy Prometheus operator
   - Configure ServiceMonitors
   - Set up Grafana dashboards

3. **Configure backups:**

   - PostgreSQL: Configure pgBackRest
   - MinIO: Set up bucket replication
   - etcd: Schedule snapshot jobs

4. **Proceed to Phase 4:** Streaming & Processing components

---

## Time Investment Summary

| Phase                        | Time   | Cumulative       |
| ---------------------------- | ------ | ---------------- |
| Prerequisites                | 30 min | 30 min           |
| Phase 1: Core Infrastructure | 45 min | 1h 15min         |
| Phase 2: Object Storage      | 30 min | 1h 45min         |
| Phase 3: Catalog             | 15 min | 2h               |
| **First Checkpoint**         |        | **2 hours**      |
| Phase 4: Streaming           | 45 min | 2h 45min         |
| Phase 5: Analytics           | 60 min | 3h 45min         |
| Phase 6: Orchestration       | 45 min | 4h 30min         |
| **Full Deployment**          |        | **~4.5-5 hours** |

Plan for a full day with testing and validation!
