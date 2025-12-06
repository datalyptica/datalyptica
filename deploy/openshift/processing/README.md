# Processing Layer - Kubernetes Manifests

This directory contains production-ready Kubernetes manifests for deploying Apache Spark and Apache Flink in Kubernetes-native mode.

## 📁 Files

### Production Deployments

- **`spark-k8s-native-production.yaml`** - Complete Spark deployment with K8s native mode
  - Spark Submit Pod (job entry point)
  - Spark History Server
  - Dynamic executor allocation
  - Iceberg + Nessie catalog integration
  - ConfigMaps, RBAC, Services, PDBs

- **`flink-k8s-native-production.yaml`** - Complete Flink deployment with K8s native mode
  - Flink JobManager
  - Flink TaskManagers (2+ replicas)
  - RocksDB state backend
  - Kafka connectors
  - ConfigMaps, RBAC, Services, PDBs

### Supporting Files

- **`monitoring.yaml`** - Prometheus monitoring configuration
  - ServiceMonitors for metrics scraping
  - PodMonitors for pod-level metrics
  - PrometheusRules for alerting

- **`secrets-template.yaml`** - Secret templates
  - MinIO credentials
  - Nessie database credentials
  - Service authentication

### Legacy Files (Reference Only)

- `spark-k8s-native.yaml` - Previous version (use production version instead)
- `flink-k8s-native.yaml` - Previous version (use production version instead)
- `spark-deployment.yaml` - Standalone mode (deprecated)
- `flink-deployment.yaml` - Standalone mode (deprecated)
- `*.yaml.bak` - Backup files

## 🚀 Quick Start

### Automated Deployment (Recommended)

```bash
# From project root
./scripts/init-processing-layer.sh
```

### Manual Deployment

```bash
# 1. Create namespace
kubectl create namespace datalyptica

# 2. Create secrets (update credentials!)
kubectl create secret generic minio-credentials \
  --from-literal=root-user=minio \
  --from-literal=root-password=YOUR_SECURE_PASSWORD \
  -n datalyptica

# 3. Deploy Spark
kubectl apply -f spark-k8s-native-production.yaml

# 4. Deploy Flink
kubectl apply -f flink-k8s-native-production.yaml

# 5. (Optional) Deploy monitoring
kubectl apply -f monitoring.yaml

# 6. Validate deployment
../../scripts/validate-processing-layer.sh
```

## 📖 Documentation

- **Comprehensive Guide**: [../docs/PROCESSING_LAYER_DEPLOYMENT_GUIDE.md](../../docs/PROCESSING_LAYER_DEPLOYMENT_GUIDE.md)
- **Quick Reference**: [../docs/PROCESSING_LAYER_QUICK_REF.md](../../docs/PROCESSING_LAYER_QUICK_REF.md)
- **Implementation Summary**: [../docs/PROCESSING_LAYER_SUMMARY.md](../../docs/PROCESSING_LAYER_SUMMARY.md)

## 🔍 What's Included

### Spark Components

| Resource | Description |
|----------|-------------|
| ConfigMap | Spark configuration with Iceberg/Nessie integration |
| ServiceAccount | RBAC for driver pod to spawn executors |
| Role + RoleBinding | Permissions to create/manage pods |
| Deployment | Spark Submit pod (1 replica) |
| Deployment | Spark History Server (1 replica) |
| Service | Spark History UI (port 18080) |
| PodDisruptionBudget | High availability protection |

### Flink Components

| Resource | Description |
|----------|-------------|
| ConfigMap | Flink configuration with Kafka/Iceberg connectors |
| ServiceAccount | RBAC for JobManager to spawn TaskManagers |
| Role + RoleBinding | Permissions to create/manage pods |
| Deployment | Flink JobManager (1 replica) |
| Deployment | Flink TaskManagers (2+ replicas) |
| Service | JobManager RPC (port 6123) |
| Service | JobManager REST/UI (port 8081) |
| Service | TaskManager headless service |
| PodDisruptionBudget | High availability protection (2x) |

## 🎯 Key Features

### Architecture

- **Kubernetes-Native**: True K8s integration (not containerized standalone)
- **Dynamic Scaling**: Automatic executor/TaskManager allocation
- **High Availability**: PodDisruptionBudgets, restart policies
- **Production-Ready**: Resource limits, health checks, monitoring

### Storage Integration

- **Apache Iceberg**: Open table format for data lake
- **Project Nessie**: Git-like catalog versioning
- **MinIO**: S3-compatible object storage
- **Checkpointing**: State persistence to S3/MinIO

### Monitoring

- **Prometheus**: Metrics collection via ServiceMonitors
- **Alerting**: Pre-configured alert rules
- **Grafana**: Dashboard-ready (import from community)

### Security

- **Non-root Containers**: Spark (UID 185), Flink (UID 1000)
- **RBAC**: Least-privilege service accounts
- **Secrets**: Credential management via Kubernetes Secrets
- **Security Contexts**: Pod-level security policies

## ⚙️ Configuration

### Resource Limits (Default)

```yaml
# Spark
spark.driver.memory: 4g
spark.executor.memory: 4g
spark.dynamicAllocation.maxExecutors: 10

# Flink
jobmanager.memory.process.size: 2048m
taskmanager.memory.process.size: 4096m
taskmanager.numberOfTaskSlots: 4
```

### Storage Paths

```yaml
# Spark
spark.eventLog.dir: s3a://lakehouse/spark-event-logs
spark.history.fs.logDirectory: s3a://lakehouse/spark-event-logs

# Flink
state.checkpoints.dir: s3://lakehouse/flink/checkpoints
state.savepoints.dir: s3://lakehouse/flink/savepoints
```

## 🧪 Testing

### Submit Test Jobs

**Spark**:
```bash
kubectl exec -it -n datalyptica $(kubectl get pod -n datalyptica -l app.kubernetes.io/name=spark,app.kubernetes.io/component=submit -o jsonpath='{.items[0].metadata.name}') -- spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode cluster \
  --name spark-pi \
  --conf spark.kubernetes.namespace=datalyptica \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 1000
```

**Flink**:
```bash
kubectl exec -it -n datalyptica $(kubectl get pod -n datalyptica -l app.kubernetes.io/name=flink,app.kubernetes.io/component=jobmanager -o jsonpath='{.items[0].metadata.name}') -- flink run -d /opt/flink/examples/streaming/WordCount.jar
```

## 🔧 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n datalyptica -l datalyptica.io/tier=processing
```

### View Logs
```bash
# Spark
kubectl logs -n datalyptica -l app.kubernetes.io/name=spark -f

# Flink
kubectl logs -n datalyptica -l app.kubernetes.io/name=flink -f
```

### Access UIs
```bash
# Spark History Server
kubectl port-forward -n datalyptica svc/spark-history-svc 18080:18080

# Flink Web UI
kubectl port-forward -n datalyptica svc/flink-jobmanager-rest 8081:8081
```

## 📦 Prerequisites

Before deploying, ensure these are running:

- ✅ Kubernetes cluster (v1.24+) or OpenShift
- ✅ MinIO (object storage)
- ✅ Nessie (catalog service)
- ✅ Kafka (for Flink streaming - optional)
- ✅ Prometheus Operator (for monitoring - optional)

## 🔄 Updates

To update configuration:

```bash
# Edit ConfigMap
kubectl edit configmap spark-k8s-config -n datalyptica
kubectl edit configmap flink-k8s-config -n datalyptica

# Restart pods
kubectl rollout restart deployment spark-submit -n datalyptica
kubectl rollout restart deployment flink-jobmanager -n datalyptica
kubectl rollout restart deployment flink-taskmanager -n datalyptica
```

## 🗑️ Cleanup

```bash
# Delete Spark
kubectl delete -f spark-k8s-native-production.yaml

# Delete Flink
kubectl delete -f flink-k8s-native-production.yaml

# Delete monitoring
kubectl delete -f monitoring.yaml

# Delete secrets (if needed)
kubectl delete secret minio-credentials -n datalyptica
```

## 📞 Support

- **Full Documentation**: `../../docs/PROCESSING_LAYER_DEPLOYMENT_GUIDE.md`
- **Quick Reference**: `../../docs/PROCESSING_LAYER_QUICK_REF.md`
- **Examples**: `../../docs/examples/`
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions

---

**Version**: 1.0.0  
**Last Updated**: December 2024  
**Status**: Production-Ready ✅
