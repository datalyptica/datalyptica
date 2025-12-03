# PHASE 1: CORE INFRASTRUCTURE DEPLOYMENT

**Time Required:** 90 minutes  
**Components:** PostgreSQL HA, Redis Sentinel, etcd Cluster, MinIO Distributed

---

## 📋 OVERVIEW

In this phase, you will deploy the foundational infrastructure services that support the entire data platform:

| Service        | Purpose               | HA Mode                | Pods        | Storage   |
| -------------- | --------------------- | ---------------------- | ----------- | --------- |
| **PostgreSQL** | Primary database      | 3-node Patroni cluster | 5           | 45Gi      |
| **Redis**      | Cache & session store | Sentinel (3+3)         | 6           | 15Gi      |
| **etcd**       | Distributed config    | 3-node Raft            | 3           | 15Gi      |
| **MinIO**      | Object storage (S3)   | 4-node distributed     | 4           | 200Gi     |
| **TOTAL**      |                       |                        | **18 pods** | **275Gi** |

---

## 🎯 DEPLOYMENT ORDER

**IMPORTANT:** Deploy in this exact order due to dependencies.

```
1. PostgreSQL HA     (20 min)  ← Foundation for Nessie, Airflow, Superset
   ↓
2. Redis Sentinel    (15 min)  ← Required for Airflow, session management
   ↓
3. etcd Cluster      (10 min)  ← Required for distributed coordination
   ↓
4. MinIO Distributed (30 min)  ← Required for data lakehouse, backups
```

---

## 📝 PRE-DEPLOYMENT CHECKLIST

Before starting, ensure:

- [ ] All prerequisites completed (`00-PREREQUISITES/`)
- [ ] All 4 namespaces created and active
- [ ] All 3 operators installed and showing "Succeeded"
- [ ] Storage class identified: **********\_\_\_**********
- [ ] Storage class name updated in ALL 4 YAML files
- [ ] OpenShift Web Console open and logged in
- [ ] CLI access working (optional): `oc whoami`

---

## 🚀 DEPLOYMENT STEPS

### Service 1: PostgreSQL HA (20 minutes)

**Purpose:** Primary relational database with automatic failover

**Steps:**

1. Open `postgresql-ha.yaml` in text editor
2. Find all instances of `storageClassName: standard`
3. Replace with your storage class name
4. Save the file
5. In OpenShift Console:
   - Navigate to **Operators** → **Installed Operators**
   - Select project: `datalyptica-infra`
   - Click **Crunchy Postgres for Kubernetes**
   - Click **PostgresCluster** tab
   - Click **Create PostgresCluster**
   - Switch to **YAML view**
   - Paste entire contents of `postgresql-ha.yaml`
   - Click **Create**
6. Wait for deployment (5-10 minutes)
7. Validate (see validation section below)

**What Gets Created:**

- 3 PostgreSQL instance pods (primary + 2 replicas)
- 2 PgBouncer pods (connection pooling)
- 1 repo-host pod (backup management)
- 3 services (primary, replicas, pgbouncer)
- Multiple PVCs (data + WAL + backups)

**Validation:**

```bash
# Check pods (should see 5+ pods running)
oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# Check cluster status
oc get postgrescluster -n datalyptica-infra

# Should show: STATUS shows green checkmark or "postgres cluster available"
```

**Get Credentials:**

```bash
# PostgreSQL admin password
oc get secret -n datalyptica-infra datalyptica-pg-pguser-postgres \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**Connection String:**

```
Host: datalyptica-pg-pgbouncer.datalyptica-infra.svc.cluster.local
Port: 5432
Database: postgres
User: postgres
Password: <from secret above>
```

---

### Service 2: Redis Sentinel (15 minutes)

**Purpose:** High-performance cache with automatic master election

**Steps:**

1. Open `redis-sentinel.yaml` in text editor
2. Find all instances of `storageClassName: standard`
3. Replace with your storage class name
4. Save the file
5. In OpenShift Console:
   - Click **+** (plus icon) in top-right corner
   - Switch to project: `datalyptica-infra`
   - Paste entire contents of `redis-sentinel.yaml`
   - Click **Create**
6. Wait for deployment (5-7 minutes)
7. Validate (see validation section below)

**What Gets Created:**

- 3 Redis pods (1 master + 2 replicas)
- 3 Redis Sentinel pods (monitoring)
- 2 services (redis, redis-sentinel)
- 3 PVCs for data persistence

**Validation:**

```bash
# Check pods (should see 6 pods running)
oc get pods -n datalyptica-infra -l app=redis

# Check Redis master
oc exec -n datalyptica-infra redis-0 -- redis-cli INFO replication

# Should show: role:master, connected_slaves:2
```

**Get Password:**

```bash
# Redis password
oc get secret -n datalyptica-infra redis-auth \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**Connection String:**

```
# For applications, use Sentinel service:
Host: redis-sentinel.datalyptica-infra.svc.cluster.local
Port: 26379
Master Name: mymaster
Password: <from secret above>
```

---

### Service 3: etcd Cluster (10 minutes)

**Purpose:** Distributed key-value store for configuration management

**Steps:**

1. Open `etcd-cluster.yaml` in text editor
2. Find all instances of `storageClassName: standard`
3. Replace with your storage class name
4. Save the file
5. In OpenShift Console:
   - Click **+** (plus icon) in top-right corner
   - Switch to project: `datalyptica-infra`
   - Paste entire contents of `etcd-cluster.yaml`
   - Click **Create**
6. Wait for deployment (3-5 minutes)
7. Validate (see validation section below)

**What Gets Created:**

- 3 etcd pods (quorum-based cluster)
- 2 services (client, peer communication)
- 3 PVCs for data persistence

**Validation:**

```bash
# Check pods (should see 3 pods running)
oc get pods -n datalyptica-infra -l app=etcd

# Check cluster health
oc exec -n datalyptica-infra etcd-0 -- etcdctl \
  --endpoints=http://etcd-0.etcd-headless:2379,http://etcd-1.etcd-headless:2379,http://etcd-2.etcd-headless:2379 \
  endpoint health

# All 3 endpoints should show "healthy"
```

**Connection String:**

```
Endpoints:
  etcd-0.etcd-headless.datalyptica-infra.svc.cluster.local:2379
  etcd-1.etcd-headless.datalyptica-infra.svc.cluster.local:2379
  etcd-2.etcd-headless.datalyptica-infra.svc.cluster.local:2379
```

---

### Service 4: MinIO Distributed (30 minutes)

**Purpose:** S3-compatible object storage for data lake

**Steps:**

1. Open `minio-distributed.yaml` in text editor
2. Find all instances of `storageClassName: standard`
3. Replace with your storage class name
4. Save the file
5. In OpenShift Console:
   - Navigate to **Operators** → **Installed Operators**
   - Select project: `datalyptica-infra`
   - Click **MinIO Operator**
   - Click **Tenant** tab
   - Click **Create Tenant**
   - Switch to **YAML view**
   - Paste entire contents of `minio-distributed.yaml`
   - Click **Create**
6. Wait for deployment (10-15 minutes)
7. Validate (see validation section below)

**What Gets Created:**

- 4 MinIO server pods (distributed mode)
- 1 MinIO console pod
- 2 services (API, Console)
- 4 PVCs (one per pod, 50Gi each)

**Validation:**

```bash
# Check pods (should see 4 MinIO pods running)
oc get pods -n datalyptica-infra -l v1.min.io/tenant=datalyptica-minio

# Check tenant status
oc get tenant -n datalyptica-infra
```

**Create Console Route:**

```bash
# Create route for MinIO console
oc create route edge minio-console \
  --service=datalyptica-minio-console \
  --port=9090 \
  -n datalyptica-infra

# Get console URL
oc get route -n datalyptica-infra minio-console -o jsonpath='{.spec.host}'
echo
```

**Get Credentials:**

```bash
# MinIO root user
oc get secret -n datalyptica-infra datalyptica-minio-creds-secret \
  -o jsonpath='{.data.accesskey}' | base64 -d && echo

# MinIO root password
oc get secret -n datalyptica-infra datalyptica-minio-creds-secret \
  -o jsonpath='{.data.secretkey}' | base64 -d && echo
```

**Access Console:**

1. Open the console URL from route command above
2. Login with root credentials
3. Create buckets: `lakehouse`, `warehouse`, `bronze`, `silver`, `gold`, `backups`

**Connection String (S3 API):**

```
Endpoint: http://minio.datalyptica-infra.svc.cluster.local:80
Access Key: <from secret above>
Secret Key: <from secret above>
```

---

## ✅ PHASE 1 VALIDATION

After deploying all 4 services, run this comprehensive validation:

### Check All Pods

```bash
# Should see 18 pods total in Running state
oc get pods -n datalyptica-infra

# Expected:
# - 5 PostgreSQL pods (3 instance + 1 repo + 1 pgbouncer)
# - 6 Redis pods (3 redis + 3 sentinel)
# - 3 etcd pods
# - 4 MinIO pods
```

### Check All Services

```bash
# Should see multiple services
oc get svc -n datalyptica-infra

# Expected services:
# - datalyptica-pg-primary (PostgreSQL write)
# - datalyptica-pg-replicas (PostgreSQL read)
# - datalyptica-pg-pgbouncer (Connection pooling)
# - redis (Redis access)
# - redis-sentinel (Sentinel monitoring)
# - etcd, etcd-headless (etcd cluster)
# - minio, datalyptica-minio-console (MinIO)
```

### Check All PVCs

```bash
# All should show "Bound" status
oc get pvc -n datalyptica-infra

# Expected: ~15 PVCs total (varies by operator)
```

### Test Connectivity

**PostgreSQL:**

```bash
POD=$(oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/role=master -o name | head -1)
oc exec -n datalyptica-infra $POD -- psql -U postgres -c "SELECT version();"
```

**Redis:**

```bash
PASSWORD=$(oc get secret -n datalyptica-infra redis-auth -o jsonpath='{.data.password}' | base64 -d)
oc exec -n datalyptica-infra redis-0 -- redis-cli -a $PASSWORD PING
# Should return: PONG
```

**etcd:**

```bash
oc exec -n datalyptica-infra etcd-0 -- etcdctl endpoint health
# Should return: healthy
```

**MinIO:**

```bash
# Access console via browser using route URL
# Or test with mc CLI (if installed)
```

---

## 🎯 SUCCESS CRITERIA

Phase 1 is complete when:

- [ ] 18 pods running in `datalyptica-infra` namespace
- [ ] All PVCs in "Bound" status
- [ ] PostgreSQL cluster shows 1 Leader + 2 Replicas
- [ ] Redis shows 1 master + 2 slaves + 3 sentinels
- [ ] etcd cluster shows 3 healthy endpoints
- [ ] MinIO shows 4 servers online
- [ ] Can access MinIO console via browser
- [ ] All credentials documented
- [ ] MinIO buckets created

---

## 🆘 TROUBLESHOOTING

### General Pod Issues

**Pods Pending:**

```bash
# Check PVC binding
oc get pvc -n datalyptica-infra

# Check events
oc get events -n datalyptica-infra --sort-by='.lastTimestamp' | tail -20
```

**Pods CrashLooping:**

```bash
# Check logs
oc logs -n datalyptica-infra <pod-name>

# Check previous logs if pod restarted
oc logs -n datalyptica-infra <pod-name> --previous
```

### PostgreSQL Issues

**Cluster not forming:**

```bash
# Check operator logs
oc logs -n openshift-operators -l app.kubernetes.io/name=postgres-operator

# Check instance logs
oc logs -n datalyptica-infra <postgres-pod-name> -c database
```

**Replication not working:**

```bash
# Check replication status
POD=$(oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/role=master -o name | head -1)
oc exec -n datalyptica-infra $POD -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

### Redis Issues

**Sentinel not electing master:**

```bash
# Check sentinel logs
oc logs -n datalyptica-infra redis-sentinel-0

# Manually check sentinel status
oc exec -n datalyptica-infra redis-sentinel-0 -- \
  redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

### etcd Issues

**Cluster not forming:**

```bash
# Check logs
oc logs -n datalyptica-infra etcd-0

# Check member list
oc exec -n datalyptica-infra etcd-0 -- etcdctl member list
```

### MinIO Issues

**Tenant not starting:**

```bash
# Check operator logs
oc logs -n openshift-operators -l name=minio-operator

# Check tenant events
oc describe tenant -n datalyptica-infra datalyptica-minio
```

---

## 📝 POST-DEPLOYMENT TASKS

### Create Application Databases in PostgreSQL

```bash
# Connect to PostgreSQL
POD=$(oc get pods -n datalyptica-infra -l postgres-operator.crunchydata.com/role=master -o name | head -1)

# Create databases
oc exec -n datalyptica-infra $POD -- psql -U postgres <<EOF
CREATE DATABASE nessie;
CREATE DATABASE airflow;
CREATE DATABASE superset;
CREATE DATABASE mlflow;

CREATE USER nessie WITH ENCRYPTED PASSWORD 'nessie-password-change-me';
CREATE USER airflow WITH ENCRYPTED PASSWORD 'airflow-password-change-me';
CREATE USER superset WITH ENCRYPTED PASSWORD 'superset-password-change-me';
CREATE USER mlflow WITH ENCRYPTED PASSWORD 'mlflow-password-change-me';

GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie;
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;
EOF
```

**IMPORTANT:** Change the passwords above to secure values!

### Initialize MinIO Buckets

Via Console (recommended for beginners):

1. Access MinIO console via route
2. Go to **Buckets**
3. Click **Create Bucket**
4. Create: `lakehouse`, `warehouse`, `bronze`, `silver`, `gold`, `backups`

Via CLI (if mc client installed):

```bash
# Configure mc alias
mc alias set datalyptica \
  http://minio.datalyptica-infra.svc.cluster.local:80 \
  <access-key> <secret-key>

# Create buckets
mc mb datalyptica/lakehouse
mc mb datalyptica/warehouse
mc mb datalyptica/bronze
mc mb datalyptica/silver
mc mb datalyptica/gold
mc mb datalyptica/backups

# List buckets
mc ls datalyptica
```

---

## 📊 RESOURCE USAGE

Check resource consumption:

```bash
# Pod resource usage
oc adm top pods -n datalyptica-infra

# Node resource usage
oc adm top nodes
```

Expected consumption:

- **CPU:** 10-15 cores
- **Memory:** 40-50Gi
- **Storage:** 275Gi

---

## ➡️ NEXT STEP

Once Phase 1 is complete and all validations pass:

✅ **Proceed to:** `../02-DATA-LAYER/README.md`

---

**Status:** ☐ Completed  
**Completed On:** ******\_\_\_******  
**Deployment Time:** ******\_\_\_******

**Components Status:**

- ☐ PostgreSQL HA - 5 pods running
- ☐ Redis Sentinel - 6 pods running
- ☐ etcd Cluster - 3 pods running
- ☐ MinIO Distributed - 4 pods running

**Credentials Documented:** ☐ Yes  
**Buckets Created:** ☐ Yes  
**Application DBs Created:** ☐ Yes

**Notes:**
