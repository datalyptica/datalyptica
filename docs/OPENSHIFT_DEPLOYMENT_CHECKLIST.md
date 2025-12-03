# OpenShift Deployment Checklist

Use this checklist to track your deployment progress.

## ✅ Pre-Deployment (30 minutes)

### OpenShift Access

- [ ] Have OpenShift cluster access (4.10+)
- [ ] Can access Web Console
- [ ] Have project admin or cluster admin role
- [ ] Verified cluster has sufficient resources:
  - [ ] CPU: 20+ cores available
  - [ ] Memory: 64Gi+ available
  - [ ] Storage: 200Gi+ available

### Storage Configuration

- [ ] Identified storage class name: `____________________`
- [ ] Updated storage class in ALL YAML files:
  - [ ] `deploy/openshift/core/01-postgresql.yaml`
  - [ ] `deploy/openshift/core/02-redis.yaml`
  - [ ] `deploy/openshift/core/03-minio.yaml`
  - [ ] `deploy/openshift/apps/01-kafka.yaml`
  - [ ] Other app service files

### Projects (Namespaces)

- [ ] Created project: `datalyptica-core`
- [ ] Created project: `datalyptica-apps`
- [ ] Created project: `datalyptica-monitoring` (optional)

### Service Accounts

- [ ] Created ServiceAccount `datalyptica-sa` in `datalyptica-core`
- [ ] Created ServiceAccount `datalyptica-sa` in `datalyptica-apps`

### Secrets Created in `datalyptica-core`

- [ ] Secret: `postgresql-credentials`
  - [ ] Key: `postgres-password`
  - [ ] Key: `nessie-password`
  - [ ] Key: `airflow-password`
  - [ ] Key: `superset-password`
  - [ ] Key: `mlflow-password`
- [ ] Secret: `redis-credentials`
  - [ ] Key: `password`
- [ ] Secret: `minio-credentials`
  - [ ] Key: `root-user`
  - [ ] Key: `root-password`
  - [ ] Key: `access-key`
  - [ ] Key: `secret-key`

### Secrets Created in `datalyptica-apps`

- [ ] Secret: `clickhouse-credentials`
  - [ ] Key: `password`
- [ ] Secret: `airflow-credentials`
  - [ ] Key: `secret-key` (32 character Fernet key)
- [ ] Secret: `superset-credentials`
  - [ ] Key: `secret-key`
  - [ ] Key: `admin-password`

---

## ✅ Core Services Deployment (30 minutes)

### PostgreSQL

- [ ] Deployed: `deploy/openshift/core/01-postgresql.yaml`
- [ ] Pod status: Running (1/1)
- [ ] PVC status: Bound
- [ ] Logs checked: No errors
- [ ] Connection tested: ✓

**Verification:**

```bash
oc get pods -n datalyptica-core -l app=postgresql
oc exec -it postgresql-0 -n datalyptica-core -- psql -U postgres -c "SELECT version();"
```

### Redis

- [ ] Deployed: `deploy/openshift/core/02-redis.yaml`
- [ ] Pod status: Running (1/1)
- [ ] PVC status: Bound
- [ ] Logs checked: No errors
- [ ] Connection tested: ✓

**Verification:**

```bash
oc get pods -n datalyptica-core -l app=redis
# Test PING
```

### MinIO

- [ ] Deployed: `deploy/openshift/core/03-minio.yaml`
- [ ] Pod status: Running (1/1)
- [ ] PVC status: Bound
- [ ] Route created for console (port 9001)
- [ ] Route URL: `https://_______________________`
- [ ] Console accessible: ✓
- [ ] Logged in with credentials: ✓
- [ ] Buckets created: ✓
  - [ ] `lakehouse`
  - [ ] `warehouse`
  - [ ] `bronze`
  - [ ] `silver`
  - [ ] `gold`

**Create Route:**

```bash
oc create route edge minio-console --service=minio --port=9001 -n datalyptica-core
```

### Nessie

- [ ] Deployed: `deploy/openshift/core/04-nessie.yaml`
- [ ] Pod status: Running (1/1)
- [ ] Logs checked: Connected to PostgreSQL ✓
- [ ] Route created for API (port 19120)
- [ ] Route URL: `https://_______________________`
- [ ] API accessible: ✓
- [ ] Default branch `main` created: ✓

**Create Route:**

```bash
oc create route edge nessie-api --service=nessie --port=19120 -n datalyptica-core
```

**Initialize:**

```bash
curl -X POST https://<nessie-route>/api/v2/trees -H "Content-Type: application/json" -d '{"name":"main","type":"BRANCH"}'
```

---

## ✅ Application Services Deployment (90 minutes)

### Kafka + Schema Registry

- [ ] Deployed: `deploy/openshift/apps/01-kafka.yaml`
- [ ] Kafka pod status: Running (1/1)
- [ ] Schema Registry pod status: Running (1/1)
- [ ] Kafka PVC status: Bound
- [ ] Logs checked: No errors
- [ ] Brokers healthy: ✓

**Verification:**

```bash
oc get pods -n datalyptica-apps -l app=kafka
oc get pods -n datalyptica-apps -l app=schema-registry
oc logs -f kafka-0 -n datalyptica-apps
```

### Trino

- [ ] Deployed: `deploy/openshift/apps/02-trino.yaml` (or via UI)
- [ ] Coordinator pod status: Running (1/1)
- [ ] Worker pods status: Running (2/2)
- [ ] Route created for UI (port 8080)
- [ ] Route URL: `https://_______________________`
- [ ] UI accessible: ✓
- [ ] Catalogs loaded: ✓

**Create Route:**

```bash
oc create route edge trino-ui --service=trino-coordinator --port=8080 -n datalyptica-apps
```

### Flink

- [ ] Deployed: `deploy/openshift/apps/03-flink.yaml` (or via UI)
- [ ] JobManager pod status: Running (1/1)
- [ ] TaskManager pods status: Running (2/2)
- [ ] Route created for UI (port 8081)
- [ ] Route URL: `https://_______________________`
- [ ] UI accessible: ✓

**Create Route:**

```bash
oc create route edge flink-ui --service=flink-jobmanager --port=8081 -n datalyptica-apps
```

### Spark

- [ ] Deployed: `deploy/openshift/apps/04-spark.yaml` (or via UI)
- [ ] Master pod status: Running (1/1)
- [ ] Worker pods status: Running (2/2)
- [ ] Route created for UI (port 4040)
- [ ] Route URL: `https://_______________________`
- [ ] UI accessible: ✓
- [ ] Workers registered: ✓

**Create Route:**

```bash
oc create route edge spark-ui --service=spark-master --port=4040 -n datalyptica-apps
```

### ClickHouse

- [ ] Deployed: `deploy/openshift/apps/05-clickhouse.yaml` (or via UI)
- [ ] Pod status: Running (1/1)
- [ ] PVC status: Bound
- [ ] Logs checked: No errors
- [ ] Connection tested: ✓

**Verification:**

```bash
oc get pods -n datalyptica-apps -l app=clickhouse
oc exec -it clickhouse-0 -n datalyptica-apps -- clickhouse-client --query "SELECT version()"
```

### Airflow

- [ ] Deployed: `deploy/openshift/apps/06-airflow.yaml` (or via UI)
- [ ] Webserver pod status: Running (1/1)
- [ ] Scheduler pod status: Running (1/1)
- [ ] Worker pods status: Running (2/2)
- [ ] Route created for UI (port 8082)
- [ ] Route URL: `https://_______________________`
- [ ] UI accessible: ✓
- [ ] Logged in (admin/admin): ✓
- [ ] Database initialized: ✓
- [ ] Celery workers active: ✓

**Create Route:**

```bash
oc create route edge airflow-ui --service=airflow-webserver --port=8082 -n datalyptica-apps
```

### Superset

- [ ] Deployed: `deploy/openshift/apps/07-superset.yaml` (or via UI)
- [ ] Pod status: Running (1/1)
- [ ] Route created for UI (port 8088)
- [ ] Route URL: `https://_______________________`
- [ ] UI accessible: ✓
- [ ] Logged in (admin/<password>): ✓
- [ ] Database initialized: ✓

**Create Route:**

```bash
oc create route edge superset-ui --service=superset --port=8088 -n datalyptica-apps
```

---

## ✅ Post-Deployment Validation (30 minutes)

### All Pods Running

```bash
oc get pods -n datalyptica-core
oc get pods -n datalyptica-apps
```

- [ ] All pods in `Running` state
- [ ] All pods show `1/1` or correct replica count
- [ ] No `CrashLoopBackOff` or `ImagePullBackOff` errors

### All Services Created

```bash
oc get svc -n datalyptica-core
oc get svc -n datalyptica-apps
```

- [ ] All services have ClusterIP assigned
- [ ] Endpoints populated for all services

### All Routes Created

```bash
oc get routes -n datalyptica-core
oc get routes -n datalyptica-apps
```

- [ ] All UI routes created
- [ ] All routes show HOST/PORT
- [ ] TLS edge termination enabled

### All PVCs Bound

```bash
oc get pvc -n datalyptica-core
oc get pvc -n datalyptica-apps
```

- [ ] All PVCs in `Bound` state
- [ ] Storage class matches expected class
- [ ] Capacity matches requested size

### Service Connectivity

- [ ] PostgreSQL accessible from Nessie: ✓
- [ ] Redis accessible from Airflow: ✓
- [ ] MinIO accessible from Spark: ✓
- [ ] Kafka accessible from applications: ✓

### Resource Usage

```bash
oc adm top pods -n datalyptica-core
oc adm top pods -n datalyptica-apps
```

- [ ] No pods exceeding memory limits
- [ ] CPU usage reasonable
- [ ] No OOMKilled pods

---

## ✅ Post-Deployment Configuration (30 minutes)

### Superset Data Sources

- [ ] Added PostgreSQL connection
- [ ] Added Trino connection
- [ ] Added ClickHouse connection
- [ ] Tested all connections: ✓

### Airflow Configuration

- [ ] Created sample DAG
- [ ] Verified scheduler is picking up DAGs
- [ ] Tested task execution
- [ ] Verified Celery worker execution

### Trino Catalogs

- [ ] Nessie catalog accessible
- [ ] MinIO S3 accessible from Trino
- [ ] Can query data via Trino UI

---

## ✅ Monitoring & Observability (Optional)

### Prometheus (if deployed)

- [ ] Deployed Prometheus
- [ ] ServiceMonitors configured
- [ ] Metrics being collected
- [ ] Route created for UI

### Grafana (if deployed)

- [ ] Deployed Grafana
- [ ] Connected to Prometheus
- [ ] Imported dashboards
- [ ] Route created for UI

### Logs

- [ ] Know how to access pod logs via UI
- [ ] Know how to access pod logs via CLI
- [ ] Understand log retention policy

---

## ✅ Documentation & Handoff

### Credentials Documented

- [ ] PostgreSQL admin password saved
- [ ] MinIO credentials saved
- [ ] Redis password saved
- [ ] ClickHouse password saved
- [ ] Airflow admin credentials saved
- [ ] Superset admin credentials saved

### Routes Documented

- [ ] MinIO Console URL: `___________________________`
- [ ] Nessie API URL: `___________________________`
- [ ] Trino UI URL: `___________________________`
- [ ] Flink UI URL: `___________________________`
- [ ] Spark UI URL: `___________________________`
- [ ] Airflow UI URL: `___________________________`
- [ ] Superset UI URL: `___________________________`

### Runbook Created

- [ ] Deployment procedure documented
- [ ] Common issues and solutions documented
- [ ] Contact information for support
- [ ] Escalation procedure defined

---

## 📊 Deployment Summary

**Deployment Date:** ********\_\_\_********

**Deployed By:** ********\_\_\_********

**OpenShift Cluster:** ********\_\_\_********

**Storage Class Used:** ********\_\_\_********

**Total Pods:** **\_** / **\_**

**Total Services:** **\_** / **\_**

**Total Routes:** **\_** / **\_**

**Total Storage Used:** **\_** GB

**Deployment Time:** **\_** hours

**Issues Encountered:**

-
-
-

**Notes:**
