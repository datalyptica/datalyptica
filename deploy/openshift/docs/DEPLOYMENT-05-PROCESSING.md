# Deployment Guide 05: Processing & Streaming Layer

**Date**: December 5, 2025  
**Cluster**: OpenShift 4.19.19  
**Project**: datalyptica  
**Previous Step**: [Catalog Layer](DEPLOYMENT-04-CATALOG.md)

---

## ✅ Deployment Status

| Component | Status | Version | Replicas | Configuration | Details |
|-----------|--------|---------|----------|---------------|---------|
| **Apache Spark** | ✅ Deployed | 3.5.7 | 1 Master + 5 Workers | HA with PDB | Custom image with Iceberg 1.8.0 |
| **Apache Flink** | ✅ Deployed | 2.1.0 | 2 JobManagers + 5 TaskManagers | Kubernetes HA | Custom image with Kafka 3.4.0, Iceberg 1.8.0, S3 plugin |

**Current Console Access:**
```bash
# Spark Master UI
echo "Spark UI: https://$(oc get route spark-master -n datalyptica -o jsonpath='{.spec.host}')"

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
6. [High Availability Configuration](#high-availability-configuration)
7. [Validation](#validation)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

---

## Overview

The Processing & Streaming Layer provides distributed data processing capabilities:

- **Apache Spark 3.5.7**: Batch processing with Iceberg 1.8.0 integration
- **Apache Flink 2.1.0**: Real-time stream processing with Kafka and Iceberg connectors

### Technology Stack

| Component | Version | Purpose | Connectors |
|-----------|---------|---------|------------|
| **Spark** | 3.5.7 | Batch processing | Iceberg 1.8.0, Nessie catalog, Hadoop AWS 3.4.1 |
| **Flink** | 2.1.0 | Stream processing | Kafka 3.4.0, Iceberg 1.8.0, S3 filesystem |
| **Iceberg** | 1.8.0 | Table format | Certified for Spark 3.5.x and Flink 2.1.x |

---

## Architecture

### Processing Layer Design

```
┌───────────────────────────────────────────────────────────────────────┐
│                    PROCESSING & STREAMING LAYER                       │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────┐  ┌──────────────────────────────┐  │
│  │      Apache Spark 3.5.7      │  │    Apache Flink 2.1.0        │  │
│  │                              │  │                              │  │
│  │  ┌────────────────────────┐  │  │  ┌─────────────────────────┐│  │
│  │  │   Spark Master (1)     │  │  │  │  JobManager #1 (Active) ││  │
│  │  │   - 1 replica          │  │  │  │  - Leader election      ││  │
│  │  │   - Recreate strategy  │  │  │  │  - Kubernetes HA        ││  │
│  │  │   - PDB: minAvail=1    │  │  │  │  - PDB: minAvail=1      ││  │
│  │  └────────────────────────┘  │  │  └─────────────────────────┘│  │
│  │                              │  │  ┌─────────────────────────┐│  │
│  │  ┌────────────────────────┐  │  │  │  JobManager #2 (Standby)││  │
│  │  │  Spark Workers (5)     │  │  │  │  - Standby replica      ││  │
│  │  │  - 5 replicas          │  │  │  │  - Automatic failover   ││  │
│  │  │  - Pod anti-affinity   │  │  │  │  - RTO < 15s            ││  │
│  │  │  - PDB: minAvail=3     │  │  │  └─────────────────────────┘│  │
│  │  │  - 4 cores, 4GB each   │  │  │                              │  │
│  │  └────────────────────────┘  │  │  ┌─────────────────────────┐│  │
│  │                              │  │  │  TaskManagers (5)        ││  │
│  │  Custom Image:               │  │  │  - 5 replicas           ││  │
│  │  spark-iceberg:3.5.7         │  │  │  - Pod anti-affinity    ││  │
│  │  - Iceberg 1.8.0             │  │  │  - PDB: minAvail=3      ││  │
│  │  - Nessie client             │  │  │  - 4 slots each         ││  │
│  │  - Hadoop AWS 3.4.1          │  │  └─────────────────────────┘│  │
│  │  - AWS SDK 1.12.772          │  │                              │  │
│  │                              │  │  Custom Image:               │  │
│  │  HA Features:                │  │  flink-connectors:2.1.0      │  │
│  │  ✓ Pod anti-affinity         │  │  - Kafka connector 3.4.0    │  │
│  │  ✓ PodDisruptionBudgets      │  │  - Iceberg 1.8.0            │  │
│  │  ✓ Rolling updates           │  │  - S3 filesystem plugin     │  │
│  │  ✓ Balanced health checks    │  │                              │  │
│  │                              │  │  HA Features:                │  │
│  └──────────────────────────────┘  │  ✓ Kubernetes HA (leader)   │  │
│                                     │  ✓ Checkpointing (30s)      │  │
│                                     │  ✓ EXACTLY_ONCE semantics   │  │
│                                     │  ✓ Pod anti-affinity        │  │
│                                     │  ✓ PodDisruptionBudgets     │  │
│                                     │  ✓ Active/standby failover  │  │
│                                     └──────────────────────────────┘  │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
            │                                   │
            ▼                                   ▼
    ┌──────────────┐                   ┌──────────────┐
    │    Nessie    │                   │    Kafka     │
    │   Catalog    │                   │   Streams    │
    └──────────────┘                   └──────────────┘
            │                                   │
            ▼                                   ▼
    ┌──────────────┐                   ┌──────────────┐
    │    MinIO     │                   │  ClickHouse  │
    │  (lakehouse) │                   │   (OLAP)     │
    └──────────────┘                   └──────────────┘
```

---

## Custom Image Builds

Both Spark and Flink use custom-built images with pre-installed connectors to avoid init container overhead and reduce startup time from ~2 minutes to ~10 seconds.

### Image Registry

Images are built and stored in OpenShift's internal registry:
- **Registry**: `image-registry.openshift-image-registry.svc:5000`
- **Namespace**: `datalyptica`
- **Build Method**: OpenShift BuildConfig with Git source

### Spark Custom Image

**Image**: `spark-iceberg:3.5.7`  
**Base**: `apache/spark:3.5.7-scala2.12-java17-python3-ubuntu`  
**Build Time**: ~1m30s

**Included JARs**:
```
/opt/spark/jars/iceberg/
├── iceberg-spark-runtime-3.5_2.12-1.8.0.jar
├── iceberg-nessie-1.8.0.jar
├── hadoop-aws-3.4.1.jar
└── aws-java-sdk-bundle-1.12.772.jar
```

**Dockerfile** (`deploy/docker/spark/Dockerfile`):
```dockerfile
FROM apache/spark:3.5.7-scala2.12-java17-python3-ubuntu

USER root

# Download Iceberg and AWS JARs (certified versions)
RUN mkdir -p /opt/spark/jars/iceberg && \
    cd /opt/spark/jars/iceberg && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.8.0/iceberg-spark-runtime-3.5_2.12-1.8.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-nessie/1.8.0/iceberg-nessie-1.8.0.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.772/aws-java-sdk-bundle-1.12.772.jar

# Fix permissions for OpenShift (random UIDs)
RUN mkdir -p /tmp/spark-work /tmp/spark-events && \
    chmod -R 777 /tmp/spark-work /tmp/spark-events /opt/spark/work 2>/dev/null || true

USER 1000
WORKDIR /opt/spark
```

### Flink Custom Image

**Image**: `flink-connectors:2.1.0`  
**Base**: `flink:2.1.0-scala_2.12-java17`  
**Build Time**: ~1m45s

**Included Connectors**:
```
/opt/flink/lib/connectors/
├── flink-sql-connector-kafka-3.4.0-2.1.jar
└── iceberg-flink-runtime-2.1-1.8.0.jar

/opt/flink/plugins/s3-fs-hadoop/
└── flink-s3-fs-hadoop-2.1.0.jar
```

**Dockerfile** (`deploy/docker/flink/Dockerfile`):
```dockerfile
FROM flink:2.1.0-scala_2.12-java17

USER root

# Download Flink connectors (certified for Flink 2.1)
RUN mkdir -p /opt/flink/lib/connectors && \
    cd /opt/flink/lib/connectors && \
    curl -L -o flink-sql-connector-kafka-3.4.0-2.1.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-2.1/flink-sql-connector-kafka-3.4.0-2.1.jar && \
    curl -L -o iceberg-flink-runtime-2.1-1.8.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-2.1/1.8.0/iceberg-flink-runtime-2.1-1.8.0.jar

# Download S3 filesystem plugin
RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop && \
    cd /opt/flink/plugins/s3-fs-hadoop && \
    curl -L -o flink-s3-fs-hadoop-2.1.0.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/2.1.0/flink-s3-fs-hadoop-2.1.0.jar

# Fix permissions for OpenShift
RUN chmod -R 777 /opt/flink 2>/dev/null || true

USER 1000
WORKDIR /opt/flink
```

### Building Images

```bash
# Build Spark image
oc apply -f deploy/openshift/builds/processing-image-builds.yaml -n datalyptica
oc start-build spark-iceberg -n datalyptica --follow

# Build Flink image
oc start-build flink-connectors -n datalyptica --follow

# Verify builds
oc get builds -n datalyptica | grep -E "spark-iceberg|flink-connectors"
oc get imagestream spark-iceberg flink-connectors -n datalyptica
```

---

## Apache Spark Deployment

### Deployment Configuration

**File**: `deploy/openshift/processing/spark-deployment.yaml`

**Key Specifications**:
- **Master**: 1 replica (Recreate strategy for consistency)
- **Workers**: 5 replicas (RollingUpdate for zero-downtime)
- **Resources per Worker**: 4 cores, 4GB RAM
- **Image**: `image-registry.openshift-image-registry.svc:5000/datalyptica/spark-iceberg:3.5.7`

### Deploy Spark

```bash
# Deploy Spark cluster
oc apply -f deploy/openshift/processing/spark-deployment.yaml -n datalyptica

# Deploy PodDisruptionBudgets
oc apply -f deploy/openshift/processing/spark-pdb.yaml -n datalyptica

# Verify deployment
oc get pods -l app.kubernetes.io/name=spark -n datalyptica
oc get svc,route -l app.kubernetes.io/name=spark -n datalyptica

# Check Spark Master logs
oc logs -l datalyptica.io/component=master -n datalyptica --tail=50

# Access Spark UI
SPARK_UI=$(oc get route spark-master -n datalyptica -o jsonpath='{.spec.host}')
echo "Spark Master UI: https://${SPARK_UI}"
```

### Expected Output

```
NAME                               READY   STATUS    RESTARTS   AGE
spark-master-6979974cd-8hm4m       1/1     Running   0          5m
spark-worker-7f8d94dd9c-9d7w5      1/1     Running   0          5m
spark-worker-7f8d94dd9c-dvxv9      1/1     Running   0          5m
spark-worker-7f8d94dd9c-gk9hb      1/1     Running   0          5m
spark-worker-7f8d94dd9c-k6wb8      1/1     Running   0          5m
spark-worker-7f8d94dd9c-xfdm6      1/1     Running   0          5m
```

### Spark Configuration Highlights

```yaml
# Master Configuration
replicas: 1
strategy:
  type: Recreate  # Ensures single master at a time

# Worker Configuration
replicas: 5
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 1

# Pod Anti-Affinity (workers spread across nodes)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: datalyptica.io/component
            operator: In
            values:
            - worker
        topologyKey: kubernetes.io/hostname

# PodDisruptionBudgets
spark-master-pdb:
  minAvailable: 1
spark-worker-pdb:
  minAvailable: 3  # Ensures 3/5 workers always available
```

---

## Apache Flink Deployment

### Kubernetes High Availability

Flink 2.1.0 is deployed with **Kubernetes HA** mode, providing:
- **2 JobManagers**: One active (leader), one standby
- **Leader Election**: Automatic via Kubernetes ConfigMaps
- **Failover Time (RTO)**: < 15 seconds
- **Checkpointing (RPO)**: 30 seconds (EXACTLY_ONCE)

### Deployment Configuration

**File**: `deploy/openshift/processing/flink-deployment.yaml`

**Key Specifications**:
- **JobManager**: 2 replicas (active/standby HA)
- **TaskManager**: 5 replicas (4 slots each = 20 total slots)
- **Image**: `image-registry.openshift-image-registry.svc:5000/datalyptica/flink-connectors:2.1.0`

### Deploy Flink

```bash
# Deploy Flink cluster
oc apply -f deploy/openshift/processing/flink-deployment.yaml -n datalyptica

# Deploy PodDisruptionBudgets
oc apply -f deploy/openshift/processing/flink-pdb.yaml -n datalyptica

# Verify deployment
oc get pods -l app.kubernetes.io/name=flink -n datalyptica
oc get svc,route -l app.kubernetes.io/name=flink -n datalyptica

# Check JobManager logs (look for leader election)
oc logs -l datalyptica.io/component=flink-jobmanager -n datalyptica --tail=100 | grep -i "leader"

# Access Flink Dashboard
FLINK_UI=$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')
echo "Flink Dashboard: https://${FLINK_UI}"
```

### Expected Output

```
NAME                                  READY   STATUS    RESTARTS   AGE
flink-jobmanager-7dbb5bd457-c9k8t     1/1     Running   0          5m
flink-jobmanager-7dbb5bd457-csv7j     1/1     Running   0          5m
flink-taskmanager-545968854-86fxj     1/1     Running   0          5m
flink-taskmanager-545968854-d78l8     1/1     Running   0          5m
flink-taskmanager-545968854-d96k5     1/1     Running   0          5m
flink-taskmanager-545968854-x7xl6     1/1     Running   0          5m
flink-taskmanager-545968854-xf5lq     1/1     Running   0          5m
```

### Flink HA Configuration Highlights

```yaml
# ConfigMap: flink-config
data:
  flink-conf.yaml: |
    # High Availability Configuration
    high-availability.type: kubernetes
    high-availability.storageDir: file:///opt/flink/ha
    high-availability.cluster-id: datalyptica-flink
    kubernetes.cluster-id: datalyptica-flink
    kubernetes.namespace: datalyptica
    
    # Checkpointing Configuration
    execution.checkpointing.interval: 30s
    execution.checkpointing.mode: EXACTLY_ONCE
    execution.checkpointing.timeout: 10min
    execution.checkpointing.tolerable-failed-checkpoints: 3
    state.backend: rocksdb
    state.checkpoints.dir: file:///opt/flink/checkpoints
    state.savepoints.dir: file:///opt/flink/savepoints

# JobManager Deployment
replicas: 2  # Active/standby for leader election

# Pod Anti-Affinity (spread across nodes)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: datalyptica.io/component
            operator: In
            values:
            - flink-jobmanager
        topologyKey: kubernetes.io/hostname

# PodDisruptionBudgets
flink-jobmanager-pdb:
  minAvailable: 1  # At least 1 JobManager always available
flink-taskmanager-pdb:
  minAvailable: 3  # At least 3/5 TaskManagers available
```

---

## High Availability Configuration

### Recovery Time Objective (RTO) & Recovery Point Objective (RPO)

| Component | RTO | RPO | Mechanism |
|-----------|-----|-----|-----------|
| **Spark Master** | ~30s | N/A (stateless) | Kubernetes automatic restart |
| **Spark Workers** | ~15s | N/A (stateless) | Rolling updates, PDB ensures 3/5 available |
| **Flink JobManager** | <15s | 30s | Kubernetes HA leader election + checkpointing |
| **Flink TaskManager** | ~20s | 30s | Automatic reconnection + state recovery |

### Pod Anti-Affinity Strategy

**Preferred** (not required) scheduling spreads pods across nodes:

```yaml
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  podAffinityTerm:
    topologyKey: kubernetes.io/hostname
```

**Benefits**:
- Survives single node failures
- Allows scheduling even if preference can't be met
- Better than `requiredDuringScheduling` for smaller clusters

### PodDisruptionBudgets

Ensures minimum availability during:
- Node maintenance
- Cluster upgrades
- Voluntary disruptions

```bash
# Verify PDBs
oc get pdb -n datalyptica

NAME                   MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
spark-master-pdb       1               N/A               0                     10m
spark-worker-pdb       3               N/A               2                     10m
flink-jobmanager-pdb   1               N/A               1                     10m
flink-taskmanager-pdb  3               N/A               2                     10m
```

### Health Check Configuration

**Balanced** health checks avoid false positives while maintaining quick detection:

| Component | Liveness | Readiness | Notes |
|-----------|----------|-----------|-------|
| Spark Master | 10s period, 30s initial | 5s period, 10s initial | HTTP probe on UI port |
| Spark Worker | 10s period, 30s initial | 5s period, 10s initial | HTTP probe on UI port |
| Flink JobManager | 10s period, 30s initial | 5s period, 10s initial | HTTP probe on REST API |
| Flink TaskManager | 30s period, 60s initial | 15s period, 30s initial | Exec probe (longer for stability) |

---

## Validation

### 1. Verify Pod Status

```bash
# Check all processing pods
oc get pods -l "app.kubernetes.io/name in (spark,flink)" -n datalyptica

# Expected: All Running with 1/1 READY
```

### 2. Test Spark Cluster

```bash
# Submit a test job
oc exec -it $(oc get pod -l datalyptica.io/component=master -n datalyptica -o jsonpath='{.items[0].metadata.name}') -n datalyptica -- \
  /opt/spark/bin/spark-submit \
  --master spark://spark-svc.datalyptica.svc.cluster.local:7077 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10

# Check Spark UI for completed job
```

### 3. Test Flink Cluster

```bash
# Check Flink cluster status via REST API
FLINK_API=$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')

# Get cluster overview
curl -s https://${FLINK_API}/overview | jq .

# Expected output should show:
# - taskmanagers: 5
# - slots-total: 20
# - slots-available: 20
# - jobs-running: 0

# Check JobManager leader
curl -s https://${FLINK_API}/jobmanager/config | jq -r '.[] | select(.key == "jobmanager.rpc.address") | .value'
```

### 4. Test Flink High Availability

```bash
# Get current leader JobManager
LEADER=$(oc get pods -l datalyptica.io/component=flink-jobmanager -n datalyptica -o json | \
  jq -r '.items[] | select(.metadata.annotations."leader.kubernetes.io/election" != null) | .metadata.name')

echo "Current leader: ${LEADER}"

# Delete leader pod to trigger failover
oc delete pod ${LEADER} -n datalyptica

# Monitor failover (should complete in <15 seconds)
time oc wait --for=condition=Ready pod -l datalyptica.io/component=flink-jobmanager -n datalyptica --timeout=30s

# Verify new leader elected
oc logs -l datalyptica.io/component=flink-jobmanager -n datalyptica --tail=20 | grep -i "leader"
```

### 5. Verify Iceberg Integration

```bash
# Test Spark with Iceberg catalog
oc exec -it $(oc get pod -l datalyptica.io/component=master -n datalyptica -o jsonpath='{.items[0].metadata.name}') -n datalyptica -- \
  /opt/spark/bin/spark-shell \
  --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog \
  --conf spark.sql.catalog.nessie.uri=http://nessie.datalyptica.svc:19120/api/v1 \
  --conf spark.sql.catalog.nessie.ref=main \
  --conf spark.sql.catalog.nessie.warehouse=s3://lakehouse/iceberg

# In Spark shell:
spark.sql("SHOW NAMESPACES IN nessie").show()
```

---

## Troubleshooting

### Common Issues

#### 1. ImagePullBackOff

**Symptom**: Pods stuck in `ImagePullBackOff`

**Solution**:
```bash
# Check if images exist
oc get imagestream spark-iceberg flink-connectors -n datalyptica

# If missing, build images
oc apply -f deploy/openshift/builds/processing-image-builds.yaml -n datalyptica
oc start-build spark-iceberg flink-connectors -n datalyptica

# Verify build completion
oc get builds -n datalyptica | grep -E "spark-iceberg|flink-connectors"
```

#### 2. Flink JobManager CrashLoopBackOff

**Symptom**: JobManagers continuously restarting

**Common Causes**:
- Missing `kubernetes.cluster-id` configuration
- Missing `kubernetes.namespace` configuration
- RBAC permissions for ConfigMap access

**Solution**:
```bash
# Check logs for specific error
oc logs -l datalyptica.io/component=flink-jobmanager -n datalyptica --tail=100

# Verify ConfigMap has required settings
oc get configmap flink-config -n datalyptica -o yaml | grep -E "cluster-id|namespace"

# Verify RBAC
oc get role,rolebinding,serviceaccount -l app.kubernetes.io/name=flink -n datalyptica
```

#### 3. Spark Workers Not Connecting

**Symptom**: Workers running but not showing in Spark UI

**Solution**:
```bash
# Check worker logs
oc logs -l datalyptica.io/component=worker -n datalyptica --tail=50

# Verify service DNS
oc exec -it $(oc get pod -l datalyptica.io/component=worker -n datalyptica -o jsonpath='{.items[0].metadata.name}') -n datalyptica -- \
  nslookup spark-svc.datalyptica.svc.cluster.local

# Check if workers are using correct master URL
oc get deployment spark-worker -n datalyptica -o yaml | grep -A 2 "spark://spark-svc"
```

#### 4. Flink TaskManagers Not Registering

**Symptom**: TaskManagers running but not visible in Flink Dashboard

**Solution**:
```bash
# Check TaskManager logs
oc logs -l datalyptica.io/component=flink-taskmanager -n datalyptica --tail=50

# Verify JobManager service
oc get svc flink-jobmanager -n datalyptica

# Check if TaskManagers can reach JobManager
oc exec -it $(oc get pod -l datalyptica.io/component=flink-taskmanager -n datalyptica -o jsonpath='{.items[0].metadata.name}') -n datalyptica -- \
  curl -s http://flink-jobmanager.datalyptica.svc:8081/overview
```

### Debug Commands

```bash
# Get all processing resources
oc get all -l "app.kubernetes.io/name in (spark,flink)" -n datalyptica

# Describe pod for events
oc describe pod <pod-name> -n datalyptica

# Check resource usage
oc top pods -l "app.kubernetes.io/name in (spark,flink)" -n datalyptica

# View all logs from a component
oc logs -l datalyptica.io/component=master -n datalyptica --tail=100 --follow
```

---

## Next Steps

**Recommended Next Steps**:

1. **Query Layer Deployment** (See: `DEPLOYMENT-06-QUERY.md`)
   - Deploy Trino for distributed SQL queries
   - Deploy ClickHouse for OLAP analytics
   - Configure Iceberg catalog integration

2. **Streaming Layer** (See: `DEPLOYMENT-07-STREAMING.md`)
   - Deploy Kafka for event streaming
   - Deploy Schema Registry
   - Configure Flink Kafka connectors

3. **Submit Your First Jobs**
   - Spark batch processing job
   - Flink streaming application
   - Iceberg table creation and queries

4. **Performance Tuning**
   - Adjust worker replicas based on workload
   - Configure checkpoint intervals
   - Optimize Iceberg table properties

**Documentation References**:
- [Apache Spark 3.5 Documentation](https://spark.apache.org/docs/3.5.7/)
- [Apache Flink 2.1 Documentation](https://nightlies.apache.org/flink/flink-docs-release-2.1/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/1.8.0/)

---

**Previous**: [Catalog Layer](DEPLOYMENT-04-CATALOG.md)  
**Next**: Query Layer (TBD)  
**Home**: [Deployment Guide Summary](DEPLOYMENT_GUIDES_SUMMARY.md)
