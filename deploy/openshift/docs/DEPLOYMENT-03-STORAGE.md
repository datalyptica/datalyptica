# Datalyptica OpenShift Deployment - Storage Layer

**Date**: December 5, 2025  
**Cluster**: virocp-poc.efinance.com.eg  
**Project**: datalyptica  
**Previous Step**: [Operator Installation](DEPLOYMENT-02-OPERATORS.md)

---

## ✅ Deployment Status

| Component | Status | Type | Replicas | Storage | Details |
|-----------|--------|------|----------|---------|---------|  
| **MinIO** | ✅ Deployed | StatefulSet | 4/4 Running | 4×200Gi (800Gi) | HA Distributed Mode, EC:2 |
| **PostgreSQL** | ✅ Deployed | CrunchyData PostgresCluster | 3/3 Running (4/4 containers) | 3×200Gi | PG 16, Auto-init 6 databases, Streaming replication |
| **Redis** | ✅ Deployed | StatefulSet | 3/3 Running (2/2 each) | 3×50Gi | Sentinel HA, quorum=2, AOF enabled |**Current Console Access:**
- MinIO: `https://minio-console-datalyptica.apps.virocp-poc.efinance.com.eg`

---

## Table of Contents

1. [Overview](#overview)
2. [Storage Architecture](#storage-architecture)
3. [MinIO Object Storage](#minio-object-storage)
4. [PostgreSQL Database](#postgresql-database)
5. [Redis Cache](#redis-cache)
6. [Validation](#validation)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

---

## Overview

The storage layer provides the foundational data persistence services for the Datalyptica platform:

- **MinIO**: S3-compatible object storage for data lakehouse (Iceberg tables)
- **PostgreSQL**: Relational database for catalog metadata (Nessie, Airflow, etc.)
- **Redis**: In-memory cache and message broker

### Storage Class

All persistent volumes use: **9500-storageclass** (IBM Block Storage CSI)

---

## Storage Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       Storage Layer                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────┐ │
│  │     MinIO      │  │   PostgreSQL    │  │      Redis       │ │
│  │                │  │                 │  │                  │ │
│  │  Object Store  │  │ CrunchyData PG  │  │  Cache & Broker  │ │
│  │  (S3-compat)   │  │   3 instances   │  │                  │ │
│  │  Distributed   │  │  PostgreSQL 16  │  │  3 replicas +    │ │
│  │  4 replicas    │  │                 │  │  3 sentinels     │ │
│  │  EC:2 mode     │  │  Auto-created:  │  │  (6 containers)  │ │
│  │                │  │  6 databases    │  │                  │ │
│  │  Buckets:      │  │  6 users        │  │  Databases:      │ │
│  │  - lakehouse   │  │  6 secrets      │  │  - nessie        │ │
│  │  - warehouse   │  │                 │  │  - airflow       │ │
│  │  - staging     │  │  Databases:     │  │  - sessions      │ │
│  │  - archive     │  │  - nessie       │  │                  │ │
│  │  - mlflow      │  │  - keycloak     │  │  AOF enabled     │ │
│  │  - backups     │  │  - airflow      │  │  Quorum: 2       │ │
│  │                │  │  - superset     │  │                  │ │
│  │  4×200Gi PVCs  │  │  - jupyterhub   │  │  3×50Gi PVCs     │ │
│  │  (800Gi total) │  │  - mlflow       │  │  (150Gi total)   │ │
│  │                │  │                 │  │                  │ │
│  └────────────────┘  │  3×200Gi PVCs   │  └──────────────────┘ │
│                      │  (600Gi total)  │                       │
│                      │                 │                       │
│                      └─────────────────┘                       │
│                                                                  │
│  Storage Class: 9500-storageclass (IBM Block Storage CSI)       │
│  Total Allocated: 1550Gi (800+600+150)                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## MinIO Object Storage

### Purpose

MinIO provides S3-compatible object storage for:
- Iceberg table data files (Parquet, ORC, Avro)
- Data lakehouse storage
- Backup archives
- Temporary staging data

### High Availability Configuration

**Architecture**: Distributed Mode (4 replicas)  
**Erasure Coding**: EC:2 (tolerates 2 node failures)  
**Total Capacity**: 800Gi (4 × 200Gi)  
**File**: `deploy/openshift/storage/minio-deployment.yaml`

```yaml
---
# MinIO Headless Service for StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: minio-headless
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
    datalyptica.io/component: minio
spec:
  clusterIP: None
  publishNotReadyAddresses: true
  ports:
  - name: api
    port: 9000
    protocol: TCP
    targetPort: 9000
  selector:
    app.kubernetes.io/name: minio
---
# MinIO StatefulSet (HA Distributed Mode)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
    datalyptica.io/component: minio
spec:
  serviceName: minio-headless
  replicas: 4
  selector:
    matchLabels:
      app.kubernetes.io/name: minio
  template:
    metadata:
      labels:
        app.kubernetes.io/name: minio
        app.kubernetes.io/part-of: datalyptica
        datalyptica.io/tier: storage
        datalyptica.io/component: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args:
        - server
        - http://minio-{0...3}.minio-headless.datalyptica.svc.cluster.local/data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "admin"
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: root-password
        ports:
        - containerPort: 9000
          name: api
          protocol: TCP
        - containerPort: 9001
          name: console
          protocol: TCP
        volumeMounts:
        - name: data
          mountPath: /data
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 15
          periodSeconds: 10
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app.kubernetes.io/name: minio
        datalyptica.io/tier: storage
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 200Gi
      storageClassName: 9500-storageclass
---
# MinIO Service (API)
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
    datalyptica.io/component: minio
spec:
  type: ClusterIP
  ports:
  - port: 9000
    targetPort: 9000
    protocol: TCP
    name: api
  selector:
    app.kubernetes.io/name: minio
---
# MinIO Service (Console)
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
    datalyptica.io/component: minio
spec:
  type: ClusterIP
  ports:
  - port: 9001
    targetPort: 9001
    protocol: TCP
    name: console
  selector:
    app.kubernetes.io/name: minio
---
# MinIO Route (Console UI)
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-console
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
    datalyptica.io/component: minio
spec:
  to:
    kind: Service
    name: minio-console
  port:
    targetPort: console
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

### Deployment Commands

```bash
# 1. Deploy MinIO HA StatefulSet
oc apply -f deploy/openshift/storage/minio-deployment.yaml

# 2. Wait for all replicas (takes 3-5 minutes)
oc wait --for=jsonpath='{.status.readyReplicas}'=4 statefulset/minio -n datalyptica --timeout=600s

# 3. Verify all pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=minio

# Expected output:
# NAME      READY   STATUS    RESTARTS   AGE
# minio-0   1/1     Running   0          5m
# minio-1   1/1     Running   0          4m
# minio-2   1/1     Running   0          3m
# minio-3   1/1     Running   0          2m

# 4. Initialize buckets automatically
oc apply -f deploy/openshift/storage/minio-init-job.yaml

# 5. Wait for bucket creation job to complete
oc wait --for=condition=complete job/minio-init-buckets -n datalyptica --timeout=120s

# 6. View bucket creation logs
oc logs job/minio-init-buckets -n datalyptica

# Expected output shows:
# ✓ Bucket 'datalyptica' created (general platform data)
# ✓ Bucket 'lakehouse' created (Iceberg table data)
# ✓ Bucket 'warehouse' created (Nessie warehouse location)
# ✓ Bucket 'mlflow' created (MLflow artifacts)
# ✓ Bucket 'airflow' created (Airflow logs and XComs)
# ✓ Policy set for 'lakehouse' (public download)
# ✓ Policy set for 'warehouse' (public download)

# 7. Verify PVCs created
oc get pvc -n datalyptica | grep minio

# Expected output (4 PVCs, 200Gi each):
# data-minio-0   Bound    pvc-xxx   200Gi   RWO   9500-storageclass
# data-minio-1   Bound    pvc-xxx   200Gi   RWO   9500-storageclass
# data-minio-2   Bound    pvc-xxx   200Gi   RWO   9500-storageclass
# data-minio-3   Bound    pvc-xxx   200Gi   RWO   9500-storageclass

# 8. Get MinIO console URL
oc get route minio-console -n datalyptica -o jsonpath='{.spec.host}'

# Login credentials: minio / <password-from-minio-credentials-secret>
```

### Automatic Bucket Initialization

The MinIO deployment includes an automatic bucket initialization job that:
- **Waits for MinIO cluster to be ready** (up to 5 minutes)
- **Creates 5 required buckets**:
  - `datalyptica` - General platform data and backups
  - `lakehouse` - Apache Iceberg table data files
  - `warehouse` - Nessie catalog warehouse location
  - `mlflow` - MLflow experiment artifacts and models
  - `airflow` - Airflow DAG logs and XCom data
- **Sets bucket policies**: Public download access for `lakehouse` and `warehouse`
- **Idempotent**: Can be re-run safely, skips existing buckets

**Job Details:**
- **File**: `deploy/openshift/storage/minio-init-job.yaml`
- **Image**: `quay.io/minio/mc:latest` (MinIO Client)
- **TTL**: Auto-deletes 5 minutes after completion
- **Retry Policy**: Up to 5 retries on failure
```

### High Availability Features

The MinIO deployment provides the following HA capabilities:

| Feature | Configuration | Benefit |
|---------|--------------|---------|
| **Distributed Mode** | 4-node cluster | No single point of failure |
| **Erasure Coding** | EC:2 (N/2 parity) | Survives 2 simultaneous node failures |
| **Automatic Failover** | Built-in health checks | Seamless recovery from node failures |
| **Data Redundancy** | Replicated across nodes | Data protection and availability |
| **Load Balancing** | Round-robin across pods | Distributed request handling |
| **Persistent Storage** | 4 × 200Gi PVCs | Independent storage per node |
| **Total Capacity** | 800Gi raw (400Gi usable) | With EC:2, ~50% storage efficiency |

**Failure Scenarios:**

- **1 pod down**: Cluster remains fully operational, automatic recovery
- **2 pods down**: Cluster still operational with degraded performance
- **3 pods down**: Cluster enters read-only mode, writes blocked
- **4 pods down**: Complete outage (requires manual intervention)

**Recovery Time:**
- Pod restart: ~30 seconds
- PVC reattachment: ~1-2 minutes
- Full cluster resync: Automatic, depends on data size

### Verification

```bash
# 1. Check StatefulSet status
oc get statefulset minio -n datalyptica

# Expected: READY 4/4

# 2. Check all MinIO pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=minio

# Expected: All 4 pods showing 1/1 Running

# 3. Check all PVCs are bound
oc get pvc -n datalyptica | grep data-minio

# Expected: All 4 PVCs (200Gi each) showing Bound status

# 4. Verify bucket initialization job completed
oc get job minio-init-buckets -n datalyptica

# Expected: STATUS = Complete, COMPLETIONS = 1/1

# 5. List buckets to verify creation
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc ls local'

# Expected output:
# [2025-12-05 17:37:00 UTC]     0B airflow/
# [2025-12-05 17:36:59 UTC]     0B datalyptica/
# [2025-12-05 17:37:00 UTC]     0B lakehouse/
# [2025-12-05 17:37:00 UTC]     0B mlflow/
# [2025-12-05 17:37:00 UTC]     0B warehouse/

# 6. Verify distributed mode in logs
oc logs minio-0 -n datalyptica --tail=30 | grep -i "distributed"

# Should see: Distributed mode endpoints listed

# 7. Test MinIO API health
oc exec minio-0 -n datalyptica -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/minio/health/live

# Expected: 200

# 8. Access MinIO Console
echo "https://$(oc get route minio-console -n datalyptica -o jsonpath='{.spec.host}')"

# Login credentials:
# Username: minio
# Password: Get from secret: oc get secret minio-credentials -n datalyptica -o jsonpath='{.data.root-password}' | base64 -d

# 9. Verify bucket policies (lakehouse and warehouse should allow public download)
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc anonymous get local/lakehouse'

# Expected: Access permission for `local/lakehouse` is `download`

# 10. Check MinIO cluster status
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc admin info local'

# Expected: Shows 4 servers online, uptime, and storage stats
```

---

## PostgreSQL Database

### Purpose

PostgreSQL provides relational database services for:
- **Nessie**: Catalog metadata storage
- **Airflow**: Workflow metadata
- **Keycloak**: User and realm data
- **Superset**: Dashboard and query metadata
- **JupyterHub**: User session data
- **MLflow**: Experiment tracking

### High Availability Configuration

**Architecture**: CrunchyData PostgreSQL Operator (3 replicas)  
**Operator**: postgresoperator.v5.8.4 (open source)  
**PostgreSQL Version**: 16  
**Automatic Database Initialization**: Yes (all 6 databases created on deployment)  
**File**: `deploy/openshift/storage/postgresql-cluster.yaml`

### Deployment Configuration

The CrunchyData operator automatically creates:
- **6 Application Databases**: nessie, keycloak, airflow, superset, jupyterhub, mlflow
- **6 Application Users**: One for each database with SUPERUSER privileges
- **6 Kubernetes Secrets**: Auto-generated with connection details (host, port, dbname, user, password, JDBC URI)
- **Schema Privileges**: Automatically granted via databaseInitSQL ConfigMap

```yaml
---
# PostgreSQL Cluster using CrunchyData Operator
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: datalyptica-postgres
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
    datalyptica.io/component: postgresql
spec:
  postgresVersion: 16
  
  # High Availability: 3 instances
  instances:
    - name: instance1
      replicas: 3
      dataVolumeClaimSpec:
        storageClassName: 9500-storageclass
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    postgres-operator.crunchydata.com/cluster: datalyptica-postgres
      resources:
        requests:
          cpu: 1000m
          memory: 2Gi
        limits:
          cpu: 2000m
          memory: 4Gi
  
  # Backups to MinIO
  backups:
    pgbackrest:
      global:
        repo1-retention-full: "14"
        repo1-retention-full-type: time
      repos:
        - name: repo1
          s3:
            bucket: datalyptica
            endpoint: minio.datalyptica.svc.cluster.local:9000
            region: us-east-1
          schedules:
            full: "0 2 * * 0"
            differential: "0 2 * * 1-6"
      configuration:
        - secret:
            name: minio-credentials
      repoHost:
        dedicated: {}
  
  # PostgreSQL Configuration
  patroni:
    dynamicConfiguration:
      postgresql:
        parameters:
          shared_buffers: 512MB
          effective_cache_size: 2GB
          maintenance_work_mem: 256MB
          checkpoint_completion_target: "0.9"
          wal_buffers: 16MB
          default_statistics_target: 100
          random_page_cost: "1.1"
          effective_io_concurrency: 200
          work_mem: 16MB
          min_wal_size: 1GB
          max_wal_size: 4GB
          max_connections: 200
  
  # Database Initialization - Create all databases and users
  databaseInitSQL:
    key: init.sql
    name: postgres-init-sql
  
  # Users - passwords auto-generated by operator
  users:
    - name: nessie
      databases:
        - nessie
      password:
        type: AlphaNumeric
      options: "SUPERUSER"
    - name: keycloak
      databases:
        - keycloak
      password:
        type: AlphaNumeric
      options: "SUPERUSER"
    - name: airflow
      databases:
        - airflow
      password:
        type: AlphaNumeric
      options: "SUPERUSER"
    - name: superset
      databases:
        - superset
      password:
        type: AlphaNumeric
      options: "SUPERUSER"
    - name: jupyterhub
      databases:
        - jupyterhub
      password:
        type: AlphaNumeric
      options: "SUPERUSER"
    - name: mlflow
      databases:
        - mlflow
      password:
        type: AlphaNumeric
      options: "SUPERUSER"
---
# Database Initialization SQL ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-sql
  namespace: datalyptica
data:
  init.sql: |
    -- Database initialization
    -- Users are automatically created by CrunchyData operator
    -- This script grants additional privileges if needed
    
    \c nessie
    GRANT ALL PRIVILEGES ON SCHEMA public TO nessie;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO nessie;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO nessie;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO nessie;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO nessie;
    
    \c keycloak
    GRANT ALL PRIVILEGES ON SCHEMA public TO keycloak;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO keycloak;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
    
    \c airflow
    GRANT ALL PRIVILEGES ON SCHEMA public TO airflow;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO airflow;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO airflow;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO airflow;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO airflow;
    
    \c superset
    GRANT ALL PRIVILEGES ON SCHEMA public TO superset;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO superset;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO superset;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO superset;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO superset;
    
    \c jupyterhub
    GRANT ALL PRIVILEGES ON SCHEMA public TO jupyterhub;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO jupyterhub;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO jupyterhub;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO jupyterhub;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO jupyterhub;
    
    \c mlflow
    GRANT ALL PRIVILEGES ON SCHEMA public TO mlflow;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mlflow;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mlflow;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mlflow;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mlflow;
```

### Deployment Commands

```bash
# 1. Deploy PostgreSQL cluster (includes ConfigMap + Cluster)
oc apply -f deploy/openshift/storage/postgresql-cluster.yaml

# Expected output:
# postgrescluster.postgres-operator.crunchydata.com/datalyptica-postgres created
# configmap/postgres-init-sql created

# 2. Wait for cluster initialization (2-3 minutes)
# Watch pods come up: 3 instance pods + 1 repo-host pod
oc get pods -n datalyptica -w | grep postgres

# Press Ctrl+C when all show Running

# 3. Verify all PostgreSQL pods are running (4/4 containers each)
oc get pods -n datalyptica -l postgres-operator.crunchydata.com/cluster=datalyptica-postgres

# Expected: 3 instance pods showing 4/4 Running
# - datalyptica-postgres-instance1-XXXX-0
# - datalyptica-postgres-instance1-YYYY-0
# - datalyptica-postgres-instance1-ZZZZ-0

# 4. Check auto-generated user secrets (one per database)
oc get secrets -n datalyptica | grep pguser

# Expected: 6 secrets created automatically:
# - datalyptica-postgres-pguser-nessie
# - datalyptica-postgres-pguser-keycloak
# - datalyptica-postgres-pguser-airflow
# - datalyptica-postgres-pguser-superset
# - datalyptica-postgres-pguser-jupyterhub
# - datalyptica-postgres-pguser-mlflow

# Each secret contains: host, port, dbname, user, password, uri, jdbc-uri
```

### Automatic Database Initialization

**The CrunchyData operator automatically:**
1. Creates all 6 databases (nessie, keycloak, airflow, superset, jupyterhub, mlflow)
2. Creates dedicated users for each database with strong passwords
3. Generates Kubernetes secrets with complete connection information
4. Runs init.sql from ConfigMap to grant schema privileges
5. Sets up streaming replication between instances
6. Configures automatic backups to MinIO

**No manual database creation required!** All databases and users are ready immediately after cluster deployment.

### Connection Information

Each application should use its dedicated secret:

```yaml
# Example: Nessie connecting to PostgreSQL
env:
- name: QUARKUS_DATASOURCE_USERNAME
  valueFrom:
    secretKeyRef:
      name: datalyptica-postgres-pguser-nessie
      key: user
- name: QUARKUS_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: datalyptica-postgres-pguser-nessie
      key: password
- name: QUARKUS_DATASOURCE_JDBC_URL
  value: jdbc:postgresql://datalyptica-postgres-primary.datalyptica.svc:5432/nessie
```

**Service Endpoints:**
- **Primary (read-write)**: `datalyptica-postgres-primary.datalyptica.svc:5432`
- **Replicas (read-only)**: `datalyptica-postgres-replicas.datalyptica.svc:5432`

### Validation

```bash
# 1. Check PostgreSQL cluster pods (expect 3×4/4 Running)
oc get pods -n datalyptica | grep postgres

# 2. Get primary pod name
PRIMARY_POD=$(oc get pods -n datalyptica -l postgres-operator.crunchydata.com/role=master -o jsonpath='{.items[0].metadata.name}')
echo "Primary Pod: $PRIMARY_POD"

# 3. List all databases
oc exec $PRIMARY_POD -n datalyptica -c database -- psql -U postgres -c "\l"

# Expected output shows 6 application databases:
# - airflow    | postgres | UTF8 | ... | airflow=CTc/postgres
# - jupyterhub | postgres | UTF8 | ... | jupyterhub=CTc/postgres
# - keycloak   | postgres | UTF8 | ... | keycloak=CTc/postgres
# - mlflow     | postgres | UTF8 | ... | mlflow=CTc/postgres
# - nessie     | postgres | UTF8 | ... | nessie=CTc/postgres
# - superset   | postgres | UTF8 | ... | superset=CTc/postgres

# 4. Test connection with application user
oc exec $PRIMARY_POD -n datalyptica -c database -- psql -U nessie -d nessie -c "SELECT current_user, current_database();"

# Expected:
#  current_user | current_database
# --------------+------------------
#  nessie       | nessie

# 5. Check replication status (should show 2 replicas streaming)
oc exec $PRIMARY_POD -n datalyptica -c database -- psql -U postgres -c "SELECT client_addr, application_name, state, sync_state FROM pg_stat_replication;"

# Expected: 2 rows showing "streaming" state, "async" sync_state

# 6. Verify PVCs (3×200Gi data volumes)
oc get pvc -n datalyptica | grep postgres

# Expected: 3 PVCs, all Bound, 200Gi each

# 7. Check cluster health logs
oc logs $PRIMARY_POD -n datalyptica -c database --tail=10

# Expected: Patroni logs showing "I am the leader with the lock"

# 8. View connection details from secret (for troubleshooting)
oc get secret datalyptica-postgres-pguser-nessie -n datalyptica -o jsonpath='{.data.uri}' | base64 -d ; echo

# Expected: postgresql://nessie:<password>@datalyptica-postgres-primary.datalyptica.svc:5432/nessie
```

---

## Redis Cache

### Purpose

Redis provides:
- **Nessie**: Catalog caching
- **Airflow**: Celery broker for distributed task execution
- **Session storage**: Application session data
- **Rate limiting**: API rate limit tracking

### High Availability Configuration

**Architecture**: Redis Sentinel (3 replicas + 3 sentinels)

**Features**:
- **Automatic Failover**: Sentinel detects master failure and promotes replica
- **Quorum**: Requires 2 sentinels to agree for failover decision
- **Replication**: 1 master + 2 replicas with asynchronous replication
- **Persistence**: AOF (Append-Only File) on all instances
- **Split-brain Protection**: Init container queries Sentinel for current master

**Sentinel Configuration**:
- Down detection: 5 seconds
- Failover timeout: 10 seconds
- Parallel syncs: 1 (replicas sync one at a time during failover)

### Deployment Configuration

**File**: `deploy/openshift/storage/redis-deployment.yaml`

```yaml
---
# Redis Headless Service (for StatefulSet)
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: redis
spec:
  clusterIP: None
  publishNotReadyAddresses: true
  ports:
  - port: 6379
    name: redis
  selector:
    app.kubernetes.io/name: redis
---
# Redis ConfigMap (redis.conf + sentinel.conf templates)
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: datalyptica
data:
  redis.conf: |
    requirepass REDIS_PASSWORD_PLACEHOLDER
    masterauth REDIS_PASSWORD_PLACEHOLDER
    appendonly yes
    appendfsync everysec
    maxmemory 2gb
    maxmemory-policy allkeys-lru
  sentinel.conf: |
    port 26379
    sentinel monitor redis-master 127.0.0.1 6379 2
    sentinel auth-pass redis-master REDIS_PASSWORD_PLACEHOLDER
    sentinel down-after-milliseconds redis-master 5000
    sentinel parallel-syncs redis-master 1
    sentinel failover-timeout redis-master 10000
    sentinel announce-ip ANNOUNCE_IP_PLACEHOLDER
    sentinel announce-port 26379
---
# Redis StatefulSet (HA with 3 replicas)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: datalyptica
spec:
  serviceName: redis-headless
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis
    spec:
      initContainers:
      - name: config-init
        image: redis:8.4.0-alpine
        command:
        - sh
        - -c
        - |
          # Query Sentinel for current master, configure replication accordingly
          # Handles bootstrap (redis-0 initial master) and failover recovery
          REDIS_PASSWORD=$(cat /secrets/password)
          cp /config/redis.conf /data/redis.conf
          cp /config/sentinel.conf /data/sentinel.conf
          sed -i "s/REDIS_PASSWORD_PLACEHOLDER/$REDIS_PASSWORD/g" /data/redis.conf /data/sentinel.conf
          sed -i "s/ANNOUNCE_IP_PLACEHOLDER/$(hostname -i)/g" /data/sentinel.conf
          
          # Check Sentinel for current master
          CURRENT_MASTER=$(redis-cli -h redis-sentinel -p 26379 sentinel get-master-addr-by-name redis-master 2>/dev/null | head -n 1)
          
          if [ -n "$CURRENT_MASTER" ] && [ "$CURRENT_MASTER" != "$(hostname -i)" ]; then
            echo "replicaof $CURRENT_MASTER 6379" >> /data/redis.conf
          elif [ "$(hostname)" != "redis-0" ]; then
            MASTER_IP=$(getent hosts redis-0.redis-headless | awk '{print $1}')
            echo "replicaof $MASTER_IP 6379" >> /data/redis.conf
          fi
        volumeMounts:
        - name: config
          mountPath: /config
        - name: data
          mountPath: /data
        - name: redis-secret
          mountPath: /secrets
      containers:
      - name: redis
        image: redis:8.4.0-alpine
        command: ["redis-server", "/data/redis.conf"]
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      - name: sentinel
        image: redis:8.4.0-alpine
        command:
        - sh
        - -c
        - |
          # Get master IP for Sentinel configuration
          if [ "$(hostname)" = "redis-0" ]; then
            MASTER_IP="127.0.0.1"
          else
            MASTER_IP=$(getent hosts redis-0.redis-headless | awk '{print $1}')
          fi
          sed -i "s/127.0.0.1/$MASTER_IP/g" /data/sentinel.conf
          redis-sentinel /data/sentinel.conf
        ports:
        - containerPort: 26379
          name: sentinel
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: config
        configMap:
          name: redis-config
      - name: redis-secret
        secret:
          secretName: redis-credentials
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: 9500-storageclass
      resources:
        requests:
          storage: 50Gi
---
# Redis Service (for client connections)
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: datalyptica
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
  selector:
    app.kubernetes.io/name: redis
---
# Redis Sentinel Service
apiVersion: v1
kind: Service
metadata:
  name: redis-sentinel
  namespace: datalyptica
spec:
  type: ClusterIP
  ports:
  - port: 26379
    targetPort: 26379
    name: sentinel
  selector:
    app.kubernetes.io/name: redis
```

### Deployment Commands

```bash
# Create Redis HA deployment
oc apply -f deploy/openshift/storage/redis-deployment.yaml

# Wait for all Redis pods to be ready
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=redis -n datalyptica --timeout=300s

# Verify all pods are running (should see 3 pods with 2/2 containers ready)
oc get pods -n datalyptica -l app.kubernetes.io/name=redis
```

### Validation

```bash
# 1. Check all Redis pods (should see redis-0, redis-1, redis-2)
oc get pods -n datalyptica -l app.kubernetes.io/name=redis

# Expected:
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   2/2     Running   0          5m
# redis-1   2/2     Running   0          5m
# redis-2   2/2     Running   0          5m

# 2. Check PVCs (should see 3 PVCs, one per replica)
oc get pvc -n datalyptica | grep redis

# Expected: data-redis-0, data-redis-1, data-redis-2 (all Bound, 50Gi each)

# 3. Get Redis password
REDIS_PASSWORD=$(oc get secret redis-credentials -n datalyptica -o jsonpath='{.data.password}' | base64 -d)

# 4. Test Redis connection
oc exec redis-0 -n datalyptica -c redis -- redis-cli -a $REDIS_PASSWORD ping
# Expected: PONG

# 5. Check replication status (identify master and replicas)
oc exec redis-0 -n datalyptica -c redis -- redis-cli -a $REDIS_PASSWORD INFO replication | grep role

# 6. Check Sentinel status
oc exec redis-0 -n datalyptica -c sentinel -- redis-cli -p 26379 sentinel masters

# Expected output should show:
# - num-slaves: 2
# - num-other-sentinels: 2
# - quorum: 2

# 7. Test automatic failover (optional)
# Delete current master pod and verify Sentinel promotes a replica
MASTER_POD=$(oc get pods -n datalyptica -l app.kubernetes.io/name=redis -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}' | while read name ip; do oc exec $name -n datalyptica -c redis -- redis-cli -a $REDIS_PASSWORD INFO replication 2>/dev/null | grep -q "role:master" && echo $name && break; done)

echo "Current master: $MASTER_POD"
oc delete pod $MASTER_POD -n datalyptica

# Wait 15 seconds and check new master
sleep 15
oc exec redis-sentinel -n datalyptica -- redis-cli -p 26379 sentinel get-master-addr-by-name redis-master
```

---

## Validation

### Complete Storage Layer Validation

Run these commands to verify all storage components:

```bash
# 1. Check all storage pods
oc get pods -n datalyptica -l datalyptica.io/tier=storage

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# minio-0                                             1/1     Running   0          5m
# minio-1                                             1/1     Running   0          5m
# minio-2                                             1/1     Running   0          5m
# minio-3                                             1/1     Running   0          5m
# datalyptica-postgres-instance1-xxxx-0               4/4     Running   0          5m
# datalyptica-postgres-instance1-yyyy-0               4/4     Running   0          5m
# datalyptica-postgres-instance1-zzzz-0               4/4     Running   0          5m
# datalyptica-postgres-repo-host-0                    2/2     Running   0          5m
# redis-0                                             2/2     Running   0          5m
# redis-1                                             2/2     Running   0          5m
# redis-2                                             2/2     Running   0          5m

# 2. Check all PVCs (4 MinIO + 3 PostgreSQL + 3 Redis = 10 PVCs)
oc get pvc -n datalyptica

# Expected: All PVCs in "Bound" status
# - data-minio-0 through data-minio-3 (200Gi each = 800Gi)
# - datalyptica-postgres-instance1-xxxx through zzzz (200Gi each = 600Gi)
# - data-redis-0 through data-redis-2 (50Gi each = 150Gi)
# Total: 1550Gi

# 3. Verify MinIO buckets created
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc ls local'

# Expected: 5 buckets (datalyptica, lakehouse, warehouse, mlflow, airflow)

# 4. Verify PostgreSQL databases created
PRIMARY_POD=$(oc get pods -n datalyptica -l postgres-operator.crunchydata.com/role=master -o jsonpath='{.items[0].metadata.name}')
oc exec $PRIMARY_POD -n datalyptica -c database -- psql -U postgres -c "\l" | grep -E "nessie|keycloak|airflow|superset|jupyterhub|mlflow"

# Expected: 6 databases listed

# 5. Check services
oc get svc -n datalyptica -l datalyptica.io/tier=storage

# Expected services:
# - minio, minio-console, minio-headless
# - datalyptica-postgres-primary, datalyptica-postgres-replicas, datalyptica-postgres-ha
# - redis, redis-headless

# 6. Verify MinIO HA cluster health
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc admin info local'

# Expected: Shows 4 servers online, distributed mode

# 7. Get MinIO console URL
echo "MinIO Console: https://$(oc get route minio-console -n datalyptica -o jsonpath='{.spec.host}')"
echo "Username: minio"

# 8. Test PostgreSQL replication status
oc exec $PRIMARY_POD -n datalyptica -c database -- psql -U postgres -c "SELECT client_addr, application_name, state, sync_state FROM pg_stat_replication;"

# Expected: 2 rows showing streaming replicas
```

### Storage Layer Checklist

- [ ] MinIO pod running (1/1 Ready)
- [ ] MinIO PVC bound (500Gi)
- [ ] MinIO console accessible via Route
- [ ] MinIO buckets created (lakehouse, warehouse, staging, archive)
- [ ] PostgreSQL cluster healthy (3/3 replicas)
- [ ] PostgreSQL PVCs bound (3x 200Gi + 3x 50Gi WAL)
- [ ] PostgreSQL databases created (nessie, airflow, keycloak, superset, mlflow)
- [ ] PostgreSQL users created and permissions granted
- [ ] Redis pods running (3/3, each 2/2 Ready - redis + sentinel containers)
- [ ] Redis PVCs bound (3× 50Gi)
- [ ] Redis replication working (1 master + 2 replicas)
- [ ] Sentinel quorum achieved (3 sentinels, quorum=2)
- [ ] Redis connection test successful (PONG)
- [ ] All services created and endpoints available

---

## Troubleshooting

### MinIO Issues

**Issue**: MinIO pod stuck in `Pending` or `ContainerCreating`
```bash
# Check PVC status for each replica
oc get pvc -n datalyptica | grep data-minio

# Check events
oc get events -n datalyptica --sort-by='.lastTimestamp' | grep minio

# Check if there's a volume attachment issue
oc describe pod minio-0 -n datalyptica
```

**Issue**: ImagePullBackOff error
```bash
# Solution: Verify image tag exists at https://quay.io/repository/minio/minio?tab=tags
# The deployment uses 'latest' tag which always exists

# Verify current image
oc get statefulset minio -n datalyptica -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should output: quay.io/minio/minio:latest

# If using specific version, ensure tag exists before deploying
```

**Issue**: Pods not scaling (stuck at 1/4 or 2/4)
```bash
# Check StatefulSet status
oc describe statefulset minio -n datalyptica

# Check PVC creation
oc get pvc -n datalyptica | grep minio

# Check storage class availability
oc get storageclass 9500-storageclass

# Force delete stuck pods
oc delete pod minio-X -n datalyptica --force --grace-period=0
```

**Issue**: MinIO console not accessible
```bash
# Check route
oc get route minio-console -n datalyptica

# Check service endpoints
oc get endpoints minio-console -n datalyptica

# Check pod logs
oc logs minio-0 -n datalyptica

# Verify all pods are ready
oc get pods -n datalyptica -l app.kubernetes.io/name=minio
```

**Issue**: Distributed mode not working
```bash
# Check if all nodes are connected
oc logs minio-0 -n datalyptica --tail=50 | grep -i "distributed\|connected"

# Verify headless service
oc get svc minio-headless -n datalyptica

# Test DNS resolution from pod
oc exec -it minio-0 -n datalyptica -- nslookup minio-headless.datalyptica.svc.cluster.local
```

**Issue**: Bucket initialization job fails
```bash
# Check job status
oc get job minio-init-buckets -n datalyptica

# View job logs
oc logs job/minio-init-buckets -n datalyptica

# Common issues:
# 1. MinIO not ready yet - Job retries up to 30 times (5 minutes)
# 2. Credentials incorrect - Verify minio-credentials secret has both root-user and root-password
# 3. Permission denied for /.mc - Fixed by setting MC_CONFIG_DIR=/tmp/.mc

# Verify secret structure
oc get secret minio-credentials -n datalyptica -o jsonpath='{.data}' | jq 'keys'
# Should show: ["root-password", "root-user"]

# If secret missing root-user key, recreate it:
oc delete secret minio-credentials -n datalyptica
oc create secret generic minio-credentials -n datalyptica \
  --from-literal=root-user=minio \
  --from-literal=root-password=<your-password>

# Delete and retry job
oc delete job minio-init-buckets -n datalyptica
oc apply -f deploy/openshift/storage/minio-init-job.yaml

# Manual bucket creation (if job continues to fail)
oc exec minio-0 -n datalyptica -- sh -c '
  mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  mc mb --ignore-existing local/datalyptica
  mc mb --ignore-existing local/lakehouse
  mc mb --ignore-existing local/warehouse
  mc mb --ignore-existing local/mlflow
  mc mb --ignore-existing local/airflow
  mc anonymous set download local/lakehouse
  mc anonymous set download local/warehouse
'
```

### PostgreSQL Issues

**Issue**: initdb pod shows `CreateContainerConfigError` - couldn't find key username
```bash
# CNPG operator requires both 'username' and 'password' in secret
# Prerequisites should have already patched the secret

# Verify secret has both keys
oc get secret postgres-credentials -n datalyptica -o jsonpath='{.data}' | jq 'keys'
# Should show: ["password", "username"]

# If missing username, patch the secret:
oc patch secret postgres-credentials -n datalyptica \
  --type='json' \
  -p='[{"op": "add", "path": "/data/username", "value": "ZGF0YWx5cHRpY2FfYWRtaW4="}]'
```

**Issue**: Cluster not becoming ready
```bash
# Check cluster status
oc describe cluster datalyptica-postgres -n datalyptica

# Check operator logs
oc logs -n datalyptica deployment/postgresql-operator-controller-manager

# Check pod events
oc get events -n datalyptica --sort-by='.lastTimestamp' | grep postgres
```

**Issue**: Replication not working
```bash
# Check replication status on primary
PRIMARY_POD=$(oc get pod -n datalyptica -l role=primary -o jsonpath='{.items[0].metadata.name}')
oc exec -it $PRIMARY_POD -n datalyptica -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

### Redis Issues

**Issue**: Redis pod CrashLoopBackOff
```bash
# Check logs
oc logs redis-0 -n datalyptica --previous

# Check configuration
oc describe pod redis-0 -n datalyptica
```

**Issue**: Cannot connect to Redis
```bash
# Verify secret exists
oc get secret redis-credentials -n datalyptica

# Test from within cluster
oc run redis-test --rm -i --tty --image=redis:8.4.0-alpine -n datalyptica -- redis-cli -h redis -a <password> ping
```

---

## Next Steps

With the storage layer deployed, proceed to:

1. **Catalog Layer Deployment** (See: `DEPLOYMENT-04-CATALOG.md`)
   - Deploy Nessie catalog service
   - Configure PostgreSQL connection
   - Initialize catalog

2. **Streaming Layer Deployment** (See: `DEPLOYMENT-05-STREAMING.md`)
   - Create Kafka cluster
   - Deploy Schema Registry
   - Configure Kafka Connect

---

## Storage Layer Summary

### Deployed Components

| Component | Type | Replicas | Storage | Status |
|-----------|------|----------|---------|--------|
| **MinIO** | StatefulSet | 4 | 4×200Gi (800Gi) | ✅ Running |
| **PostgreSQL** | CrunchyData PostgresCluster | 3 | 3×200Gi (600Gi) | ✅ Running |
| **Redis** | StatefulSet + Sentinel | 3 | 3×50Gi (150Gi) | ✅ Running |

### Automatic Initialization

- ✅ **MinIO**: 5 buckets created automatically (datalyptica, lakehouse, warehouse, mlflow, airflow)
- ✅ **PostgreSQL**: 6 databases + 6 users + 6 secrets auto-generated (nessie, keycloak, airflow, superset, jupyterhub, mlflow)
- ✅ **Redis**: Sentinel HA with automatic failover (quorum=2)

### Total Resources

- **Storage Allocated**: 1550Gi (800Gi MinIO + 600Gi PostgreSQL + 150Gi Redis)
- **CPU Requests**: ~7 cores (4×1 MinIO + 3×1 PostgreSQL + 3×0.25 Redis)
- **CPU Limits**: ~14 cores (4×2 MinIO + 3×2 PostgreSQL + 3×0.5 Redis)
- **Memory Requests**: ~11Gi (4×2Gi MinIO + 3×2Gi PostgreSQL + 3×512Mi Redis)
- **Memory Limits**: ~22Gi (4×4Gi MinIO + 3×4Gi PostgreSQL + 3×1Gi Redis)

### High Availability Features

- **MinIO**: EC:2 erasure coding, survives 2 node failures
- **PostgreSQL**: Patroni-based HA, automatic failover, streaming replication
- **Redis**: Sentinel quorum-based leader election, automatic promotion
- **Memory Requests**: 5 Gi
- **Memory Limits**: 10 Gi
- **Storage**: 1.5 TiB total (MinIO: 800Gi, PostgreSQL: 600Gi data + 150Gi WAL, Redis: 50Gi)
- **PVCs**: 14 total (4 MinIO + 6 PostgreSQL + 1 Redis + 3 completed init jobs)

### Service Endpoints

```
MinIO API:       minio:9000
MinIO Console:   minio-console:9001
  Route:         https://minio-console-datalyptica.apps.virocp-poc.efinance.com.eg

PostgreSQL:      datalyptica-postgres-rw:5432 (read-write - primary)
                 datalyptica-postgres-ro:5432 (read-only - replicas)
                 datalyptica-postgres-r:5432 (read - any instance)

Redis:           redis:6379
```

### Deployed Resources Summary

**Pods**: 8 Running
- MinIO: 4 pods (minio-0 through minio-3)
- PostgreSQL: 3 pods (datalyptica-postgres-1, -2, -3)
- Redis: 1 pod (redis-0)

**Services**: 7 total
- MinIO: minio (API), minio-console, minio-headless
- PostgreSQL: datalyptica-postgres-rw, -ro, -r
- Redis: redis

**Storage**: 1.5 TiB across 14 PVCs (all Bound)

---

**Document Version**: 2.0  
**Last Updated**: December 5, 2025  
**Components Deployed**: 3/3 ✅  
**Status**: ✅ Storage layer complete - Ready for catalog layer (Nessie) deployment
