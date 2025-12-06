# Deployment Guide 05: Processing & Streaming Layer

**Date**: December 6, 2025  
**Cluster**: OpenShift 4.19.19  
**Project**: datalyptica  
**Previous Step**: [Catalog Layer](DEPLOYMENT-04-CATALOG.md)

---

## ✅ Deployment Status

| Component | Status | Version | Mode | Replicas | Configuration | Details |
|-----------|--------|---------|------|----------|---------------|---------|
| **Apache Spark** | ✅ Deployed | 3.5.7 | K8s-Native | 1 Submit + Dynamic Executors | Iceberg 1.10.0 | Custom image, PDB, History Server |
| **Apache Flink** | ✅ Deployed | 1.20.0 | K8s-Native | 1 JobManager + 2 TaskManagers | Kafka, Iceberg 1.7.0 | Custom image, PDB, HA enabled |

**Current Console Access:**
```bash
# Spark History Server UI
echo "Spark History: https://$(oc get route spark-history -n datalyptica -o jsonpath='{.spec.host}')"

# Flink Dashboard
echo "Flink UI: https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')"
```

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Custom Image Builds](#custom-image-builds)
4. [Apache Spark Deployment](#apache-spark-deployment)
5. [Apache Flink Deployment](#apache-flink-deployment)
6. [Validation](#validation)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

---

## Overview

The Processing & Streaming Layer provides distributed data processing capabilities using **Kubernetes-native** deployment modes:

- **Apache Spark 3.5.7**: Batch and streaming processing with dynamic executor allocation
- **Apache Flink 1.20.0**: Real-time stream processing with exactly-once semantics

### Key Features

**Spark Kubernetes-Native Mode**:
- ✅ Dynamic executor allocation (1-10 executors on-demand)
- ✅ No standalone cluster overhead
- ✅ Direct K8s API integration
- ✅ Automatic executor lifecycle management
- ✅ Fair scheduler with multiple pools
- ✅ Spark History Server for job tracking

**Flink Kubernetes-Native Mode**:
- ✅ JobManager for orchestration
- ✅ TaskManagers with 4 slots each
- ✅ RocksDB incremental state backend
- ✅ Exactly-once processing semantics
- ✅ Checkpointing to MinIO (60s interval)
- ✅ High availability with K8s backend

### Technology Stack

| Component | Version | Connectors/Libraries | Storage Backend |
|-----------|---------|---------------------|-----------------|
| **Spark** | 3.5.7 | Iceberg 1.10.0, Nessie, Hadoop AWS 3.4.1, AWS SDK 1.12.772 | MinIO (S3) |
| **Flink** | 1.20.0 | Kafka 3.3.0, Iceberg 1.7.0, S3 filesystem, Hadoop AWS 3.4.1 | MinIO (S3) |
| **Iceberg** | 1.10.0 (Spark), 1.7.0 (Flink) | Nessie catalog integration | MinIO lakehouse bucket |

---

## Architecture

### Processing Layer Design

```
┌──────────────────────────────────────────────────────────────────────┐
│                  PROCESSING & STREAMING LAYER (K8s-Native)           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐  │
│  │      Apache Spark 3.5.7      │  │    Apache Flink 1.20.0       │  │
│  │     (K8s-Native Mode)        │  │    (K8s-Native Mode)         │  │
│  │                              │  │                              │  │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────────┐│  │
│  │  │ Spark Submit Pod (1)   │  │  │  │  JobManager (1)         ││  │
│  │  │  - Job entry point     │  │  │  │  - Job orchestration    ││  │
│  │  │  - Client mode         │  │  │  │  - REST API: 8081       ││  │
│  │  │  - spawns drivers      │  │  │  │  - RPC: 6123            ││  │
│  │  └────────────────────────┘  │  │  └─────────────────────────┘│  │
│  │                              │  │                              │  │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────────┐│  │
│  │  │ Spark Driver (dynamic) │  │  │  │  TaskManagers (2)       ││  │
│  │  │  - Created per job     │──┼──┼─▶│  - 4 slots each         ││  │
│  │  │  - K8s pod lifecycle   │  │  │  │  - State backend: RocksDB││  │
│  │  └────────┬───────────────┘  │  │  │  - Data port: 6121      ││  │
│  │           │                   │  │  └─────────────────────────┘│  │
│  │           ├─ spawns ──┐       │  │                              │  │
│  │           │           │       │  │  ┌─────────────────────────┐│  │
│  │  ┌────────▼────┐ ┌────▼────┐  │  │  │ Checkpoints → MinIO     ││  │
│  │  │ Executor 1  │ │Executor..│  │  │  │  /flink/checkpoints     ││  │
│  │  │ (dynamic)   │ │(1-10)    │  │  │  │  Interval: 60s          ││  │
│  │  │ 4GB, 2 cores│ │          │  │  │  │  Mode: EXACTLY_ONCE     ││  │
│  │  └─────────────┘ └──────────┘  │  │  └─────────────────────────┘│  │
│  │                              │  │                              │  │
│  │  ┌────────────────────────┐  │  │  HA Features:                │  │
│  │  │ Spark History Server   │  │  │  ✓ K8s HA backend           │  │
│  │  │  - Reads event logs    │  │  │  ✓ Checkpointing            │  │
│  │  │  - UI: Port 18080      │  │  │  ✓ PodDisruptionBudgets     │  │
│  │  │  - Route enabled       │  │  │  ✓ Rolling updates          │  │
│  │  └────────────────────────┘  │  │                              │  │
│  │                              │  │                              │  │
│  │  Custom Image:               │  │  Custom Image:               │  │
│  │  spark-iceberg:3.5.7         │  │  flink-connectors:1.20.0     │  │
│  │  - Pre-loaded JARs           │  │  - Pre-loaded connectors     │  │
│  │  - Startup: ~10s             │  │  - Startup: ~15s             │  │
│  │                              │  │                              │  │
│  │  HA Features:                │  │  Resource Allocation:        │  │
│  │  ✓ Dynamic allocation        │  │  - JobManager: 2 cores, 2GB  │  │
│  │  ✓ PodDisruptionBudgets      │  │  - TaskManager: 2 cores, 4GB │  │
│  │  ✓ Event logging to MinIO    │  │  - Total slots: 8            │  │
│  │  ✓ Fair scheduler (5 pools)  │  │                              │  │
│  │                              │  │                              │  │
│  └──────────────────────────────┘  └──────────────────────────────┘  │
│                                                                      │
└──────────────────────┬───────────────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
   ┌────▼─────┐                 ┌─────▼────┐
   │  Nessie  │                 │  MinIO   │
   │ Catalog  │                 │  Storage │
   │  (API)   │                 │ lakehouse│
   └──────────┘                 └──────────┘
        │                             │
        └──────────┬──────────────────┘
                   │
           ┌───────▼────────┐
           │ Iceberg Tables │
           │ s3://lakehouse/│
           └────────────────┘
```

### Deployment Model Comparison

| Feature | Standalone Mode (❌ Old) | Kubernetes-Native (✅ New) |
|---------|-------------------------|---------------------------|
| **Architecture** | Master + Workers | Submit Pod + Dynamic Executors/TaskManagers |
| **Resource Management** | Static allocation | Dynamic on-demand |
| **Scalability** | Manual worker scaling | Automatic K8s scheduling |
| **Integration** | External to K8s | Native K8s API |
| **Overhead** | Separate cluster components | Minimal, on-demand |
| **Executor Lifecycle** | Long-running workers | Per-job, automatic cleanup |
| **Failure Handling** | Manual intervention | K8s self-healing |

---

## Custom Image Builds

Both Spark and Flink use custom-built images with pre-installed connectors to:
- ✅ Eliminate init container overhead
- ✅ Reduce startup time (~10-15 seconds vs ~2 minutes)
- ✅ Ensure connector version compatibility
- ✅ Simplify deployment configuration

### Build Configuration

Images are built using OpenShift BuildConfig with Git source strategy.

**File**: `deploy/openshift/builds/processing-image-builds.yaml`

```yaml
---
# Spark Custom Image BuildConfig
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: spark-iceberg
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: spark
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: processing
spec:
  source:
    type: Git
    git:
      uri: https://github.com/datalyptica/datalyptica.git
      ref: main
    contextDir: deploy/docker/spark
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  output:
    to:
      kind: ImageStreamTag
      name: spark-iceberg:3.5.7
  triggers:
  - type: ConfigChange
  - type: ImageChange
---
# Spark ImageStream
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: spark-iceberg
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: spark
    app.kubernetes.io/part-of: datalyptica
spec:
  lookupPolicy:
    local: true
  tags:
  - name: "3.5.7"
    from:
      kind: DockerImage
      name: spark-iceberg:3.5.7
---
# Flink Custom Image BuildConfig
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: flink-connectors
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: flink
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: streaming
spec:
  source:
    type: Git
    git:
      uri: https://github.com/datalyptica/datalyptica.git
      ref: main
    contextDir: deploy/docker/flink
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  output:
    to:
      kind: ImageStreamTag
      name: flink-connectors:1.20.0
  triggers:
  - type: ConfigChange
  - type: ImageChange
---
# Flink ImageStream
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: flink-connectors
  namespace: datalyptica
  labels:
    app.kubernetes.io/name: flink
    app.kubernetes.io/part-of: datalyptica
spec:
  lookupPolicy:
    local: true
  tags:
  - name: "1.20.0"
    from:
      kind: DockerImage
      name: flink-connectors:1.20.0
```

### Build Images

```bash
# 1. Apply build configurations
oc apply -f deploy/openshift/builds/processing-image-builds.yaml

# 2. Start Spark image build
oc start-build spark-iceberg -n datalyptica --follow

# Expected output:
# Cloning "https://github.com/datalyptica/datalyptica.git" ...
# Step 1/6 : FROM apache/spark:3.5.7-scala2.12-java17-python3-ubuntu
# ...
# Successfully pushed image-registry.openshift-image-registry.svc:5000/datalyptica/spark-iceberg@sha256:...
# Push successful

# Build time: ~90 seconds

# 3. Start Flink image build
oc start-build flink-connectors -n datalyptica --follow

# Expected output:
# Cloning "https://github.com/datalyptica/datalyptica.git" ...
# Step 1/8 : FROM apache/flink:1.20.0-scala_2.12-java17
# ...
# Successfully pushed image-registry.openshift-image-registry.svc:5000/datalyptica/flink-connectors@sha256:...
# Push successful

# Build time: ~105 seconds

# 4. Verify builds completed
oc get builds -n datalyptica | grep -E "spark-iceberg|flink-connectors"

# Expected output:
# spark-iceberg-1       Docker   Git        Complete   90 seconds ago
# flink-connectors-1    Docker   Git        Complete   105 seconds ago

# 5. Verify image streams
oc get imagestream spark-iceberg flink-connectors -n datalyptica

# Expected output:
# NAME                IMAGE REPOSITORY                                                           TAGS     UPDATED
# spark-iceberg       image-registry.openshift-image-registry.svc:5000/datalyptica/spark-iceberg   3.5.7    2 minutes ago
# flink-connectors    image-registry.openshift-image-registry.svc:5000/datalyptica/flink-connectors 1.20.0   1 minute ago

# 6. Check image details
oc describe imagestream spark-iceberg -n datalyptica
oc describe imagestream flink-connectors -n datalyptica
```

### Spark Custom Image Details

**Base Image**: `apache/spark:3.5.7-scala2.12-java17-python3-ubuntu`

**Included JARs** (Pre-loaded in `/opt/spark/jars/`):
- `iceberg-spark-runtime-3.5_2.12-1.10.0.jar` - Iceberg Spark runtime
- `iceberg-nessie-1.10.0.jar` - Nessie catalog integration
- `hadoop-aws-3.4.1.jar` - Hadoop AWS S3A filesystem
- `aws-java-sdk-bundle-1.12.772.jar` - AWS SDK v1 (for S3A)
- `bundle-2.28.11.jar` - AWS SDK v2 (for Iceberg S3FileIO)
- `url-connection-client-2.28.11.jar` - AWS SDK HTTP client

**Security**: Runs as UID 185 (non-root, OpenShift compatible)

### Flink Custom Image Details

**Base Image**: `apache/flink:1.20.0-scala_2.12-java17`

**Included Connectors** (Pre-loaded in `/opt/flink/lib/`):
- `flink-sql-connector-kafka-3.3.0-1.20.jar` - Kafka connector
- `iceberg-flink-runtime-1.20-1.7.0.jar` - Iceberg Flink runtime
- `hadoop-common-3.4.1.jar` - Hadoop common libraries
- `hadoop-aws-3.4.1.jar` - Hadoop AWS S3A filesystem
- `aws-java-sdk-bundle-1.12.772.jar` - AWS SDK v1
- `iceberg-nessie-1.10.0.jar` - Nessie catalog integration
- `bundle-2.28.11.jar` - Nessie client bundle

**S3 Filesystem Plugin** (`/opt/flink/plugins/s3-fs-hadoop/`):
- `flink-s3-fs-hadoop-1.20.0.jar` - S3 filesystem plugin

**Security**: Runs as UID 1000 (non-root, OpenShift compatible)

---

## Apache Spark Deployment

### Deployment Architecture

**Kubernetes-Native Mode**: True K8s integration where:
1. **Submit Pod**: Long-running pod that submits jobs via `spark-submit`
2. **Driver Pod**: Created dynamically per job by the Submit pod
3. **Executor Pods**: Created dynamically by the Driver pod (1-10 executors)
4. **History Server**: Standalone pod for viewing completed jobs

### Prerequisites

Before deploying Spark, ensure:
- ✅ MinIO is running (storage for event logs and checkpoints)
- ✅ Nessie is running (catalog for Iceberg tables)
- ✅ `minio-credentials` secret exists
- ✅ Custom Spark image is built (`spark-iceberg:3.5.7`)

### Deployment Files

1. **`spark-k8s-native-production.yaml`** - Main deployment (Submit Pod, History Server, ConfigMaps, RBAC)
2. **`spark-pdb.yaml`** - PodDisruptionBudgets for high availability

### Deploy Spark

```bash
# 1. Deploy Spark components
oc apply -f deploy/openshift/processing/spark-k8s-native-production.yaml

# Expected output:
# namespace/datalyptica unchanged
# configmap/spark-k8s-config created
# serviceaccount/spark-driver created
# role.rbac.authorization.k8s.io/spark-driver-role created
# rolebinding.rbac.authorization.k8s.io/spark-driver-rolebinding created
# deployment.apps/spark-submit created
# service/spark-submit-svc created
# service/spark-history-svc created
# deployment.apps/spark-history-server created
# poddisruptionbudget.policy/spark-submit-pdb created

# 2. Wait for Spark Submit pod to be ready (30-45 seconds)
oc wait --for=condition=ready pod -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit -n datalyptica --timeout=120s

# Expected output:
# pod/spark-submit-xxxxxxxxxx-xxxxx condition met

# 3. Wait for Spark History Server to be ready (45-60 seconds)
oc wait --for=condition=ready pod -l app.kubernetes.io/name=spark,app.kubernetes.io/component=history-server -n datalyptica --timeout=120s

# Expected output:
# pod/spark-history-server-xxxxxxxxxx-xxxxx condition met

# 4. Verify all Spark pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=spark

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# spark-submit-xxxxxxxxxx-xxxxx           1/1     Running   0          60s
# spark-history-server-xxxxxxxxxx-xxxxx   1/1     Running   0          60s

# 5. Create OpenShift Routes for external access
oc create route edge spark-history \
  --service=spark-history-svc \
  --port=18080 \
  --insecure-policy=Redirect \
  -n datalyptica

# Expected output:
# route.route.openshift.io/spark-history created

# 6. Get Spark History Server URL
SPARK_HISTORY_URL="https://$(oc get route spark-history -n datalyptica -o jsonpath='{.spec.host}')"
echo "Spark History Server: $SPARK_HISTORY_URL"

# 7. Verify services created
oc get svc -n datalyptica -l app.kubernetes.io/name=spark

# Expected output:
# NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
# spark-submit-svc    ClusterIP   172.30.xxx.xxx   <none>        4040/TCP    2m
# spark-history-svc   ClusterIP   172.30.xxx.xxx   <none>        18080/TCP   2m

# 8. Verify RBAC resources
oc get serviceaccount spark-driver -n datalyptica
oc get role spark-driver-role -n datalyptica
oc get rolebinding spark-driver-rolebinding -n datalyptica

# 9. Check Spark Submit pod logs
oc logs -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit --tail=20

# Expected output should show:
# Spark Submit Pod Ready
# Submit jobs using: oc exec -it spark-submit-xxx -- spark-submit ...
# Spark version: 3.5.7

# 10. Check Spark History Server logs
oc logs -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=history-server --tail=20

# Expected to see history server started on port 18080
```

### Spark Configuration Highlights

**ConfigMap: spark-k8s-config**

Key configuration parameters:

```yaml
# Kubernetes Native Mode
spark.master                                    k8s://https://kubernetes.default.svc:443
spark.kubernetes.namespace                      datalyptica
spark.kubernetes.authenticate.driver.serviceAccountName spark-driver

# Container Image
spark.kubernetes.container.image                image-registry.openshift-image-registry.svc:5000/datalyptica/spark-iceberg:3.5.7

# Dynamic Executor Allocation
spark.dynamicAllocation.enabled                 true
spark.dynamicAllocation.minExecutors            1
spark.dynamicAllocation.maxExecutors            10
spark.dynamicAllocation.initialExecutors        2

# Iceberg + Nessie Catalog
spark.sql.catalog.iceberg                       org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.iceberg.catalog-impl          org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.iceberg.uri                   http://nessie.datalyptica.svc.cluster.local:19120/api/v2
spark.sql.catalog.iceberg.warehouse             s3a://lakehouse/

# S3/MinIO Storage
spark.hadoop.fs.s3a.endpoint                    http://minio.datalyptica.svc.cluster.local:9000
spark.hadoop.fs.s3a.path.style.access           true

# Event Logging
spark.eventLog.enabled                          true
spark.eventLog.dir                              s3a://lakehouse/spark-event-logs
spark.history.fs.logDirectory                   s3a://lakehouse/spark-event-logs
```

### Submit a Test Job

```bash
# Get Spark Submit pod name
SPARK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit -o jsonpath='{.items[0].metadata.name}')

# Execute into the pod
oc exec -it ${SPARK_POD} -n datalyptica -- bash

# Inside the pod, submit SparkPi example (cluster mode)
spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode cluster \
  --name spark-pi-test \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.kubernetes.namespace=datalyptica \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-driver \
  --conf spark.kubernetes.container.image=image-registry.openshift-image-registry.svc:5000/datalyptica/spark-iceberg:3.5.7 \
  --conf spark.executor.instances=2 \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 1000

# Exit the pod
exit

# Monitor driver pod creation
oc get pods -n datalyptica -l spark-role=driver -w

# View driver logs
oc logs -n datalyptica -l spark-role=driver -f

# View executor logs
oc logs -n datalyptica -l spark-role=executor -f

# After job completes, check Spark History Server
# Navigate to $SPARK_HISTORY_URL to see completed job
```

---

## Apache Flink Deployment

### Deployment Architecture

**Kubernetes-Native Mode**: Flink natively integrates with K8s:
1. **JobManager**: Orchestrates job execution and manages TaskManagers
2. **TaskManagers**: Execute tasks with 4 slots each (2 replicas = 8 total slots)
3. **Checkpointing**: Periodic state snapshots to MinIO for fault tolerance
4. **HA Mode**: Kubernetes HA backend for JobManager leader election

### Prerequisites

Before deploying Flink, ensure:
- ✅ MinIO is running (storage for checkpoints and savepoints)
- ✅ Nessie is running (catalog for Iceberg sinks)
- ✅ Kafka is running (optional, for streaming sources)
- ✅ `minio-credentials` secret exists
- ✅ Custom Flink image is built (`flink-connectors:1.20.0`)

### Deployment Files

1. **`flink-k8s-native-production.yaml`** - Main deployment (JobManager, TaskManagers, ConfigMaps, RBAC)
2. **`flink-pdb.yaml`** - PodDisruptionBudgets for high availability

### Deploy Flink

```bash
# 1. Deploy Flink components
oc apply -f deploy/openshift/processing/flink-k8s-native-production.yaml

# Expected output:
# namespace/datalyptica unchanged
# configmap/flink-k8s-config created
# serviceaccount/flink created
# role.rbac.authorization.k8s.io/flink-role created
# rolebinding.rbac.authorization.k8s.io/flink-rolebinding created
# deployment.apps/flink-jobmanager created
# deployment.apps/flink-taskmanager created
# service/flink-jobmanager created
# service/flink-jobmanager-rest created
# service/flink-taskmanager created
# poddisruptionbudget.policy/flink-jobmanager-pdb created
# poddisruptionbudget.policy/flink-taskmanager-pdb created

# 2. Wait for Flink JobManager to be ready (45-60 seconds)
oc wait --for=condition=ready pod -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -n datalyptica --timeout=120s

# Expected output:
# pod/flink-jobmanager-xxxxxxxxxx-xxxxx condition met

# 3. Wait for Flink TaskManagers to be ready (45-60 seconds)
oc wait --for=condition=ready pod -l app.kubernetes.io/name=flink,app.kubernetes.io/component=taskmanager -n datalyptica --timeout=120s

# Expected output:
# pod/flink-taskmanager-xxxxxxxxxx-xxxxx condition met
# pod/flink-taskmanager-xxxxxxxxxx-yyyyy condition met

# 4. Verify all Flink pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=flink

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# flink-jobmanager-xxxxxxxxxx-xxxxx     1/1     Running   0          90s
# flink-taskmanager-xxxxxxxxxx-xxxxx    1/1     Running   0          90s
# flink-taskmanager-xxxxxxxxxx-yyyyy    1/1     Running   0          90s

# 5. Create OpenShift Routes for external access
oc create route edge flink-jobmanager \
  --service=flink-jobmanager-rest \
  --port=8081 \
  --insecure-policy=Redirect \
  -n datalyptica

# Expected output:
# route.route.openshift.io/flink-jobmanager created

# 6. Get Flink Dashboard URL
FLINK_UI_URL="https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')"
echo "Flink Dashboard: $FLINK_UI_URL"

# 7. Verify services created
oc get svc -n datalyptica -l app.kubernetes.io/name=flink

# Expected output:
# NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
# flink-jobmanager          ClusterIP   172.30.xxx.xxx   <none>        6123/TCP,6124/TCP,8081/TCP   2m
# flink-jobmanager-rest     ClusterIP   172.30.xxx.xxx   <none>        8081/TCP                     2m
# flink-taskmanager         ClusterIP   None             <none>        6121/TCP,6122/TCP            2m

# 8. Verify RBAC resources
oc get serviceaccount flink -n datalyptica
oc get role flink-role -n datalyptica
oc get rolebinding flink-rolebinding -n datalyptica

# 9. Check Flink JobManager logs
oc logs -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager --tail=30

# Expected output should show:
# Starting Flink JobManager...
# Rest endpoint listening at localhost:8081
# JobManager successfully started

# 10. Check Flink TaskManager logs
oc logs -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=taskmanager --tail=20

# Expected output should show:
# Successful registration at resource manager...
# Offering 4 task slots to JobManager

# 11. Verify TaskManager registration
oc exec -n datalyptica $(oc get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -o jsonpath='{.items[0].metadata.name}') -- \
  curl -s http://localhost:8081/taskmanagers | grep -o '"slotsNumber":[0-9]*'

# Expected output:
# "slotsNumber":4
# "slotsNumber":4
# (Total 8 slots from 2 TaskManagers)
```

### Flink Configuration Highlights

**ConfigMap: flink-k8s-config**

Key configuration parameters:

```yaml
# Kubernetes Configuration
kubernetes.cluster-id: datalyptica-flink
kubernetes.namespace: datalyptica
kubernetes.service-account: flink
kubernetes.container.image: image-registry.openshift-image-registry.svc:5000/datalyptica/flink-connectors:1.20.0

# JobManager Configuration
jobmanager.rpc.address: flink-jobmanager
jobmanager.rpc.port: 6123
jobmanager.memory.process.size: 2048m

# TaskManager Configuration
taskmanager.memory.process.size: 4096m
taskmanager.numberOfTaskSlots: 4

# High Availability
high-availability.type: kubernetes
high-availability.storageDir: s3://lakehouse/flink/ha

# State Backend - RocksDB
state.backend.type: rocksdb
state.backend: rocksdb
state.backend.incremental: true
state.checkpoints.dir: s3://lakehouse/flink/checkpoints
state.savepoints.dir: s3://lakehouse/flink/savepoints

# Checkpointing
execution.checkpointing.interval: 60s
execution.checkpointing.mode: EXACTLY_ONCE
execution.checkpointing.timeout: 10min

# S3/MinIO Configuration
s3.endpoint: http://minio.datalyptica.svc.cluster.local:9000
s3.path.style.access: true
fs.s3a.endpoint: http://minio.datalyptica.svc.cluster.local:9000
fs.s3a.path.style.access: true
```

### Submit a Test Job

```bash
# Get Flink JobManager pod name
FLINK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -o jsonpath='{.items[0].metadata.name}')

# Execute into the pod
oc exec -it ${FLINK_POD} -n datalyptica -- bash

# Inside the pod, submit WordCount example
flink run -d /opt/flink/examples/streaming/WordCount.jar

# Expected output:
# Job has been submitted with JobID xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# List running jobs
flink list

# Exit the pod
exit

# View job in Flink Dashboard
# Navigate to $FLINK_UI_URL to see running job
```

---

## Validation

### Complete Processing Layer Checklist

Run the following validation steps to ensure successful deployment:

#### Spark Validation

```bash
# 1. Verify Spark pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=spark

# Expected: spark-submit (1/1), spark-history-server (1/1)

# 2. Verify Spark services
oc get svc -n datalyptica -l app.kubernetes.io/name=spark

# Expected: spark-submit-svc, spark-history-svc

# 3. Verify Spark route
oc get route spark-history -n datalyptica

# Expected: spark-history route with HTTPS

# 4. Test Spark History Server accessibility
curl -k "https://$(oc get route spark-history -n datalyptica -o jsonpath='{.spec.host}')"

# Expected: HTML response (Spark UI)

# 5. Verify Spark RBAC
oc get serviceaccount spark-driver -n datalyptica
oc get role spark-driver-role -n datalyptica
oc get rolebinding spark-driver-rolebinding -n datalyptica

# Expected: All resources exist

# 6. Check MinIO connectivity from Spark
SPARK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit -o jsonpath='{.items[0].metadata.name}')
oc exec ${SPARK_POD} -n datalyptica -- curl -s http://minio.datalyptica.svc.cluster.local:9000/minio/health/live

# Expected: HTTP 200 OK

# 7. Check Nessie connectivity from Spark
oc exec ${SPARK_POD} -n datalyptica -- curl -s http://nessie.datalyptica.svc.cluster.local:19120/api/v2/config

# Expected: JSON response with Nessie configuration

# 8. Submit test job and verify completion
# (See "Submit a Test Job" section above)

# 9. Verify event logs in MinIO
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc ls local/lakehouse/spark-event-logs/'

# Expected: List of event log directories (after job completion)
```

#### Flink Validation

```bash
# 1. Verify Flink pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=flink

# Expected: flink-jobmanager (1/1), flink-taskmanager-* (2x 1/1)

# 2. Verify Flink services
oc get svc -n datalyptica -l app.kubernetes.io/name=flink

# Expected: flink-jobmanager, flink-jobmanager-rest, flink-taskmanager

# 3. Verify Flink route
oc get route flink-jobmanager -n datalyptica

# Expected: flink-jobmanager route with HTTPS

# 4. Test Flink Dashboard accessibility
curl -k "https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')/overview"

# Expected: JSON response with cluster overview

# 5. Verify Flink RBAC
oc get serviceaccount flink -n datalyptica
oc get role flink-role -n datalyptica
oc get rolebinding flink-rolebinding -n datalyptica

# Expected: All resources exist

# 6. Check TaskManager registration
FLINK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -o jsonpath='{.items[0].metadata.name}')
oc exec ${FLINK_POD} -n datalyptica -- curl -s http://localhost:8081/taskmanagers

# Expected: JSON showing 2 TaskManagers with 4 slots each

# 7. Check MinIO connectivity from Flink
oc exec ${FLINK_POD} -n datalyptica -- curl -s http://minio.datalyptica.svc.cluster.local:9000/minio/health/live

# Expected: HTTP 200 OK

# 8. Submit test job and verify execution
# (See "Submit a Test Job" section above)

# 9. Verify checkpoints in MinIO (after job runs for 60+ seconds)
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc ls local/lakehouse/flink/checkpoints/'

# Expected: List of checkpoint directories (after job creates checkpoints)
```

#### Integration Validation

```bash
# 1. Verify all processing pods are healthy
oc get pods -n datalyptica -l 'datalyptica.io/tier in (processing,streaming)'

# Expected: All pods showing Running status

# 2. Check PodDisruptionBudgets
oc get pdb -n datalyptica | grep -E "spark|flink"

# Expected: spark-submit-pdb, flink-jobmanager-pdb, flink-taskmanager-pdb

# 3. Verify resource allocation
oc top pods -n datalyptica -l 'app.kubernetes.io/name in (spark,flink)'

# Expected: CPU and memory usage within limits

# 4. Check events for any issues
oc get events -n datalyptica --sort-by='.lastTimestamp' | grep -E "spark|flink" | tail -20

# Expected: No error events

# 5. Verify secrets are accessible
oc get secret minio-credentials -n datalyptica -o jsonpath='{.data.root-user}' | base64 -d
# Expected: minio (or your MinIO username)
```

### Processing Layer Deployment Checklist

- [ ] Spark custom image built (`spark-iceberg:3.5.7`)
- [ ] Flink custom image built (`flink-connectors:1.20.0`)
- [ ] Spark Submit pod running (1/1)
- [ ] Spark History Server running (1/1)
- [ ] Flink JobManager running (1/1)
- [ ] Flink TaskManagers running (2/2, 1/1 each)
- [ ] Spark RBAC configured (ServiceAccount, Role, RoleBinding)
- [ ] Flink RBAC configured (ServiceAccount, Role, RoleBinding)
- [ ] Spark services created (spark-submit-svc, spark-history-svc)
- [ ] Flink services created (flink-jobmanager, flink-taskmanager, flink-jobmanager-rest)
- [ ] Spark route created (spark-history with HTTPS)
- [ ] Flink route created (flink-jobmanager with HTTPS)
- [ ] MinIO connectivity verified (from both Spark and Flink)
- [ ] Nessie connectivity verified (from both Spark and Flink)
- [ ] Spark test job submitted and completed successfully
- [ ] Flink test job submitted and running
- [ ] Spark event logs visible in MinIO (lakehouse/spark-event-logs)
- [ ] Flink checkpoints visible in MinIO (lakehouse/flink/checkpoints)
- [ ] PodDisruptionBudgets active
- [ ] Web UIs accessible (Spark History Server, Flink Dashboard)

---

## Troubleshooting

### Spark Issues

#### Issue: Spark Submit Pod CrashLoopBackOff

**Symptom**: Submit pod repeatedly crashes

```bash
# Check pod events
oc describe pod -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit

# Check logs
oc logs -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit --previous
```

**Common Causes**:
1. Missing `minio-credentials` secret
2. Image pull failure
3. Insufficient permissions

**Solution**:
```bash
# Verify secret exists
oc get secret minio-credentials -n datalyptica

# Verify image exists
oc get imagestream spark-iceberg -n datalyptica

# Check SCC
oc describe scc datalyptica-scc
```

#### Issue: Spark Executor Pods Not Starting

**Symptom**: Driver pod created but executors fail

```bash
# Check driver pod logs
oc logs -n datalyptica -l spark-role=driver

# Check executor pod events
oc describe pod -n datalyptica -l spark-role=executor
```

**Common Causes**:
1. RBAC permissions missing
2. Resource quota exceeded
3. Image pull failure

**Solution**:
```bash
# Verify ServiceAccount has permissions
oc auth can-i create pods --as=system:serviceaccount:datalyptica:spark-driver -n datalyptica

# Check resource quotas
oc describe resourcequota -n datalyptica

# Verify image
oc get imagestream spark-iceberg -n datalyptica
```

#### Issue: Spark Cannot Connect to MinIO/Nessie

**Symptom**: S3 or Nessie connection errors in logs

```bash
# Test connectivity from Spark pod
SPARK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit -o jsonpath='{.items[0].metadata.name}')

# Test MinIO
oc exec ${SPARK_POD} -n datalyptica -- curl -v http://minio.datalyptica.svc.cluster.local:9000

# Test Nessie
oc exec ${SPARK_POD} -n datalyptica -- curl -v http://nessie.datalyptica.svc.cluster.local:19120/api/v2/config

# Check credentials
oc get secret minio-credentials -n datalyptica -o yaml
```

### Flink Issues

#### Issue: Flink TaskManagers Not Registering

**Symptom**: TaskManagers running but not visible in dashboard

```bash
# Check JobManager logs
oc logs -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager --tail=50

# Check TaskManager logs
oc logs -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=taskmanager --tail=50

# Verify service
oc get svc flink-jobmanager -n datalyptica

# Test connectivity
FLINK_TM_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=taskmanager -o jsonpath='{.items[0].metadata.name}')
oc exec ${FLINK_TM_POD} -n datalyptica -- nc -zv flink-jobmanager.datalyptica.svc 6123
```

**Solution**: Verify Flink RPC service is accessible and TaskManager configuration is correct

#### Issue: Flink Checkpoint Failures

**Symptom**: Frequent checkpoint failures in logs

```bash
# Check JobManager logs for checkpoint errors
oc logs -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager | grep -i checkpoint

# Verify MinIO connectivity
FLINK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -o jsonpath='{.items[0].metadata.name}')
oc exec ${FLINK_POD} -n datalyptica -- curl -v http://minio.datalyptica.svc.cluster.local:9000

# Check S3 credentials
oc get secret minio-credentials -n datalyptica -o yaml

# Verify bucket exists
oc exec minio-0 -n datalyptica -- sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc ls local/lakehouse/flink/'
```

**Solution**: Ensure MinIO is accessible and credentials are correct

#### Issue: Flink Web UI Not Accessible

**Symptom**: Route exists but UI returns errors

```bash
# Check route
oc get route flink-jobmanager -n datalyptica

# Test service directly
oc port-forward -n datalyptica svc/flink-jobmanager-rest 8081:8081

# Access locally: http://localhost:8081

# Check JobManager logs for REST API errors
oc logs -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager | grep -i rest
```

**Solution**: Verify JobManager pod is healthy and REST API is listening on port 8081

### General Debug Commands

```bash
# Get all processing resources
oc get all -n datalyptica -l 'app.kubernetes.io/name in (spark,flink)'

# Describe pod for detailed events
oc describe pod <pod-name> -n datalyptica

# View recent events
oc get events -n datalyptica --sort-by='.lastTimestamp' | tail -30

# Check resource usage
oc top pods -n datalyptica -l 'app.kubernetes.io/name in (spark,flink)'

# View all logs from a component
oc logs -n datalyptica -l app.kubernetes.io/name=spark --all-containers --tail=100

# Execute into pod for debugging
oc exec -it <pod-name> -n datalyptica -- bash

# Port-forward for local testing
oc port-forward -n datalyptica <pod-name> 8080:8080
```

---

## Next Steps

With the Processing & Streaming Layer deployed, you can now:

### 1. Run Production Workloads

**Spark Batch Processing**:
```bash
# Submit batch job to process Iceberg tables
SPARK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit -o jsonpath='{.items[0].metadata.name}')

oc exec -it ${SPARK_POD} -n datalyptica -- spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode cluster \
  --name etl-pipeline \
  --conf spark.kubernetes.namespace=datalyptica \
  --conf spark.executor.instances=5 \
  s3a://lakehouse/jobs/etl_pipeline.py
```

**Flink Streaming**:
```bash
# Submit streaming job
FLINK_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -o jsonpath='{.items[0].metadata.name}')

oc exec -it ${FLINK_POD} -n datalyptica -- flink run -d \
  /opt/flink/jobs/kafka-to-iceberg-pipeline.jar
```

### 2. Deploy Query Layer

Proceed to **Query Layer Deployment** (See: `DEPLOYMENT-06-QUERY.md`) to deploy:
- **Trino**: Distributed SQL query engine for Iceberg tables
- **ClickHouse**: Real-time OLAP analytics database

### 3. Set Up Monitoring

Configure comprehensive monitoring:
```bash
# Deploy Prometheus ServiceMonitors
oc apply -f deploy/openshift/processing/monitoring.yaml

# Verify metrics endpoints
oc exec ${SPARK_POD} -n datalyptica -- curl -s http://localhost:4040/metrics/json
oc exec ${FLINK_POD} -n datalyptica -- curl -s http://localhost:9249/metrics
```

### 4. Create Iceberg Tables

Use Spark to create your first Iceberg tables:
```bash
oc exec -it ${SPARK_POD} -n datalyptica -- pyspark \
  --conf spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog

# In PySpark shell:
spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.analytics")
spark.sql("CREATE TABLE iceberg.analytics.events (id BIGINT, ts TIMESTAMP) USING iceberg")
spark.sql("INSERT INTO iceberg.analytics.events VALUES (1, current_timestamp())")
spark.sql("SELECT * FROM iceberg.analytics.events").show()
```

### 5. Performance Tuning

Optimize for your workload:
- Adjust executor instances based on data volume
- Tune checkpoint intervals for Flink
- Configure Iceberg table properties (partition spec, file size)
- Monitor resource usage and adjust limits

---

## Summary

**Processing Layer Deployment Complete!** ✅

You have successfully deployed:
- ✅ **Apache Spark 3.5.7** (Kubernetes-native with dynamic executors)
- ✅ **Apache Flink 1.20.0** (Kubernetes-native with HA configuration)
- ✅ **Iceberg Integration** (via Nessie catalog and MinIO storage)
- ✅ **Custom Images** (pre-loaded connectors for fast startup)
- ✅ **High Availability** (PodDisruptionBudgets, health checks)
- ✅ **Web UIs** (Spark History Server, Flink Dashboard)

**Key URLs**:
- Spark History: `https://$(oc get route spark-history -n datalyptica -o jsonpath='{.spec.host}')`
- Flink Dashboard: `https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')`

**What's Next**: Deploy the Query Layer to enable SQL access to your data lakehouse.

---

**Previous**: [Catalog Layer](DEPLOYMENT-04-CATALOG.md)  
**Next**: Query Layer (TBD)  
**Home**: [Deployment Guide Summary](README.md)
