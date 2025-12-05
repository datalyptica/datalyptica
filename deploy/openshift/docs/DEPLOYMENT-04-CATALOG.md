# Deployment Guide 04: Catalog Layer

## Overview

The **Catalog Layer** provides unified metadata management and data cataloging services for the Datalyptica platform. This layer is built on **Project Nessie**, which implements Git-like versioning for data lakes.

**Components**:
- **Nessie**: Catalog server with ACID transactions, branching, and time-travel

**Dependencies**:
- ✅ Storage Layer (PostgreSQL for metadata, MinIO for object storage)
- ✅ Application secrets (nessie-db-credentials, nessie-minio-credentials)

---

## Component Status

| Component | Status | Deployment Type | Replicas | Storage | Configuration |
|-----------|--------|----------------|----------|---------|---------------|
| **Nessie** | ✅ Deployed | Deployment | 3/3 Running | PostgreSQL (nessie DB) + MinIO (lakehouse) | HA with pod anti-affinity, PDB |

**Current Console Access:**
```bash
# Get Nessie API URL
echo "Nessie API: https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')"

# Check Nessie health
curl -s https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')/q/health
```

---

## Table of Contents

1. [Architecture](#architecture)
2. [Nessie Catalog](#nessie-catalog)
3. [Validation](#validation)
4. [Troubleshooting](#troubleshooting)
5. [Next Steps](#next-steps)

---

## Architecture

### Catalog Layer Design

```
┌────────────────────────────────────────────────────────────┐
│                    CATALOG LAYER                           │
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Nessie Catalog                      │    │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐│    │
│  │  │  nessie-0  │  │  nessie-1  │  │  nessie-2  ││    │
│  │  │   (pod)    │  │   (pod)    │  │   (pod)    ││    │
│  │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘│    │
│  │        │               │               │        │    │
│  │        └───────────────┴───────────────┘        │    │
│  │                        │                        │    │
│  │                        ▼                        │    │
│  │               ┌────────────────┐                │    │
│  │               │  Load Balancer │                │    │
│  │               │  (K8s Service) │                │    │
│  │               └────────┬───────┘                │    │
│  └────────────────────────┼───────────────────────┘    │
│                            │                            │
└────────────────────────────┼────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            ▼                                 ▼
    ┌──────────────┐                 ┌──────────────┐
    │  PostgreSQL  │                 │    MinIO     │
    │   (nessie)   │                 │  (lakehouse) │
    │   Metadata   │                 │    Tables    │
    └──────────────┘                 └──────────────┘
```

### High Availability Configuration

**Nessie HA Features**:
- **3 Replicas**: Ensures availability during pod failures
- **Pod Anti-Affinity**: Spreads pods across different nodes (preferred)
- **Rolling Updates**: Zero-downtime deployments (maxUnavailable=0, maxSurge=1)
- **Pod Disruption Budget**: Maintains minimum 2 replicas during maintenance
- **Shared Backend**: All replicas use same PostgreSQL database (stateless application)
- **Health Checks**: Liveness and readiness probes on `/q/health/*` endpoints

**Backend Storage**:
- **PostgreSQL**: 3-node CNPG cluster with streaming replication
- **MinIO**: 4-node distributed cluster with EC:2

---

## Nessie Catalog

### Purpose

Project Nessie provides:
- **Git-like Versioning**: Branch, tag, and merge data lake tables
- **ACID Transactions**: Atomic commits across multiple tables
- **Time Travel**: Query data as it existed at any point in time
- **Catalog API**: REST and Iceberg REST catalog endpoints
- **Multi-table Transactions**: Consistent snapshots across tables

### Architecture Components

**Nessie Service**: 3 replicas for HA
- **Backend**: PostgreSQL (JDBC version store)
- **Object Storage**: MinIO (table data and metadata files)
- **Catalog**: Iceberg REST catalog with S3-compatible storage

### Deployment Configuration

**File**: `deploy/openshift/catalog/nessie-deployment.yaml`

**Key Configuration**:
```yaml
---
# Nessie ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: nessie-config
  namespace: datalyptica
data:
  application.properties: |
    # Server
    quarkus.http.port=19120
    quarkus.http.cors=true
    
    # JDBC Backend
    nessie.version.store.type=JDBC
    quarkus.datasource.jdbc.url=jdbc:postgresql://datalyptica-postgres-rw.datalyptica.svc.cluster.local:5432/nessie
    
    # Catalog
    nessie.catalog.default-warehouse=warehouse
    nessie.catalog.warehouses.warehouse.location=s3://lakehouse/
    
    # S3/MinIO
    nessie.catalog.service.s3.default-options.endpoint=http://minio.datalyptica.svc.cluster.local:9000
    nessie.catalog.service.s3.default-options.path-style-access=true
---
# Nessie Deployment (3 replicas with HA)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nessie
  namespace: datalyptica
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - nessie
              topologyKey: kubernetes.io/hostname
      containers:
      - name: nessie
        image: ghcr.io/projectnessie/nessie:0.77.1
        ports:
        - containerPort: 19120
          name: http
        env:
        - name: QUARKUS_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: nessie-db-credentials
              key: username
        - name: QUARKUS_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: nessie-db-credentials
              key: password
        - name: QUARKUS_CONFIG_SECRET_S3_DEFAULT_NAME
          valueFrom:
            secretKeyRef:
              name: nessie-minio-credentials
              key: access-key
        - name: QUARKUS_CONFIG_SECRET_S3_DEFAULT_SECRET
          valueFrom:
            secretKeyRef:
              name: nessie-minio-credentials
              key: secret-key
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nessie
  namespace: datalyptica
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: nessie
```

### Deployment Commands

```bash
# Apply Nessie deployment
oc apply -f deploy/openshift/catalog/nessie-deployment.yaml

# Wait for all replicas to be ready
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=nessie -n datalyptica --timeout=300s

# Verify all pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=nessie
```

**Expected Output**:
```
NAME                      READY   STATUS    RESTARTS   AGE
nessie-67fb6b9f4f-fzgj9   1/1     Running   0          2m
nessie-67fb6b9f4f-hsgmd   1/1     Running   0          2m
nessie-67fb6b9f4f-qx8vh   1/1     Running   0          2m
```

### Validation

```bash
# 1. Check pod status
oc get pods -n datalyptica -l app.kubernetes.io/name=nessie

# 2. Get Nessie URL
NESSIE_URL="https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')"
echo "Nessie API: $NESSIE_URL"

# 3. Check health endpoint
curl -s $NESSIE_URL/q/health | jq

# Expected output:
# {
#   "status": "UP",
#   "checks": [
#     {
#       "name": "Database connections health check",
#       "status": "UP"
#     }
#   ]
# }

# 4. Check Nessie API version
curl -s $NESSIE_URL/api/v2/config | jq

# 5. List default branches
curl -s $NESSIE_URL/api/v2/trees | jq

# Expected: Should show "main" branch by default

# 6. Verify database connection
PG_PRIMARY=$(oc get pod -n datalyptica -l role=primary -o jsonpath='{.items[0].metadata.name}')
oc exec $PG_PRIMARY -n datalyptica -- psql -U nessie -d nessie -c "\dt"

# Should show Nessie tables (refs, commits, etc.)

# 7. Check pod distribution across nodes
oc get pods -n datalyptica -l app.kubernetes.io/name=nessie -o wide

# Pods should be spread across different nodes (if multiple nodes available)
```

---

## Validation

### Complete Catalog Layer Validation

```bash
# 1. Verify all Nessie pods are running
oc get pods -n datalyptica -l app.kubernetes.io/name=nessie

# Expected: 3/3 pods Running

# 2. Check PodDisruptionBudget
oc get pdb nessie -n datalyptica

# Expected: ALLOWED DISRUPTIONS = 1 (ensures 2 pods always available)

# 3. Verify service and route
oc get svc nessie -n datalyptica
oc get route nessie -n datalyptica

# 4. Test Nessie REST API
NESSIE_URL="https://$(oc get route nessie -n datalyptica -o jsonpath='{.spec.host}')"
curl -s $NESSIE_URL/q/health
curl -s $NESSIE_URL/api/v2/config

# 5. Verify database connectivity
PG_PRIMARY=$(oc get pod -n datalyptica -l role=primary -o jsonpath='{.items[0].metadata.name}')
oc exec $PG_PRIMARY -n datalyptica -- psql -U nessie -d nessie -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';"

# Should show Nessie schema tables

# 6. Verify MinIO connectivity
NESSIE_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=nessie -o jsonpath='{.items[0].metadata.name}')
oc exec $NESSIE_POD -n datalyptica -- curl -s http://minio.datalyptica.svc.cluster.local:9000/minio/health/live

# Expected: HTTP 200 OK

# 7. Test failover (delete one pod and verify service continuity)
oc delete pod -n datalyptica -l app.kubernetes.io/name=nessie --field-selector metadata.name=$(oc get pod -n datalyptica -l app.kubernetes.io/name=nessie -o jsonpath='{.items[0].metadata.name}')

# Wait a few seconds
sleep 5

# Verify service still responds
curl -s $NESSIE_URL/q/health

# Verify pod count returns to 3
oc get pods -n datalyptica -l app.kubernetes.io/name=nessie
```

### Catalog Layer Checklist

- [ ] Nessie pods running (3/3)
- [ ] Nessie database created in PostgreSQL
- [ ] Nessie user and permissions granted
- [ ] nessie-db-credentials secret created
- [ ] nessie-minio-credentials secret created
- [ ] Nessie service created (ClusterIP)
- [ ] Nessie route created (HTTPS)
- [ ] Health endpoint responding (UP status)
- [ ] API v2 endpoint accessible
- [ ] Database tables initialized
- [ ] MinIO connectivity verified
- [ ] Pod anti-affinity working (pods on different nodes)
- [ ] PodDisruptionBudget active (minAvailable=2)
- [ ] Failover tested (pod deletion recovers)

---

## Troubleshooting

### Nessie Pods Not Starting

**Issue**: Pods stuck in `CreateContainerConfigError`

```bash
# Check pod events
oc describe pod -n datalyptica -l app.kubernetes.io/name=nessie

# Common causes:
# 1. Missing nessie-db-credentials secret
oc get secret nessie-db-credentials -n datalyptica

# 2. Missing nessie-minio-credentials secret
oc get secret nessie-minio-credentials -n datalyptica

# 3. Database not created
PG_PRIMARY=$(oc get pod -n datalyptica -l role=primary -o jsonpath='{.items[0].metadata.name}')
oc exec $PG_PRIMARY -n datalyptica -- psql -U postgres -c "\l nessie"
```

**Solution**: Ensure secrets and database are created (see DEPLOYMENT-01-PREREQUISITES.md)

### Database Connection Errors

**Issue**: Nessie logs show database connection failures

```bash
# Check Nessie logs
oc logs -n datalyptica -l app.kubernetes.io/name=nessie --tail=50

# Verify PostgreSQL is accessible
oc get cluster datalyptica-postgres -n datalyptica

# Test connection from Nessie pod
NESSIE_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=nessie -o jsonpath='{.items[0].metadata.name}')
oc exec $NESSIE_POD -n datalyptica -- nc -zv datalyptica-postgres-rw 5432

# Verify credentials
oc get secret nessie-db-credentials -n datalyptica -o jsonpath='{.data.username}' | base64 -d
```

**Solution**: Verify PostgreSQL cluster is healthy and credentials are correct

### MinIO Connection Errors

**Issue**: Nessie cannot access MinIO

```bash
# Check MinIO pods
oc get pods -n datalyptica -l app.kubernetes.io/name=minio

# Test MinIO connectivity from Nessie pod
NESSIE_POD=$(oc get pod -n datalyptica -l app.kubernetes.io/name=nessie -o jsonpath='{.items[0].metadata.name}')
oc exec $NESSIE_POD -n datalyptica -- curl -s http://minio.datalyptica.svc.cluster.local:9000/minio/health/live

# Verify MinIO credentials
oc get secret nessie-minio-credentials -n datalyptica -o jsonpath='{.data.access-key}' | base64 -d
```

**Solution**: Ensure MinIO is running and credentials match

---

## Next Steps

With the Catalog Layer deployed, proceed to:

1. **Streaming Layer Deployment** (See: `DEPLOYMENT-05-STREAMING.md`)
   - Deploy Kafka cluster with Strimzi operator
   - Configure topics and replication
   - Set up Kafka Connect

2. **Processing Layer Deployment** (See: `DEPLOYMENT-05-PROCESSING.md`)
   - Deploy Spark 3.5.7 for batch processing with Iceberg 1.10.0
   - Deploy Flink 2.1.0 for stream processing with Kubernetes HA
   - Configure Nessie integration

3. **Query Layer Deployment** (See: `DEPLOYMENT-07-QUERY.md`)
   - Deploy Trino for SQL queries
   - Deploy ClickHouse for analytics
   - Configure Nessie catalog access

---

**Catalog Layer Deployment Complete!** ✅

The Nessie catalog service is now running with HA configuration, ready to provide metadata management for the data lakehouse.
