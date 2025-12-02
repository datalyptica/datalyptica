# Datalyptica OpenShift Deployment - Complete Package Summary

**Date:** December 1, 2025  
**Version:** 1.0.0  
**Status:** Ready for Deployment

---

## 📦 Package Contents

This package provides everything needed to deploy the Datalyptica (Datalyptica Data Lakehouse) platform on Red Hat OpenShift Container Platform with High Availability.

### Documentation (4 files)

```
docs/
├── OPENSHIFT_DEPLOYMENT_GUIDE.md         # Main deployment guide (Sections 1-8)
├── OPENSHIFT_DEPLOYMENT_GUIDE_PART2.md   # Compute layer deployment (Sections 8.4-9.5)
├── OPENSHIFT_DEPLOYMENT_GUIDE_PART3.md   # (To be created: Observability, security, ops)
└── TECHNOLOGY_STACK.md                   # Existing platform specifications
```

### Deployment Manifests

```
openshift/
├── README.md                             # Deployment overview
├── namespaces/
│   ├── kustomization.yaml
│   ├── namespaces.yaml                   # 5 namespaces
│   ├── resource-quotas.yaml              # Resource limits
│   └── limit-ranges.yaml                 # Container defaults
├── operators/                            # Operator installations
├── storage/                              # PostgreSQL, MinIO configs
├── control/                              # Kafka, Schema Registry
├── data/                                 # Trino, Spark, Flink, Nessie, ClickHouse
├── management/                           # Grafana, Prometheus, Keycloak, Loki
├── security/                             # NetworkPolicies, RBAC
├── networking/                           # Routes, Ingress
└── scripts/
    ├── 01-generate-secrets.sh            # Generate all passwords/keys
    ├── 02-create-secrets.sh              # Create Kubernetes secrets
    ├── 03-install-operators.sh           # Install required operators
    ├── deploy-all.sh                     # Complete automated deployment
    ├── validate-deployment.sh            # Post-deployment validation
    └── uninstall.sh                      # Clean uninstall script
```

---

## 🚀 Quick Start Guide

### Prerequisites Check

Before starting, ensure you have:

- [x] **OpenShift cluster 4.13+** with cluster-admin access
- [x] **oc CLI** installed and configured
- [x] **kubectl** installed (optional but recommended)
- [x] **Minimum cluster**: 8 nodes (3 control, 5 workers)
- [x] **Storage classes** configured (fast-ssd, standard)
- [x] **50GB+ free space** on local machine (for secrets, temp files)

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd datalyptica
```

### Step 2: Login to OpenShift

```bash
# Login to your OpenShift cluster
oc login https://api.your-cluster.com:6443

# Verify cluster access
oc whoami
oc cluster-info

# Check available storage classes
oc get storageclass
```

### Step 3: Generate Secrets

```bash
cd deploy/openshift
./scripts/01-generate-secrets.sh
```

**IMPORTANT:**

- Secrets are generated in `./openshift-secrets/`
- Backup these secrets immediately to a secure vault
- This directory is git-ignored for security

### Step 4: Deploy Platform

#### Option A: Complete Automated Deployment (Recommended)

```bash
./scripts/deploy-all.sh
```

**Note:** All commands assume you're in the `deploy/openshift/` directory.

This script will:

1. Create all namespaces
2. Create all secrets in OpenShift
3. Install required operators
4. Deploy storage layer (PostgreSQL, MinIO)
5. Deploy control layer (Kafka, Schema Registry)
6. Deploy data layer (Trino, Spark, Flink, Nessie, ClickHouse)
7. Deploy management layer (Grafana, Prometheus, Keycloak, Loki)
8. Configure security and networking

**Estimated time:** 30-60 minutes

#### Option B: Manual Step-by-Step Deployment

```bash
# 1. Create namespaces
oc apply -k namespaces/

# 2. Create secrets
./scripts/02-create-secrets.sh

# 3. Install operators
./scripts/03-install-operators.sh

# 4. Deploy storage layer
oc apply -k storage/

# 5. Deploy control layer
oc apply -k control/

# 6. Deploy data layer
oc apply -k data/

# 7. Deploy management layer
oc apply -k management/

# 8. Configure security & networking
oc apply -k security/
oc apply -k networking/
```

### Step 5: Validate Deployment

```bash
./scripts/validate-deployment.sh
```

This will check:

- ✅ All namespaces created
- ✅ All operators running
- ✅ All pods in Running state
- ✅ All services created
- ✅ Routes/Ingress configured

### Step 6: Access Services

#### Get Routes/URLs

```bash
# List all routes
oc get routes -n datalyptica-management

# Get Grafana URL
oc get route grafana -n datalyptica-management -o jsonpath='{.spec.host}'

# Get Keycloak URL
oc get route keycloak -n datalyptica-management -o jsonpath='{.spec.host}'
```

#### Get Credentials

```bash
# Grafana
cat ./openshift-secrets/grafana_admin_user
cat ./openshift-secrets/grafana_admin_password

# Keycloak
cat ./openshift-secrets/keycloak_admin_user
cat ./openshift-secrets/keycloak_admin_password

# PostgreSQL
cat ./openshift-secrets/postgres_password

# MinIO
cat ./openshift-secrets/minio_access_key
cat ./openshift-secrets/minio_secret_key
```

---

## 📊 Platform Architecture

### Namespaces

| Namespace                  | Purpose              | Components                                        | Resource Quota         |
| -------------------------- | -------------------- | ------------------------------------------------- | ---------------------- |
| **datalyptica-operators**  | Operator deployments | CloudNativePG, Strimzi, MinIO operators           | N/A (system)           |
| **datalyptica-storage**    | Storage layer        | PostgreSQL (3 replicas), MinIO (4+ nodes)         | 32 CPU, 128GB RAM, 5TB |
| **datalyptica-control**    | Streaming/messaging  | Kafka (3 brokers), Schema Registry, Connect       | 24 CPU, 64GB RAM, 2TB  |
| **datalyptica-data**       | Data processing      | Trino, Spark, Flink, Nessie, ClickHouse, dbt      | 64 CPU, 256GB RAM, 1TB |
| **datalyptica-management** | Monitoring/IAM       | Grafana, Prometheus, Loki, Keycloak, Alertmanager | 16 CPU, 64GB RAM, 1TB  |

### Components Overview

#### Storage Layer (datalyptica-storage)

- **PostgreSQL** (CloudNativePG): 3-node HA cluster with automatic failover
- **MinIO**: Distributed object storage (4+ nodes, EC:4 erasure coding)

#### Control Layer (datalyptica-control)

- **Kafka**: 3-broker cluster (KRaft mode, no ZooKeeper)
- **Schema Registry**: Avro schema management (2 replicas)
- **Kafka Connect**: CDC and integrations (2 replicas)

#### Data Layer (datalyptica-data)

- **Nessie**: Git-like data catalog (3 replicas)
- **Trino**: SQL query engine (2 coordinators, 3+ workers)
- **Spark**: Batch processing (2 masters, 3+ workers)
- **Flink**: Stream processing (2 JobManagers, 3+ TaskManagers)
- **ClickHouse**: OLAP database (3 replicas, sharded)
- **dbt**: SQL transformations (1 replica)

#### Management Layer (datalyptica-management)

- **Prometheus**: Metrics collection (2 replicas, HA)
- **Grafana**: Dashboards (2 replicas)
- **Loki**: Log aggregation (3 replicas, distributed)
- **Alertmanager**: Alert routing (3 replicas, cluster)
- **Keycloak**: IAM/SSO (2 replicas)

---

## 🔧 Operational Commands

### Monitoring

```bash
# Watch all pods
oc get pods --all-namespaces -l platform=datalyptica -w

# Check pod logs
oc logs -f deployment/nessie -n datalyptica-data

# Check operator status
oc get csv -n datalyptica-operators

# Check cluster resources
oc get cluster postgresql-ha -n datalyptica-storage
oc get kafka datalyptica-kafka -n datalyptica-control
oc get tenant datalyptica-minio -n datalyptica-storage
```

### Scaling

```bash
# Scale Trino workers
oc scale deployment trino-worker --replicas=5 -n datalyptica-data

# Scale Spark workers
oc scale deployment spark-worker --replicas=5 -n datalyptica-data

# Scale Flink TaskManagers
oc scale deployment flink-taskmanager --replicas=5 -n datalyptica-data
```

### Troubleshooting

```bash
# Describe pod for events
oc describe pod <pod-name> -n <namespace>

# Get pod logs (previous instance)
oc logs <pod-name> -n <namespace> --previous

# Execute command in pod
oc exec -it <pod-name> -n <namespace> -- /bin/bash

# Check resource usage
oc top pods -n datalyptica-data
oc top nodes

# Check storage
oc get pvc --all-namespaces -l platform=datalyptica
```

---

## 📝 Configuration Files

### Key ConfigMaps

All configuration is managed via ConfigMaps and can be edited:

```bash
# Trino configuration
oc edit configmap trino-config -n datalyptica-data

# Spark configuration
oc edit configmap spark-config -n datalyptica-data

# Prometheus configuration
oc edit configmap prometheus-config -n datalyptica-management
```

### Secrets Management

Secrets are stored in Kubernetes secrets:

```bash
# List all secrets
oc get secrets -n datalyptica-storage

# View secret (base64 encoded)
oc get secret postgresql-credentials -n datalyptica-storage -o yaml

# Decode secret value
oc get secret postgresql-credentials -n datalyptica-storage \
  -o jsonpath='{.data.postgres-password}' | base64 -d
```

---

## 🔒 Security Features

### Network Policies

Network isolation between namespaces:

- Storage layer: Restricted access (only from data/control layers)
- Control layer: Kafka accessible from data/management layers
- Data layer: Services accessible from management layer
- Management layer: Web UIs exposed via Routes with TLS

### RBAC

Role-based access control:

- **cluster-admin**: Full platform access
- **platform-admin**: Datalyptica namespaces only
- **developer**: Read/write in data namespace
- **viewer**: Read-only access

### TLS/SSL

All internal communication encrypted:

- PostgreSQL: TLS connections
- Kafka: SSL/TLS listeners
- MinIO: HTTPS endpoints
- All Routes: TLS termination

---

## 📈 Performance Tuning

### PostgreSQL

```yaml
# CloudNativePG Cluster spec
postgresql:
  parameters:
    max_connections: "500"
    shared_buffers: "4GB"
    effective_cache_size: "12GB"
    work_mem: "10MB"
```

### Kafka

```yaml
# Kafka config
config:
  num.io.threads: 8
  num.network.threads: 3
  log.retention.hours: 168
  default.replication.factor: 3
```

### MinIO

```yaml
# MinIO tenant
pools:
  - servers: 4
    volumesPerServer: 4
    resources:
      requests:
        cpu: "2"
        memory: "8Gi"
```

---

## 🔄 Backup & Recovery

### PostgreSQL Backups

Automated backups to MinIO:

```bash
# Check backup status
oc get backup -n datalyptica-storage

# Trigger manual backup
cat <<EOF | oc apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M%S)
  namespace: datalyptica-storage
spec:
  cluster:
    name: postgresql-ha
EOF

# Restore from backup
# See: docs/OPENSHIFT_DEPLOYMENT_GUIDE.md Section 16
```

### MinIO Data

MinIO versioning enabled by default:

- Object versioning: Enabled
- Lifecycle policies: Configured
- Replication: EC:4 (survives 4 drive failures)

---

## 🚨 Troubleshooting Guide

### Common Issues

#### Issue: Pods stuck in Pending

```bash
# Check events
oc get events -n <namespace> --sort-by='.lastTimestamp'

# Check resource quotas
oc describe resourcequota -n <namespace>

# Check storage
oc get pvc -n <namespace>
```

#### Issue: PostgreSQL not ready

```bash
# Check cluster status
oc get cluster postgresql-ha -n datalyptica-storage

# Check pods
oc get pods -n datalyptica-storage -l cnpg.io/cluster=postgresql-ha

# View logs
oc logs postgresql-ha-1 -n datalyptica-storage
```

#### Issue: Kafka not starting

```bash
# Check Kafka status
oc get kafka datalyptica-kafka -n datalyptica-control

# Check ZooKeeper (if applicable)
oc get pods -n datalyptica-control -l strimzi.io/name=datalyptica-kafka-zookeeper

# View operator logs
oc logs -n datalyptica-operators deployment/strimzi-cluster-operator
```

---

## 📚 Additional Resources

### Documentation

- **Main Guide**: [docs/OPENSHIFT_DEPLOYMENT_GUIDE.md](docs/OPENSHIFT_DEPLOYMENT_GUIDE.md)
- **Part 2**: [docs/OPENSHIFT_DEPLOYMENT_GUIDE_PART2.md](docs/OPENSHIFT_DEPLOYMENT_GUIDE_PART2.md)
- **Technology Stack**: [docs/TECHNOLOGY_STACK.md](docs/TECHNOLOGY_STACK.md)
- **Architecture Review**: [docs/ARCHITECTURE_REVIEW.md](docs/ARCHITECTURE_REVIEW.md)

### External Documentation

- **OpenShift**: https://docs.openshift.com/
- **CloudNativePG**: https://cloudnative-pg.io/documentation/
- **Strimzi**: https://strimzi.io/documentation/
- **MinIO Operator**: https://min.io/docs/minio/kubernetes/upstream/
- **Apache Iceberg**: https://iceberg.apache.org/docs/latest/
- **Project Nessie**: https://projectnessie.org/
- **Trino**: https://trino.io/docs/current/
- **Apache Spark**: https://spark.apache.org/docs/latest/
- **Apache Flink**: https://nightlies.apache.org/flink/

---

## ✅ Deployment Checklist

### Pre-Deployment

- [ ] OpenShift cluster ready (4.13+)
- [ ] Cluster-admin access verified
- [ ] oc CLI installed
- [ ] Storage classes available
- [ ] Sufficient cluster resources
- [ ] Network policies supported

### Deployment

- [ ] Namespaces created
- [ ] Secrets generated and created
- [ ] Operators installed
- [ ] Storage layer deployed
- [ ] Control layer deployed
- [ ] Data layer deployed
- [ ] Management layer deployed
- [ ] Security configured
- [ ] Routes created

### Post-Deployment

- [ ] Validation script passed
- [ ] All pods Running
- [ ] Services accessible
- [ ] Routes working with TLS
- [ ] Credentials documented
- [ ] Monitoring dashboards configured
- [ ] Backups configured
- [ ] Alert rules configured

### Production Readiness

- [ ] Performance testing completed
- [ ] Failover testing completed
- [ ] Backup/restore tested
- [ ] Security scan passed
- [ ] Documentation reviewed
- [ ] Team training completed
- [ ] On-call procedures defined
- [ ] Runbooks created

---

## 🤝 Support

### Getting Help

1. **Check logs**: `oc logs -f <pod-name> -n <namespace>`
2. **Check events**: `oc get events -n <namespace>`
3. **Run validation**: `./scripts/validate-deployment.sh`
4. **Review documentation**: See docs/ directory

### Reporting Issues

When reporting issues, include:

- OpenShift version: `oc version`
- Cluster info: `oc cluster-info`
- Pod status: `oc get pods -n <namespace>`
- Pod logs: `oc logs <pod-name> -n <namespace>`
- Events: `oc get events -n <namespace>`

---

## 📄 License

Proprietary - Internal Use Only

---

## 📝 Change Log

### Version 1.0.0 (December 1, 2025)

- Initial OpenShift deployment package
- Complete documentation suite
- Automated deployment scripts
- HA configuration for all components
- Security hardening
- Monitoring and observability stack

---

**End of Summary**

For detailed step-by-step instructions, see [docs/OPENSHIFT_DEPLOYMENT_GUIDE.md](docs/OPENSHIFT_DEPLOYMENT_GUIDE.md)
