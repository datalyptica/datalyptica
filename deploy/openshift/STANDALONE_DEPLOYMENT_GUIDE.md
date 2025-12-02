# Standalone Deployment Guide

This guide covers deploying Datalyptica in **standalone mode** for development, testing, and demo environments.

## Overview

Standalone deployments use:

- **Single replica** for all services (replicas: 1)
- **Reduced resource requests/limits** (50% of HA configuration)
- **Relaxed anti-affinity** (preferredDuringScheduling instead of required)
- **No PodDisruptionBudgets** (not needed for single replicas)
- **Standard storage class** (instead of fast-ssd)
- **Simplified clustering** (single-node mode where applicable)

## Architecture Differences

| Aspect         | HA Mode           | Standalone Mode |
| -------------- | ----------------- | --------------- |
| Replicas       | 2-3+ per service  | 1 per service   |
| Anti-affinity  | Required          | Preferred/None  |
| PDBs           | Yes               | No              |
| Storage        | fast-ssd          | standard        |
| Resources      | Full (production) | 50% (dev/test)  |
| Failover       | Automatic         | Manual restart  |
| Data Loss Risk | Low               | Medium-High     |

## Prerequisites

- OpenShift cluster (single node acceptable)
- Minimum resources: 16 CPU cores, 32 GB RAM
- Storage: 500 GB standard persistent storage
- Network: Internal cluster networking only

## Quick Start

### 1. Create Namespaces

\`\`\`bash
oc create namespace datalyptica-storage
oc create namespace datalyptica-control
oc create namespace datalyptica-data
oc create namespace datalyptica-management
oc create namespace datalyptica-infrastructure

# Label namespaces for NetworkPolicies

oc label namespace datalyptica-storage name=datalyptica-storage
oc label namespace datalyptica-control name=datalyptica-control
oc label namespace datalyptica-data name=datalyptica-data
oc label namespace datalyptica-management name=datalyptica-management
oc label namespace datalyptica-infrastructure name=datalyptica-infrastructure
\`\`\`

### 2. Create Secrets

\`\`\`bash

# PostgreSQL credentials

oc create secret generic postgresql-credentials \\
--from-literal=username=admin \\
--from-literal=password=change-me-password \\
--from-literal=postgres_password=change-me-postgres \\
--from-literal=replication_password=change-me-replication \\
-n datalyptica-storage

# MinIO credentials

oc create secret generic minio-credentials \\
--from-literal=access-key=minioadmin \\
--from-literal=secret-key=minioadmin123 \\
-n datalyptica-storage

# Redis password

oc create secret generic redis-credentials \\
--from-literal=password=change-me-redis \\
-n datalyptica-infrastructure

# Add more secrets as needed for other services

\`\`\`

### 3. Deploy Services

Deploy in order by layer:

\`\`\`bash

# Storage Layer

oc apply -k deploy/openshift/standalone/storage/postgresql
oc apply -k deploy/openshift/standalone/storage/minio

# Control Layer

oc apply -k deploy/openshift/standalone/control/kafka
oc apply -k deploy/openshift/standalone/control/schema-registry
oc apply -k deploy/openshift/standalone/control/kafka-connect

# Data Layer

oc apply -k deploy/openshift/standalone/data/nessie
oc apply -k deploy/openshift/standalone/data/trino
oc apply -k deploy/openshift/standalone/data/spark
oc apply -k deploy/openshift/standalone/data/flink
oc apply -k deploy/openshift/standalone/data/clickhouse
oc apply -k deploy/openshift/standalone/data/dbt

# Management Layer

oc apply -k deploy/openshift/standalone/management/prometheus
oc apply -k deploy/openshift/standalone/management/grafana
oc apply -k deploy/openshift/standalone/management/loki
oc apply -k deploy/openshift/standalone/management/alertmanager
oc apply -k deploy/openshift/standalone/management/alloy
oc apply -k deploy/openshift/standalone/management/kafka-ui

# Infrastructure Layer

oc apply -k deploy/openshift/standalone/infrastructure/keycloak
oc apply -k deploy/openshift/standalone/infrastructure/redis

# Analytics Layer

oc apply -k deploy/openshift/standalone/analytics/airflow
oc apply -k deploy/openshift/standalone/analytics/jupyterhub
oc apply -k deploy/openshift/standalone/analytics/mlflow
oc apply -k deploy/openshift/standalone/analytics/superset
oc apply -k deploy/openshift/standalone/analytics/great-expectations
\`\`\`

### 4. Verify Deployment

\`\`\`bash

# Check all pods

oc get pods -A | grep datalyptica

# Check services

oc get svc -A | grep datalyptica

# Check routes

oc get routes -A | grep datalyptica
\`\`\`

### 5. Access Services

Access via OpenShift Routes:

- **Grafana**: https://grafana.apps.cluster.local
- **Trino UI**: https://trino.apps.cluster.local
- **MinIO Console**: https://minio-console.apps.cluster.local
- **Kafka UI**: https://kafka-ui.apps.cluster.local
- **JupyterHub**: https://jupyter.apps.cluster.local
- **Superset**: https://superset.apps.cluster.local
- **Airflow**: https://airflow.apps.cluster.local
- **Keycloak**: https://keycloak.apps.cluster.local
- **MLflow**: https://mlflow.apps.cluster.local
- **Prometheus**: https://prometheus.apps.cluster.local

## Converting Standalone to HA

### Automated Conversion

\`\`\`bash

# Use the migration script

./deploy/openshift/scripts/switch-to-ha.sh
\`\`\`

### Manual Conversion Steps

1. **Scale up replicas**:
   \`\`\`bash
   oc scale statefulset postgresql --replicas=3 -n datalyptica-storage
   oc scale deployment grafana --replicas=2 -n datalyptica-management

# ... repeat for all services

\`\`\`

2. **Apply PodDisruptionBudgets**:
   \`\`\`bash
   oc apply -k deploy/openshift/ha/storage/postgresql/pdb.yaml

# ... for all services

\`\`\`

3. **Update resource limits**:
   Edit deployments to use full resource specifications.

4. **Update storage class**:
   For new deployments, update PVCs to use `fast-ssd`.

5. **Update anti-affinity rules**:
   Edit pod specs to use `requiredDuringSchedulingIgnoredDuringExecution`.

## Troubleshooting

### Pod Won't Start

\`\`\`bash

# Check pod status

oc describe pod <pod-name> -n <namespace>

# Check logs

oc logs <pod-name> -n <namespace>

# Check events

oc get events -n <namespace> --sort-by='.lastTimestamp'
\`\`\`

### Out of Resources

Standalone mode requires minimum 16 CPU / 32 GB RAM. If insufficient:

\`\`\`bash

# Reduce resource requests further

# Edit deployment.yaml and reduce resources by another 50%

\`\`\`

### Storage Issues

\`\`\`bash

# Check PVC status

oc get pvc -A | grep datalyptica

# Check storage class

oc get storageclass

# If no standard storage class, create one or update manifests

\`\`\`

### Networking Issues

\`\`\`bash

# Test connectivity between pods

oc run -it --rm debug --image=busybox --restart=Never -- sh

# Inside pod:

# wget -O- http://postgresql.datalyptica-storage:5432

# Check NetworkPolicies

oc get networkpolicies -A
\`\`\`

## Performance Tuning

### Reduce PostgreSQL Memory

Edit `deploy/openshift/standalone/storage/postgresql/configmap.yaml`:
\`\`\`yaml
shared_buffers: 128MB # Instead of 256MB
effective_cache_size: 512MB # Instead of 1GB
\`\`\`

### Reduce JVM Heap Sizes

For Kafka, Spark, Flink, reduce memory allocations:
\`\`\`yaml
env:

- name: JAVA_OPTS
  value: "-Xms256m -Xmx512m" # Instead of -Xms512m -Xmx1g
  \`\`\`

## Backup and Recovery

### Backup

\`\`\`bash

# PostgreSQL backup

oc exec -it postgresql-0 -n datalyptica-storage -- pg_dump -U admin datalyptica > backup.sql

# MinIO backup

mc mirror minio/datalyptica ./backup/minio/
\`\`\`

### Recovery

\`\`\`bash

# PostgreSQL restore

cat backup.sql | oc exec -i postgresql-0 -n datalyptica-storage -- psql -U admin datalyptica

# MinIO restore

mc mirror ./backup/minio/ minio/datalyptica
\`\`\`

## Limitations

1. **No automatic failover** - Manual pod restart required on failure
2. **Single point of failure** - Any pod failure affects availability
3. **No rolling updates** - Downtime during updates
4. **Limited scalability** - Cannot handle high concurrent load
5. **Data loss risk** - Single storage replica only

## Use Cases

✅ **Good for**:

- Development environments
- Testing and QA
- Proof of concepts
- Demos and presentations
- Learning and training
- CI/CD pipelines

❌ **Not suitable for**:

- Production workloads
- Business-critical data
- High availability requirements
- Large-scale data processing
- Multi-tenant environments

## Next Steps

- For production, see [HA_DEPLOYMENT_GUIDE.md](HA_DEPLOYMENT_GUIDE.md)
- Configure monitoring alerts
- Set up backup schedules
- Plan migration to HA mode
