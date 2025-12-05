# Datalyptica OpenShift Deployment Guide

**Platform Version**: 4.0  
**Last Updated**: December 5, 2025  
**Deployment Method**: Step-by-Step Layer Approach  
**Status**: ✅ Production-Ready | Tested on OpenShift 4.19.19

---

## 📋 Quick Start

This is a **complete, tested deployment guide** for the Datalyptica Data Platform on Red Hat OpenShift. Follow the guides in order for first-time deployment success.

### Prerequisites Checklist

Before starting:
- [ ] OpenShift cluster 4.17+ with admin access
- [ ] Storage class available (block storage recommended)
- [ ] Cluster has internet access for pulling images
- [ ] `oc` CLI installed and authenticated
- [ ] At least 3 worker nodes (for HA configurations)

### Deployment Time Estimate

| Phase | Component | Time | Complexity |
|-------|-----------|------|------------|
| 1 | Prerequisites & Setup | 15-30 min | Easy |
| 2 | Operators | 30-45 min | Easy |
| 3 | Storage Layer | 45-60 min | Medium |
| 4 | Catalog Layer | 20-30 min | Easy |
| 5 | Processing Layer | 60-90 min | Medium |
| **Total** | **Full Platform** | **3-4 hours** | **Medium** |

---

## 📚 Deployment Guides (In Order)

### Phase 1: Prerequisites & Planning
**[DEPLOYMENT-01-PREREQUISITES.md](./DEPLOYMENT-01-PREREQUISITES.md)**

What you'll do:
- ✅ Verify OpenShift cluster readiness
- ✅ Create `datalyptica` namespace
- ✅ Configure storage classes
- ✅ Set up network policies
- ✅ Configure RBAC and service accounts
- ✅ Enable internal image registry (for custom builds)

**Time**: 15-30 minutes  
**Critical**: Must complete before proceeding

---

### Phase 2: Operator Installation
**[DEPLOYMENT-02-OPERATORS.md](./DEPLOYMENT-02-OPERATORS.md)**

What you'll do:
- ✅ Install Strimzi Kafka Operator
- ✅ Install Crunchy PostgreSQL Operator
- ✅ Install ClickHouse Operator (optional)
- ✅ Verify operator readiness

**Time**: 30-45 minutes  
**Note**: Operators manage the lifecycle of platform components

---

### Phase 3: Storage Layer
**[DEPLOYMENT-03-STORAGE.md](./DEPLOYMENT-03-STORAGE.md)**

What you'll deploy:
- ✅ **MinIO** - S3-compatible object storage (4 replicas, 800Gi)
- ✅ **PostgreSQL** - Relational database with Crunchy operator (3 replicas, 600Gi)
- ✅ **Redis** - Cache and message broker (3+3 replicas, 150Gi)

**Time**: 45-60 minutes  
**Total Storage**: ~1.5TB

**Verification Steps**:
```bash
# All pods should be Running
oc get pods -l datalyptica.io/tier=storage -n datalyptica

# Access MinIO console
echo "MinIO: https://$(oc get route minio-console -n datalyptica -o jsonpath='{.spec.host}')"
```

---

### Phase 4: Catalog Layer
**[DEPLOYMENT-04-CATALOG.md](./DEPLOYMENT-04-CATALOG.md)**

What you'll deploy:
- ✅ **Nessie** - Git-like catalog for Iceberg tables (3 replicas)

**Time**: 20-30 minutes

**Verification Steps**:
```bash
# Check Nessie health
curl -s https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')/q/health

# Should return: {"status":"UP"}
```

---

### Phase 5: Processing & Streaming Layer
**[DEPLOYMENT-05-PROCESSING.md](./DEPLOYMENT-05-PROCESSING.md)**

What you'll deploy:
- ✅ **Apache Spark 3.5.7** - Batch processing with Iceberg 1.8.0
  - 1 Master + 5 Workers
  - Custom image with pre-installed connectors
  - Pod anti-affinity for HA
  - PodDisruptionBudgets ensuring 3/5 workers always available

- ✅ **Apache Flink 2.1.0** - Stream processing with Kubernetes HA
  - 2 JobManagers (active/standby with leader election)
  - 5 TaskManagers (20 slots total)
  - Custom image with Kafka 3.4.0 and Iceberg 1.8.0 connectors
  - S3 filesystem plugin
  - RTO < 15s, RPO = 30s
  - EXACTLY_ONCE checkpointing

**Time**: 60-90 minutes (includes building custom images)

**Verification Steps**:
```bash
# Check all processing pods
oc get pods -l "app.kubernetes.io/name in (spark,flink)" -n datalyptica

# Access Spark UI
echo "Spark: https://$(oc get route spark-master -n datalyptica -o jsonpath='{.spec.host}')"

# Access Flink Dashboard
echo "Flink: https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')"

# Verify Flink HA (should show 2 JobManagers, 5 TaskManagers)
curl -s https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')/overview | jq .
```

---

## 🎯 Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATALYPTICA PLATFORM                         │
│                    Namespace: datalyptica                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              PROCESSING & STREAMING TIER                 │  │
│  │  • Spark 3.5.7 (1M + 5W) + Flink 2.1.0 (2JM + 5TM)     │  │
│  │  • Iceberg 1.8.0 table format                           │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │                  CATALOG TIER                            │  │
│  │  • Nessie 0.105.7 (3 replicas)                          │  │
│  │  • Git-like versioning for data                         │  │
│  └───────────────────────┬──────────────────────────────────┘  │
│                          │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │                  STORAGE TIER                            │  │
│  │  • MinIO (4 replicas, 800Gi) - Object storage          │  │
│  │  • PostgreSQL (3 replicas, 600Gi) - Metadata           │  │
│  │  • Redis (3+3 replicas, 150Gi) - Cache                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 INFRASTRUCTURE                           │  │
│  │  • OpenShift 4.19+ | Kubernetes 1.30+                   │  │
│  │  • Internal Image Registry (for custom builds)          │  │
│  │  • StorageClass: 9500-storageclass (IBM Block)         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Deployed Component Versions

| Component | Version | Configuration | Status |
|-----------|---------|---------------|--------|
| **MinIO** | 2025-10-15 | 4 replicas, 200Gi each | ✅ Tested |
| **PostgreSQL** | 16.6 | 3 replicas (Crunchy), 200Gi each | ✅ Tested |
| **Redis** | 8.4.0 | 3 servers + 3 sentinels, 50Gi each | ✅ Tested |
| **Nessie** | 0.105.7 | 3 replicas, HA with PDB | ✅ Tested |
| **Spark** | 3.5.7 | 1 master + 5 workers, Iceberg 1.8.0 | ✅ Tested |
| **Flink** | 2.1.0 | 2 JobManagers + 5 TaskManagers, K8s HA | ✅ Tested |
| **Iceberg** | 1.8.0 | Certified with Spark 3.5.x & Flink 2.1.x | ✅ Tested |

**Total Resources**:
- **Pods**: ~40 (including replicas)
- **Storage**: ~1.5TB
- **CPU**: ~50 cores (requests)
- **Memory**: ~120GB (requests)

---

## 🔍 Verification Checklist

After completing all phases, verify the platform is healthy:

### 1. Check All Pods

```bash
# All pods should be Running or Completed
oc get pods -n datalyptica

# Expected pod count: ~40 pods
oc get pods -n datalyptica --no-headers | wc -l
```

### 2. Check Storage

```bash
# All PVCs should be Bound
oc get pvc -n datalyptica

# Expected: 10 PVCs (4 MinIO + 3 PostgreSQL + 3 Redis)
```

### 3. Check Services and Routes

```bash
# List all exposed services
oc get routes -n datalyptica

# Should include:
# - minio-console
# - nessie
# - spark-master
# - flink-jobmanager
```

### 4. Functional Tests

```bash
# Test MinIO access
mc alias set datalyptica https://$(oc get route minio-console -n datalyptica -o jsonpath='{.spec.host}') admin <password>
mc ls datalyptica

# Test Nessie catalog
curl -s https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')/api/v1/trees | jq .

# Test Spark cluster
oc exec -it $(oc get pod -l datalyptica.io/component=master -n datalyptica -o jsonpath='{.items[0].metadata.name}') -n datalyptica -- \
  /opt/spark/bin/spark-submit \
  --master spark://spark-svc.datalyptica.svc.cluster.local:7077 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10

# Test Flink cluster
curl -s https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')/overview | jq .
# Should show: taskmanagers: 5, slots-total: 20
```

---

## 🛠️ Custom Image Builds

Both Spark and Flink use **custom-built images** stored in OpenShift's internal registry:

### Why Custom Images?

- ✅ **Faster startup**: 10s vs 2+ minutes (no init containers)
- ✅ **Reliability**: Pre-validated connector versions
- ✅ **Consistency**: Same image across all pods
- ✅ **Certified plugins**: Iceberg 1.8.0 certified for both engines

### Building Images

```bash
# Enable internal registry (done in Phase 1)
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type merge \
  --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'

# Create BuildConfigs
oc apply -f deploy/openshift/builds/processing-image-builds.yaml -n datalyptica

# Trigger builds
oc start-build spark-iceberg -n datalyptica --follow
oc start-build flink-connectors -n datalyptica --follow

# Verify images
oc get imagestream spark-iceberg flink-connectors -n datalyptica
```

**Build Times**:
- Spark: ~1m30s
- Flink: ~1m45s

---

## 🔒 High Availability Features

### Spark HA
- **Master**: Single replica with Kubernetes auto-restart (~30s RTO)
- **Workers**: 5 replicas with PodDisruptionBudget (minAvailable: 3)
- **Pod Anti-Affinity**: Spreads workers across nodes
- **Health Checks**: Liveness 10s, Readiness 5s

### Flink HA
- **JobManager**: 2 replicas with Kubernetes leader election (<15s RTO)
- **TaskManager**: 5 replicas with PodDisruptionBudget (minAvailable: 3)
- **Checkpointing**: EXACTLY_ONCE, 30s interval (RPO: 30s)
- **State Backend**: RocksDB with local filesystem (configurable to S3)
- **Pod Anti-Affinity**: Spreads pods across nodes

### Storage HA
- **MinIO**: Distributed mode with 4 nodes (EC:2)
- **PostgreSQL**: Streaming replication with 3 replicas (Crunchy operator)
- **Redis**: Sentinel configuration with 3 servers + 3 sentinels (quorum: 2)

---

## 📖 Additional Documentation

### Reference Documents

- **[COMPONENT-VERSIONS.md](./COMPONENT-VERSIONS.md)** - Complete version matrix with breaking changes
- **[../../README.md](../../README.md)** - OpenShift deployment overview
- **[../../../docs/OPENSHIFT_DEPLOYMENT_CLI.md](../../../docs/OPENSHIFT_DEPLOYMENT_CLI.md)** - Alternative CLI-based guide (all-in-one)
- **[../../../docs/OPENSHIFT_DEPLOYMENT_QUICKSTART.md](../../../docs/OPENSHIFT_DEPLOYMENT_QUICKSTART.md)** - Quick reference guide

### Deployment Files

All deployment YAMLs are located in:
```
deploy/openshift/
├── builds/
│   └── processing-image-builds.yaml        # Spark & Flink BuildConfigs
├── catalog/
│   └── nessie-deployment.yaml              # Nessie catalog
├── processing/
│   ├── spark-deployment.yaml               # Spark cluster
│   ├── spark-pdb.yaml                      # Spark PodDisruptionBudgets
│   ├── flink-deployment.yaml               # Flink cluster (with HA)
│   └── flink-pdb.yaml                      # Flink PodDisruptionBudgets
└── storage/
    ├── minio-deployment.yaml               # MinIO object storage
    ├── postgresql-cluster.yaml             # PostgreSQL (Crunchy)
    └── redis-deployment.yaml               # Redis cache
```

---

## 🚨 Common Issues and Solutions

### Issue: ImagePullBackOff for custom images

**Cause**: Custom images not built yet

**Solution**:
```bash
# Check if images exist
oc get imagestream -n datalyptica

# If missing, build them
oc start-build spark-iceberg flink-connectors -n datalyptica

# Wait for completion (~3 minutes total)
oc get builds -w -n datalyptica
```

### Issue: Flink JobManager CrashLoopBackOff

**Cause**: Missing Kubernetes HA configuration

**Solution**:
```bash
# Verify flink-config ConfigMap has:
oc get configmap flink-config -n datalyptica -o yaml | grep -E "cluster-id|namespace"

# Should show:
#   kubernetes.cluster-id: datalyptica-flink
#   kubernetes.namespace: datalyptica
```

### Issue: Pods stuck in Pending

**Cause**: Insufficient resources or PVC not bound

**Solution**:
```bash
# Check node resources
oc describe nodes | grep -A 5 "Allocated resources"

# Check PVC status
oc get pvc -n datalyptica

# Check pod events
oc describe pod <pod-name> -n datalyptica
```

### Issue: Storage class not found

**Cause**: Wrong storage class name

**Solution**:
```bash
# List available storage classes
oc get storageclass

# Update all YAMLs to use your cluster's storage class
# Default in guides: 9500-storageclass
```

---

## 🎓 Next Steps After Deployment

1. **Deploy Query Layer**
   - Trino for distributed SQL queries
   - ClickHouse for OLAP analytics

2. **Deploy Streaming Layer**
   - Kafka with Strimzi operator
   - Schema Registry
   - Kafka Connect for CDC

3. **Deploy Analytics Tools**
   - Apache Airflow for orchestration
   - JupyterHub for notebooks
   - MLflow for ML experiments
   - Apache Superset for visualization

4. **Configure IAM**
   - Keycloak for identity management
   - LDAP/AD integration
   - OAuth2 SSO

5. **Set Up Monitoring**
   - Prometheus + Grafana
   - Loki for log aggregation
   - Alertmanager for notifications

---

## 📞 Support and Troubleshooting

### Debug Commands

```bash
# View all resources
oc get all -n datalyptica

# Check pod logs
oc logs <pod-name> -n datalyptica --tail=100

# Check pod events
oc get events -n datalyptica --sort-by='.lastTimestamp'

# Shell into pod
oc exec -it <pod-name> -n datalyptica -- bash

# Check resource usage
oc adm top nodes
oc adm top pods -n datalyptica
```

### Validation Script

```bash
#!/bin/bash
# validate-deployment.sh

echo "=== Datalyptica Deployment Validation ==="

echo -e "\n1. Checking pods..."
oc get pods -n datalyptica | grep -v Running | grep -v Completed && echo "❌ Some pods are not Running" || echo "✅ All pods Running"

echo -e "\n2. Checking PVCs..."
oc get pvc -n datalyptica | grep -v Bound && echo "❌ Some PVCs not Bound" || echo "✅ All PVCs Bound"

echo -e "\n3. Checking routes..."
oc get routes -n datalyptica -o custom-columns=NAME:.metadata.name,HOST:.spec.host --no-headers

echo -e "\n4. Testing MinIO..."
curl -sk https://$(oc get route minio-console -n datalyptica -o jsonpath='{.spec.host}') > /dev/null && echo "✅ MinIO accessible" || echo "❌ MinIO not accessible"

echo -e "\n5. Testing Nessie..."
curl -sk https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')/q/health | grep -q "UP" && echo "✅ Nessie healthy" || echo "❌ Nessie unhealthy"

echo -e "\n6. Testing Spark..."
oc get pods -l datalyptica.io/component=master -n datalyptica | grep -q Running && echo "✅ Spark master Running" || echo "❌ Spark master not Running"

echo -e "\n7. Testing Flink..."
curl -sk https://$(oc get route flink-jobmanager -n datalyptica -o jsonpath='{.spec.host}')/overview | grep -q "taskmanagers" && echo "✅ Flink cluster healthy" || echo "❌ Flink cluster unhealthy"

echo -e "\n=== Validation Complete ==="
```

---

## 📝 Changelog

### Version 4.0 (December 5, 2025)
- ✅ Updated to Spark 3.5.7 with Iceberg 1.8.0
- ✅ Updated to Flink 2.1.0 with Kubernetes HA
- ✅ Added custom image builds for faster startup
- ✅ Implemented PodDisruptionBudgets for HA
- ✅ Added pod anti-affinity configurations
- ✅ Optimized health check timings
- ✅ Certified plugin matrix (Spark 3.5.x + Flink 2.1.x + Iceberg 1.8.0)

### Version 3.0 (December 2025)
- ✅ Updated to PostgreSQL 16.6 with Crunchy 5.8.5
- ✅ Updated to Redis 8.4.0
- ✅ Updated to Nessie 0.105.7
- ✅ All versions verified from authoritative sources

---

**Ready to deploy?** Start with **[DEPLOYMENT-01-PREREQUISITES.md](./DEPLOYMENT-01-PREREQUISITES.md)** →
