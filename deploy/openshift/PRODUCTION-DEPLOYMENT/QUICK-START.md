# QUICK START GUIDE

## Deploy Datalyptica Core Platform in 3 Hours

**This is your express guide to deploying the core platform using OpenShift Web Console.**

---

## ⚡ WHAT YOU'LL DO

1. **Prerequisites** (30 min) - Install operators, create namespaces
2. **Core Infrastructure** (90 min) - Deploy PostgreSQL, Redis, etcd, MinIO
3. **Data Layer** (15 min) - Deploy Nessie
4. **Validation** (30 min) - Test everything

**Total Time: ~2.5-3 hours**

---

## 📖 BEFORE YOU START

### Required Information

Before beginning, write down these details:

**Your Storage Class Name:** ******\_\_\_******
(Find it: OpenShift Console → Storage → StorageClasses)

**Your OpenShift Console URL:** ******\_\_\_******

**Your Cluster Admin Login:** ******\_\_\_******

---

## STEP-BY-STEP DEPLOYMENT

### 🔧 PHASE 0: PREREQUISITES (30 minutes)

#### Step 1: Create Namespaces (5 min)

**Via Console:**

1. OpenShift Console → Home → Projects
2. Click "Create Project" 4 times for:
   - `datalyptica-infra`
   - `datalyptica-data`
   - `datalyptica-apps`
   - `datalyptica-monitoring`

**Via CLI:**

```bash
oc apply -f 00-PREREQUISITES/STEP-1-namespace-setup.yaml
oc get projects | grep datalyptica
```

✅ **Checkpoint:** 4 projects active

---

#### Step 2: Install Operators (20 min)

**For Each Operator:**

1. **Crunchy Postgres Operator**

   - Operators → OperatorHub
   - Search: "postgres"
   - Install "Crunchy Postgres for Kubernetes"
   - Channel: v5
   - Install mode: All namespaces
   - Namespace: openshift-operators
   - Approval: Automatic

2. **MinIO Operator**

   - Search: "minio"
   - Install "MinIO Operator"
   - Channel: stable
   - Same settings as above

3. **Strimzi Kafka Operator**
   - Search: "strimzi"
   - Install "Strimzi"
   - Channel: stable
   - Same settings as above

**Wait:** 10-15 minutes for all operators to show "Succeeded"

✅ **Checkpoint:** 3 operators succeeded

---

#### Step 3: Update Storage Class in YAML Files (5 min)

Open each file and replace `storageClassName: standard` with your storage class:

- [ ] `01-CORE-INFRASTRUCTURE/postgresql-ha.yaml` (3 places)
- [ ] `01-CORE-INFRASTRUCTURE/redis-sentinel.yaml` (1 place)
- [ ] `01-CORE-INFRASTRUCTURE/etcd-cluster.yaml` (1 place)
- [ ] `01-CORE-INFRASTRUCTURE/minio-distributed.yaml` (1 place)

**Or use CLI:**

```bash
cd 01-CORE-INFRASTRUCTURE
export SC="your-storage-class"
sed -i.bak "s/storageClassName: standard/storageClassName: $SC/g" *.yaml
```

✅ **Checkpoint:** All YAML files updated

---

### 🏗️ PHASE 1: CORE INFRASTRUCTURE (90 minutes)

#### Service 1: PostgreSQL HA (20 min)

1. **Open:** `01-CORE-INFRASTRUCTURE/postgresql-ha.yaml`
2. **Copy** all contents
3. **Console:** Operators → Installed Operators
4. **Project:** datalyptica-infra
5. **Click:** Crunchy Postgres for Kubernetes
6. **Click:** PostgresCluster tab
7. **Click:** Create PostgresCluster
8. **Switch to:** YAML view
9. **Paste** copied content
10. **Click:** Create

**Wait:** 10 minutes

**Validate:**

```bash
oc get pods -n datalyptica-infra | grep postgres
# Expect: 5+ pods Running
```

**Get Password:**

```bash
oc get secret -n datalyptica-infra datalyptica-pg-pguser-postgres \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**Password:** ******\_\_\_******

✅ **Checkpoint:** PostgreSQL running with 5 pods

---

#### Service 2: Redis Sentinel (15 min)

1. **Open:** `01-CORE-INFRASTRUCTURE/redis-sentinel.yaml`
2. **Update password** in `redis-auth` secret (line ~36)
3. **Copy** all contents
4. **Console:** Click **+** (plus icon)
5. **Project:** datalyptica-infra
6. **Paste** content
7. **Click:** Create

**Wait:** 7 minutes

**Validate:**

```bash
oc get pods -n datalyptica-infra | grep redis
# Expect: 6 pods Running (3 redis + 3 sentinel)
```

✅ **Checkpoint:** Redis running with 6 pods

---

#### Service 3: etcd Cluster (10 min)

1. **Open:** `01-CORE-INFRASTRUCTURE/etcd-cluster.yaml`
2. **Copy** all contents
3. **Console:** Click **+**
4. **Project:** datalyptica-infra
5. **Paste** content
6. **Click:** Create

**Wait:** 5 minutes

**Validate:**

```bash
oc get pods -n datalyptica-infra | grep etcd
# Expect: 3 pods Running
```

✅ **Checkpoint:** etcd running with 3 pods

---

#### Service 4: MinIO Distributed (30 min)

1. **Open:** `01-CORE-INFRASTRUCTURE/minio-distributed.yaml`
2. **Update credentials** in `datalyptica-minio-creds-secret`:
   - `accesskey:` (line ~79) - Change from "minio-admin"
   - `secretkey:` (line ~80) - Change password
3. **Copy** all contents
4. **Console:** Operators → Installed Operators
5. **Project:** datalyptica-infra
6. **Click:** MinIO Operator
7. **Click:** Tenant tab
8. **Click:** Create Tenant
9. **Switch to:** YAML view
10. **Paste** content
11. **Click:** Create

**Wait:** 15 minutes

**Validate:**

```bash
oc get pods -n datalyptica-infra | grep minio
# Expect: 4 pods Running
```

**Create Console Route:**

```bash
oc create route edge minio-console \
  --service=datalyptica-minio-console \
  --port=9090 \
  -n datalyptica-infra

# Get URL
oc get route -n datalyptica-infra minio-console -o jsonpath='{.spec.host}'
echo
```

**Console URL:** https://******\_\_\_******

**Create Buckets:**

1. Access console URL in browser
2. Login with your credentials
3. Buckets → Create Bucket → Create each:
   - `lakehouse`
   - `warehouse`
   - `bronze`
   - `silver`
   - `gold`
   - `backups`

✅ **Checkpoint:** MinIO running, console accessible, buckets created

---

#### Create PostgreSQL Databases (5 min)

```bash
# Get primary pod name
POD=$(oc get pods -n datalyptica-infra \
  -l postgres-operator.crunchydata.com/role=master \
  -o name | head -1)

# Create databases (CHANGE PASSWORDS!)
oc exec -n datalyptica-infra $POD -- psql -U postgres <<EOF
CREATE DATABASE nessie;
CREATE DATABASE airflow;
CREATE DATABASE superset;
CREATE DATABASE mlflow;

CREATE USER nessie WITH ENCRYPTED PASSWORD 'nessie-pass-123';
CREATE USER airflow WITH ENCRYPTED PASSWORD 'airflow-pass-123';
CREATE USER superset WITH ENCRYPTED PASSWORD 'superset-pass-123';
CREATE USER mlflow WITH ENCRYPTED PASSWORD 'mlflow-pass-123';

GRANT ALL PRIVILEGES ON DATABASE nessie TO nessie;
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;
EOF
```

**Record Passwords:**

- Nessie: ******\_\_\_******
- Airflow: ******\_\_\_******
- Superset: ******\_\_\_******
- MLflow: ******\_\_\_******

✅ **Checkpoint:** Phase 1 complete - 18 pods running

---

### 📊 PHASE 2: DATA LAYER (15 minutes)

#### Deploy Nessie

1. **Open:** `02-DATA-LAYER/nessie-deployment.yaml`
2. **Update password** in `nessie-postgres-secret` (line ~13)
   - Must match the password you set for `nessie` user above
3. **Copy** all contents
4. **Console:** Click **+**
5. **Project:** datalyptica-data
6. **Paste** content
7. **Click:** Create

**Wait:** 3 minutes

**Validate:**

```bash
oc get pods -n datalyptica-data
# Expect: 2 nessie pods Running
```

**Create Default Branch:**

```bash
# Port forward
oc port-forward -n datalyptica-data svc/nessie 19120:19120 &

# Create main branch
curl -X POST http://localhost:19120/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"main","type":"BRANCH"}'

# Verify
curl http://localhost:19120/api/v2/trees

# Kill port forward
kill %1
```

**Optional - Create Route:**

```bash
oc create route edge nessie-api \
  --service=nessie \
  --port=19120 \
  -n datalyptica-data
```

✅ **Checkpoint:** Phase 2 complete - 20 total pods running

---

### ✅ PHASE 3: VALIDATION (30 minutes)

#### Check All Pods

```bash
# Infrastructure (should be 18 pods)
oc get pods -n datalyptica-infra

# Data layer (should be 2 pods)
oc get pods -n datalyptica-data

# All should be Running, 1/1 or correct replica count
```

#### Check All PVCs

```bash
oc get pvc -n datalyptica-infra
oc get pvc -n datalyptica-data

# All should be Bound
```

#### Test PostgreSQL

```bash
POD=$(oc get pods -n datalyptica-infra \
  -l postgres-operator.crunchydata.com/role=master \
  -o name | head -1)

oc exec -n datalyptica-infra $POD -- \
  psql -U postgres -c "SELECT version();"

# Should return PostgreSQL 15.x
```

#### Test Redis

```bash
PASSWORD=$(oc get secret -n datalyptica-infra redis-auth \
  -o jsonpath='{.data.password}' | base64 -d)

oc exec -n datalyptica-infra redis-0 -- \
  redis-cli -a $PASSWORD PING

# Should return: PONG
```

#### Test etcd

```bash
oc exec -n datalyptica-infra etcd-0 -- \
  etcdctl endpoint health

# Should return: healthy
```

#### Test MinIO

Open MinIO console in browser:

- URL from earlier: https://******\_\_\_******
- Should be able to login and see buckets

#### Test Nessie

```bash
oc port-forward -n datalyptica-data svc/nessie 19120:19120 &
curl http://localhost:19120/api/v2/config
kill %1

# Should return JSON configuration
```

✅ **All Tests Passed!**

---

## 🎉 DEPLOYMENT COMPLETE!

### What You've Built:

| Component         | Pods   | Storage   | Status |
| ----------------- | ------ | --------- | ------ |
| PostgreSQL HA     | 5      | 45Gi      | ✅     |
| Redis Sentinel    | 6      | 15Gi      | ✅     |
| etcd Cluster      | 3      | 15Gi      | ✅     |
| MinIO Distributed | 4      | 200Gi     | ✅     |
| Nessie Catalog    | 2      | -         | ✅     |
| **TOTAL**         | **20** | **275Gi** | **✅** |

---

## 📝 IMPORTANT - SAVE THIS INFORMATION

### Connection Strings

**PostgreSQL:**

```
Primary: datalyptica-pg-pgbouncer.datalyptica-infra.svc.cluster.local:5432
User: postgres
Password: _______________
```

**Redis:**

```
Sentinel: redis-sentinel.datalyptica-infra.svc.cluster.local:26379
Master Name: mymaster
Password: _______________
```

**MinIO:**

```
API: http://minio.datalyptica-infra.svc.cluster.local:80
Console: https://_______________
Access Key: _______________
Secret Key: _______________
```

**Nessie:**

```
Internal: http://nessie.datalyptica-data.svc.cluster.local:19120/api/v2
External: https://_______________
```

---

## 🚀 NEXT STEPS

1. **Review:** `VALIDATION-CHECKLIST.md` for detailed validation
2. **Test HA:** Simulate failures to verify automatic recovery
3. **Configure Backups:** Set up backup schedules
4. **Deploy Apps:** Add Kafka, Trino, Flink, Spark, etc.
5. **Monitor:** Add Prometheus and Grafana

---

## 📚 DOCUMENTATION

- **Full Guide:** `README.md`
- **Prerequisites:** `00-PREREQUISITES/`
- **Core Infrastructure:** `01-CORE-INFRASTRUCTURE/README.md`
- **Data Layer:** `02-DATA-LAYER/README.md`
- **Validation:** `VALIDATION-CHECKLIST.md`

---

**Need Help?**

- Check logs: `oc logs -n <namespace> <pod-name>`
- Check events: `oc get events -n <namespace> --sort-by='.lastTimestamp'`
- Review troubleshooting sections in each README

**Congratulations! Your core data platform is now running! 🎊**
