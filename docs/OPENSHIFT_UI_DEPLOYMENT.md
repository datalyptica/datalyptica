# OpenShift UI Deployment Guide - Datalyptica Data Platform

## 📋 Overview

This guide walks you through deploying the Datalyptica Data Platform using the OpenShift Web Console UI.

**Estimated Time**: 4-6 hours (including validation)

---

## 🎯 Prerequisites

### 1. OpenShift Access

- [ ] OpenShift cluster access (4.10+)
- [ ] Cluster admin or project admin permissions
- [ ] Access to OpenShift Web Console

### 2. Resource Requirements

**Minimum per namespace:**

- CPU: 10 cores
- Memory: 32Gi
- Storage: 200Gi

**Recommended:**

- CPU: 20 cores
- Memory: 64Gi
- Storage: 500Gi

### 3. Storage Class

- [ ] Identify available storage class:
  ```
  Administrator → Storage → StorageClasses
  ```
- [ ] Note the name (e.g., `ocs-storagecluster-ceph-rbd`, `gp3`, `thin`)

### 4. Container Images

**Option A: Use Public Images (Easiest)**

- Images will be pulled from Docker Hub
- No additional setup required

**Option B: Push to OpenShift Internal Registry**

- See "Image Registry Setup" section below

---

## 📦 Pre-Deployment Setup

### Step 1: Create Projects (Namespaces)

**Via UI:**

1. **Administrator** → **Home** → **Projects**
2. Click **Create Project**
3. Create three projects:

   - Name: `datalyptica-core`
   - Display Name: `Datalyptica Core Services`
   - Description: `Core infrastructure (PostgreSQL, Redis, MinIO, Nessie)`

4. Repeat for:
   - `datalyptica-apps` (Application services)
   - `datalyptica-monitoring` (Optional - Prometheus, Grafana)

### Step 2: Create Service Accounts

**For datalyptica-core:**

1. Navigate to **Administrator** → **User Management** → **ServiceAccounts**
2. Select project: `datalyptica-core`
3. Click **Create ServiceAccount**
4. Paste:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: datalyptica-sa
  namespace: datalyptica-core
```

**Repeat for datalyptica-apps:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: datalyptica-sa
  namespace: datalyptica-apps
```

### Step 3: Create Secrets

**Navigate to:** Workloads → Secrets → Create → Key/Value Secret

#### PostgreSQL Credentials (datalyptica-core)

- **Secret Name**: `postgresql-credentials`
- **Key/Value Pairs**:
  ```
  postgres-password: <generate-strong-password>
  nessie-password: <generate-strong-password>
  airflow-password: <generate-strong-password>
  superset-password: <generate-strong-password>
  mlflow-password: <generate-strong-password>
  ```

#### Redis Credentials (datalyptica-core)

- **Secret Name**: `redis-credentials`
- **Key/Value Pairs**:
  ```
  password: <generate-strong-password>
  ```

#### MinIO Credentials (datalyptica-core)

- **Secret Name**: `minio-credentials`
- **Key/Value Pairs**:
  ```
  root-user: minioadmin
  root-password: <generate-strong-password>
  access-key: <generate-access-key>
  secret-key: <generate-secret-key>
  ```

#### ClickHouse Credentials (datalyptica-apps)

- **Secret Name**: `clickhouse-credentials`
- **Key/Value Pairs**:
  ```
  password: <generate-strong-password>
  ```

#### Airflow Credentials (datalyptica-apps)

- **Secret Name**: `airflow-credentials`
- **Key/Value Pairs**:
  ```
  secret-key: <generate-fernet-key-32-chars>
  ```

#### Superset Credentials (datalyptica-apps)

- **Secret Name**: `superset-credentials`
- **Key/Value Pairs**:
  ```
  secret-key: <generate-strong-password>
  admin-password: <generate-strong-password>
  ```

**💡 Tip:** Use a password generator for all secrets (minimum 16 characters)

---

## 🚀 Deployment Phase 1: Core Services

### 1.1 Deploy PostgreSQL

**Path:** Administrator → Workloads → StatefulSets → Create StatefulSet

**File to use:** `deploy/openshift/core/01-postgresql.yaml` (see below)

**Key modifications in UI:**

1. Change `storageClassName: standard` → your storage class
2. Update `image: datalyptica/postgresql:latest` if using internal registry
3. Verify security context is preserved

**Validation:**

```bash
oc get pods -n datalyptica-core -l app=postgresql
oc logs -n datalyptica-core postgresql-0
```

**Wait for:** Pod status = Running, Ready 1/1

---

### 1.2 Deploy Redis

**Path:** Administrator → Workloads → StatefulSets → Create StatefulSet

**File to use:** `deploy/openshift/core/02-redis.yaml`

**Validation:**

```bash
oc get pods -n datalyptica-core -l app=redis
oc exec -n datalyptica-core redis-0 -- redis-cli -a $(oc get secret redis-credentials -o jsonpath='{.data.password}' | base64 -d) ping
```

**Expected:** PONG

---

### 1.3 Deploy MinIO

**Path:** Administrator → Workloads → StatefulSets → Create StatefulSet

**File to use:** `deploy/openshift/core/03-minio.yaml`

**After deployment, create Route:**

1. **Networking** → **Routes** → **Create Route**
2. **Name**: `minio-console`
3. **Service**: `minio`
4. **Target Port**: `9001 → 9001`
5. **TLS**: Edge termination
6. Click **Create**

**Validation:**

- Access MinIO Console: `https://minio-console-datalyptica-core.apps.<cluster-domain>`
- Login with credentials from secret

---

### 1.4 Deploy Nessie

**Path:** Administrator → Workloads → Deployments → Create Deployment

**File to use:** `deploy/openshift/core/04-nessie.yaml`

**Create Route:**

1. **Name**: `nessie-api`
2. **Service**: `nessie`
3. **Target Port**: `19120 → 19120`
4. **TLS**: Edge termination

**Validation:**

```bash
curl https://nessie-api-datalyptica-core.apps.<cluster-domain>/api/v2/config
```

---

## 🚀 Deployment Phase 2: Application Services

### 2.1 Deploy Kafka

**Path:** Administrator → Workloads → StatefulSets → Create StatefulSet

**File to use:** `deploy/openshift/apps/01-kafka.yaml`

**Note:** This includes both Kafka and Schema Registry

**Validation:**

```bash
oc get pods -n datalyptica-apps -l app=kafka
oc get pods -n datalyptica-apps -l app=schema-registry
oc logs -n datalyptica-apps kafka-0
```

---

### 2.2 Deploy Trino

**Path:** Administrator → Workloads → Deployments → Create Deployment

**File to use:** `deploy/openshift/apps/02-trino.yaml`

**Note:** This includes both Coordinator and Workers

**Create Route for UI:**

1. **Name**: `trino-ui`
2. **Service**: `trino-coordinator`
3. **Target Port**: `8080 → 8080`
4. **TLS**: Edge termination

**Validation:**

- Access UI: `https://trino-ui-datalyptica-apps.apps.<cluster-domain>`

---

### 2.3 Deploy Flink

**Path:** Administrator → Workloads → Deployments → Create Deployment

**File to use:** `deploy/openshift/apps/03-flink.yaml`

**Create Route for JobManager UI:**

1. **Name**: `flink-ui`
2. **Service**: `flink-jobmanager`
3. **Target Port**: `8081 → 8081`

---

### 2.4 Deploy Spark

**Path:** Administrator → Workloads → Deployments → Create Deployment

**File to use:** `deploy/openshift/apps/04-spark.yaml`

**Create Route for Spark UI:**

1. **Name**: `spark-ui`
2. **Service**: `spark-master`
3. **Target Port**: `4040 → 4040`

---

### 2.5 Deploy ClickHouse

**Path:** Administrator → Workloads → StatefulSets → Create StatefulSet

**File to use:** `deploy/openshift/apps/05-clickhouse.yaml`

**Validation:**

```bash
oc exec -n datalyptica-apps clickhouse-0 -- clickhouse-client --password=$(oc get secret clickhouse-credentials -o jsonpath='{.data.password}' | base64 -d) --query "SELECT version()"
```

---

### 2.6 Deploy Airflow

**Path:** Administrator → Workloads → Deployments → Create Deployment

**File to use:** `deploy/openshift/apps/06-airflow.yaml`

**Note:** This includes Webserver, Scheduler, and Worker

**Create Route for Airflow UI:**

1. **Name**: `airflow-ui`
2. **Service**: `airflow-webserver`
3. **Target Port**: `8082 → 8082`

**Default credentials:** admin / admin

---

### 2.7 Deploy Superset

**Path:** Administrator → Workloads → Deployments → Create Deployment

**File to use:** `deploy/openshift/apps/07-superset.yaml`

**Create Route for Superset UI:**

1. **Name**: `superset-ui`
2. **Service**: `superset`
3. **Target Port**: `8088 → 8088`

**Default credentials:** admin / <admin-password-from-secret>

---

## 📊 Post-Deployment Configuration

### Initialize MinIO Buckets

```bash
oc exec -n datalyptica-core minio-0 -- sh -c '
mc alias set local http://localhost:9000 minioadmin $(cat /run/secrets/minio-credentials/root-password)
mc mb local/lakehouse
mc mb local/warehouse
mc mb local/bronze
mc mb local/silver
mc mb local/gold
'
```

### Initialize Nessie Default Branch

```bash
curl -X POST https://nessie-api-datalyptica-core.apps.<cluster-domain>/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"main","type":"BRANCH"}'
```

### Verify Airflow Database

```bash
oc exec -n datalyptica-apps <airflow-webserver-pod> -- airflow db check
```

---

## 🔍 Validation & Testing

### Check All Pods Running

```bash
# Core services
oc get pods -n datalyptica-core

# Expected output:
# postgresql-0     1/1  Running
# redis-0          1/1  Running
# minio-0          1/1  Running
# nessie-xxx       1/1  Running

# App services
oc get pods -n datalyptica-apps

# Expected: All pods Running with 1/1 or 2/2 ready
```

### Check Services

```bash
oc get svc -n datalyptica-core
oc get svc -n datalyptica-apps
```

### Check Routes

```bash
oc get routes -n datalyptica-core
oc get routes -n datalyptica-apps
```

### Test Service Connectivity

**From within cluster:**

```bash
# Test PostgreSQL
oc run test-pg --image=postgres:15 --rm -it --restart=Never -- \
  psql -h postgresql.datalyptica-core.svc.cluster.local -U postgres -c "SELECT version();"

# Test Redis
oc run test-redis --image=redis:7 --rm -it --restart=Never -- \
  redis-cli -h redis.datalyptica-core.svc.cluster.local PING
```

---

## 🛠️ Troubleshooting

### Pod Not Starting

**Check Events:**

```bash
oc describe pod <pod-name> -n <namespace>
```

**Common Issues:**

- **ImagePullBackOff**: Image not accessible
  - Solution: Use public images or push to internal registry
- **CrashLoopBackOff**: Application error
  - Solution: Check logs with `oc logs <pod-name>`
- **Pending**: Storage not bound
  - Solution: Check PVC status, verify storage class

### Storage Issues

**Check PVCs:**

```bash
oc get pvc -n datalyptica-core
oc get pvc -n datalyptica-apps
```

**If stuck Pending:**

1. Check storage class exists
2. Verify quota not exceeded
3. Check node storage capacity

### Security Context Issues

**SCC Violations:**

```bash
oc get pod <pod-name> -o yaml | grep scc
```

**If restricted SCC causing issues:**

```bash
# Grant anyuid SCC (if allowed by cluster admin)
oc adm policy add-scc-to-user anyuid -z datalyptica-sa -n datalyptica-core
```

### Network Connectivity Issues

**Test DNS resolution:**

```bash
oc run test-dns --image=busybox --rm -it --restart=Never -- \
  nslookup postgresql.datalyptica-core.svc.cluster.local
```

---

## 📈 Monitoring

### Resource Usage

**Via UI:**

- **Administrator** → **Observe** → **Dashboards**
- Select project: `datalyptica-core` or `datalyptica-apps`
- View CPU, Memory, Network metrics

**Via CLI:**

```bash
oc adm top pods -n datalyptica-core
oc adm top pods -n datalyptica-apps
```

### Logs

**Via UI:**

- **Administrator** → **Workloads** → **Pods**
- Click pod → **Logs** tab

**Via CLI:**

```bash
oc logs -f <pod-name> -n <namespace>
```

---

## 🔐 Security Best Practices

1. **Use strong passwords** for all secrets (16+ characters)
2. **Enable TLS** on all Routes
3. **Regular updates** of container images
4. **Network Policies** to restrict inter-pod communication (optional)
5. **RBAC** - grant minimum required permissions
6. **Secret rotation** - rotate passwords quarterly

---

## 📝 Deployment Checklist

### Pre-Deployment

- [ ] OpenShift cluster access verified
- [ ] Storage class identified
- [ ] Resource quotas checked
- [ ] Projects created (core, apps, monitoring)
- [ ] Service accounts created
- [ ] All secrets created

### Core Services

- [ ] PostgreSQL deployed and running
- [ ] Redis deployed and running
- [ ] MinIO deployed and running
- [ ] MinIO buckets initialized
- [ ] Nessie deployed and running
- [ ] Nessie default branch created

### Application Services

- [ ] Kafka deployed and running
- [ ] Trino deployed and running
- [ ] Flink deployed and running
- [ ] Spark deployed and running
- [ ] ClickHouse deployed and running
- [ ] Airflow deployed and running
- [ ] Superset deployed and running

### Post-Deployment

- [ ] All pods running
- [ ] All services accessible
- [ ] Routes created for UIs
- [ ] Service connectivity tested
- [ ] Monitoring configured
- [ ] Backup strategy planned

---

## 🆘 Support Resources

- **OpenShift Documentation**: https://docs.openshift.com/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Datalyptica Issues**: https://github.com/datalyptica/datalyptica/issues

---

**Deployment Guide Version**: 1.0  
**Last Updated**: December 3, 2025  
**Maintained By**: Datalyptica Team
