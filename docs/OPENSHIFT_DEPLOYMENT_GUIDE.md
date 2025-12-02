# Datalyptica Platform - OpenShift Deployment Guide

**Document Version:** 1.0.0  
**Date:** December 1, 2025  
**Classification:** Production Deployment Manual  
**Platform:** Red Hat OpenShift Container Platform 4.13+

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Prerequisites](#2-prerequisites)
3. [Architecture Overview](#3-architecture-overview)
4. [Namespace Structure](#4-namespace-structure)
5. [Pre-Deployment Setup](#5-pre-deployment-setup)
6. [Storage Configuration](#6-storage-configuration)
7. [Operator Installation](#7-operator-installation)
8. [Core Services Deployment](#8-core-services-deployment)
9. [Compute Layer Deployment](#9-compute-layer-deployment)
10. [Observability Stack](#10-observability-stack)
11. [Security Configuration](#11-security-configuration)
12. [Networking and Ingress](#12-networking-and-ingress)
13. [Validation and Testing](#13-validation-and-testing)
14. [Operational Procedures](#14-operational-procedures)
15. [Monitoring and Alerting](#15-monitoring-and-alerting)
16. [Backup and Disaster Recovery](#16-backup-and-disaster-recovery)
17. [Troubleshooting](#17-troubleshooting)
18. [Appendices](#18-appendices)

---

## 1. Executive Summary

### 1.1 Deployment Overview

This guide provides step-by-step instructions for deploying the Datalyptica Data Lakehouse platform on Red Hat OpenShift Container Platform with High Availability (HA) configuration.

**Platform Characteristics:**

- **29 distinct services** across 5 namespaces
- **Highly Available** (3+ replicas for critical components)
- **Production-ready** with comprehensive monitoring
- **Secure by default** with NetworkPolicies and RBAC
- **Scalable** architecture supporting horizontal scaling

### 1.2 Deployment Timeline

| Phase                       | Duration        | Description                                   |
| --------------------------- | --------------- | --------------------------------------------- |
| **Phase 1: Pre-deployment** | 2-4 hours       | Infrastructure validation, namespace creation |
| **Phase 2: Operators**      | 1-2 hours       | Install and configure operators               |
| **Phase 3: Storage Layer**  | 2-3 hours       | PostgreSQL, MinIO deployment                  |
| **Phase 4: Data Services**  | 2-3 hours       | Kafka, Nessie, Catalog services               |
| **Phase 5: Compute Layer**  | 2-3 hours       | Trino, Spark, Flink, ClickHouse               |
| **Phase 6: Observability**  | 1-2 hours       | Prometheus, Grafana, Loki                     |
| **Phase 7: Validation**     | 2-4 hours       | End-to-end testing                            |
| **Total**                   | **12-21 hours** | Complete deployment                           |

### 1.3 Key Differences from Docker Compose

| Aspect            | Docker Compose        | OpenShift                       |
| ----------------- | --------------------- | ------------------------------- |
| **Orchestration** | Single host           | Multi-node cluster              |
| **HA**            | Manual (Patroni/etcd) | Operator-managed (StatefulSets) |
| **Networking**    | Bridge networks       | SDN with NetworkPolicies        |
| **Storage**       | Local volumes         | PVCs with dynamic provisioning  |
| **Security**      | Docker secrets        | OpenShift Secrets + SCC         |
| **Ingress**       | Port mapping          | Routes/Ingress                  |
| **Scaling**       | Manual                | Automatic (HPA)                 |

---

## 2. Prerequisites

### 2.1 OpenShift Cluster Requirements

#### Minimum Production Cluster

```
Control Plane: 3 nodes
  - 4 vCPU per node
  - 16 GB RAM per node
  - 120 GB disk per node

Worker Nodes: 5 nodes
  - 16 vCPU per node
  - 64 GB RAM per node
  - 500 GB SSD per node (OS + ephemeral)

Total: 8 nodes, 92 vCPU, 368 GB RAM
```

#### Storage Requirements

```
Storage Classes Required:
  - Fast SSD (block storage): For databases, Kafka
  - Standard (block storage): For logs, general use
  - Object Storage (S3-compatible): For data lake (MinIO or external)

Minimum Capacity:
  - Fast SSD: 2 TB (for PostgreSQL, Kafka, ClickHouse)
  - Standard: 1 TB (for logs, monitoring data)
  - Object Storage: 10 TB+ (for data lake)
```

#### Network Requirements

```
- OpenShift SDN or OVN-Kubernetes
- NetworkPolicy support enabled
- Ingress Controller (Router) deployed
- Internal DNS (CoreDNS)
- Load Balancer support (for external services)
- Bandwidth: 10 Gbps recommended between nodes
```

### 2.2 Software Prerequisites

#### OpenShift Version

| Distribution                 | Version | Status         |
| ---------------------------- | ------- | -------------- |
| Red Hat OpenShift            | 4.13+   | ✅ Recommended |
| OpenShift Container Platform | 4.14+   | ✅ Recommended |
| OKD (Community)              | 4.13+   | ⚠️ Tested      |

#### Required Operators

| Operator                | Version | Source      | Purpose                |
| ----------------------- | ------- | ----------- | ---------------------- |
| **CloudNativePG**       | 1.22+   | OperatorHub | PostgreSQL HA          |
| **Strimzi Kafka**       | 0.39+   | OperatorHub | Kafka cluster          |
| **MinIO Operator**      | 5.0+    | OperatorHub | Object storage         |
| **Prometheus Operator** | 0.70+   | Built-in    | Monitoring             |
| **Cert-Manager**        | 1.13+   | OperatorHub | Certificate management |

#### Client Tools

| Tool                   | Version         | Installation                 |
| ---------------------- | --------------- | ---------------------------- |
| **oc** (OpenShift CLI) | Matches cluster | `brew install openshift-cli` |
| **kubectl**            | Matches cluster | `brew install kubectl`       |
| **helm**               | 3.12+           | `brew install helm`          |
| **jq**                 | 1.6+            | `brew install jq`            |
| **yq**                 | 4.30+           | `brew install yq`            |

### 2.3 Access Requirements

#### Cluster Access

- [ ] OpenShift cluster admin credentials (`cluster-admin` role)
- [ ] Access to OpenShift Console
- [ ] CLI access configured (`oc login`)
- [ ] Ability to create namespaces/projects
- [ ] Ability to install operators

#### External Services

- [ ] Container registry access (for custom images)
- [ ] Internet access for pulling operator images
- [ ] DNS management (for custom domains)
- [ ] Certificate Authority (for SSL/TLS)

### 2.4 Pre-Deployment Checklist

```bash
# Verify cluster access
oc whoami
oc cluster-info

# Check cluster version
oc get clusterversion

# Verify available resources
oc describe nodes | grep -E "cpu|memory"

# Check storage classes
oc get storageclass

# Verify OperatorHub access
oc get packagemanifests -n openshift-marketplace

# Check if you can create namespaces
oc auth can-i create namespaces

# Verify NetworkPolicy support
oc get crd networkpolicies.networking.k8s.io
```

**All checks must pass before proceeding.**

---

## 3. Architecture Overview

### 3.1 High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    OPENSHIFT ROUTER / INGRESS                   │
│              (Routes for external access with TLS)              │
└────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
┌─────────▼──────────┐ ┌──────▼─────────┐ ┌──────▼──────────┐
│   datalyptica-management │ │   datalyptica-data   │ │  datalyptica-storage  │
│                    │ │                │ │                 │
│ • Grafana          │ │ • Trino        │ │ • PostgreSQL    │
│ • Keycloak         │ │ • Spark        │ │   (CloudNativePG)│
│ • Kafka UI         │ │ • Flink        │ │ • MinIO (HA)    │
│ • Prometheus       │ │ • Nessie       │ │                 │
│ • Alertmanager     │ │ • ClickHouse   │ │                 │
│ • Loki             │ │ • dbt          │ │                 │
└────────────────────┘ └────────────────┘ └─────────────────┘
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
                 ┌────────────▼────────────┐
                 │    datalyptica-control        │
                 │                         │
                 │  • Kafka (Strimzi)      │
                 │  • Schema Registry      │
                 │  • Kafka Connect        │
                 │  • ZooKeeper (if needed)│
                 └─────────────────────────┘
                              │
                 ┌────────────▼────────────┐
                 │    datalyptica-operators      │
                 │                         │
                 │  • CloudNativePG Op.    │
                 │  • Strimzi Op.          │
                 │  • MinIO Op.            │
                 │  • Cert-Manager         │
                 └─────────────────────────┘
```

### 3.2 Component Distribution

#### Namespace: `datalyptica-operators`

**Purpose:** Operator deployments  
**Components:** CloudNativePG Operator, Strimzi Operator, MinIO Operator, Cert-Manager

#### Namespace: `datalyptica-storage`

**Purpose:** Persistent storage services  
**Components:**

- PostgreSQL Cluster (CloudNativePG) - 3 instances
- MinIO Tenant - 4+ nodes (distributed)
- Persistent Volume Claims

**Resource Allocation:**

- CPU: 32 cores reserved
- Memory: 128 GB reserved
- Storage: 2 TB fast SSD

#### Namespace: `datalyptica-control`

**Purpose:** Message streaming and coordination  
**Components:**

- Kafka Cluster (Strimzi) - 3 brokers
- ZooKeeper (if not using KRaft) - 3 nodes
- Schema Registry - 2 replicas
- Kafka Connect - 2 replicas

**Resource Allocation:**

- CPU: 24 cores reserved
- Memory: 64 GB reserved
- Storage: 1 TB SSD

#### Namespace: `datalyptica-data`

**Purpose:** Data processing and query engines  
**Components:**

- Nessie - 3 replicas
- Trino Coordinator - 2 replicas
- Trino Workers - 3+ replicas (scalable)
- Spark Master - 2 replicas (active/standby)
- Spark Workers - 3+ replicas (scalable)
- Flink JobManager - 2 replicas (HA)
- Flink TaskManager - 3+ replicas (scalable)
- ClickHouse - 3 replicas (sharded)
- dbt - 1 replica

**Resource Allocation:**

- CPU: 64+ cores (scalable)
- Memory: 256+ GB (scalable)
- Storage: 500 GB SSD

#### Namespace: `datalyptica-management`

**Purpose:** Observability, IAM, and management interfaces  
**Components:**

- Keycloak - 2 replicas
- Grafana - 2 replicas
- Prometheus - 2 replicas (HA)
- Alertmanager - 3 replicas (cluster)
- Loki - 3 replicas (distributed)
- Alloy (Promtail) - DaemonSet
- Kafka UI - 2 replicas

**Resource Allocation:**

- CPU: 16 cores reserved
- Memory: 64 GB reserved
- Storage: 500 GB standard

### 3.3 High Availability Design

#### Database Layer (PostgreSQL)

```
CloudNativePG Cluster:
├── Primary Instance (read-write)
├── Standby Instance 1 (hot standby)
├── Standby Instance 2 (hot standby)
└── Automatic failover (<30s)

Features:
  - Streaming replication
  - Automatic failover
  - Connection pooling (PgBouncer integrated)
  - Backup to S3 (MinIO)
```

#### Messaging Layer (Kafka)

```
Strimzi Kafka Cluster:
├── Kafka Broker 1 (controller + broker)
├── Kafka Broker 2 (controller + broker)
├── Kafka Broker 3 (controller + broker)
└── KRaft mode (no ZooKeeper)

Configuration:
  - Replication factor: 3
  - Min in-sync replicas: 2
  - Rack awareness: Enabled
```

#### Object Storage (MinIO)

```
MinIO Tenant (Operator-managed):
├── Pool 1: 4 servers × 4 drives (16 drives)
├── Erasure coding: EC:4 (survives 4 drive failures)
├── Distributed locking
└── Load balanced access

Features:
  - Automatic healing
  - Versioning enabled
  - Encryption at rest
  - S3 API compatibility
```

#### Query Engines

```
Trino:
├── Coordinator 1 (active)
├── Coordinator 2 (standby)
└── Workers (3+ nodes, auto-scale)

Spark:
├── Master 1 (active)
├── Master 2 (standby via ZooKeeper)
└── Workers (3+ nodes, dynamic allocation)

Flink:
├── JobManager 1 (active)
├── JobManager 2 (standby)
└── TaskManagers (3+ nodes, slot-based)
```

---

## 4. Namespace Structure

### 4.1 Create Namespaces

Create all required namespaces with proper labels and annotations:

```bash
# Create namespace configuration file
cat <<EOF > namespaces.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica-operators
  labels:
    name: datalyptica-operators
    platform: datalyptica
    tier: operators
  annotations:
    openshift.io/description: "Datalyptica Platform Operators"
    openshift.io/display-name: "Datalyptica Operators"
---
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica-storage
  labels:
    name: datalyptica-storage
    platform: datalyptica
    tier: storage
  annotations:
    openshift.io/description: "Datalyptica Storage Layer (PostgreSQL, MinIO)"
    openshift.io/display-name: "Datalyptica Storage"
---
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica-control
  labels:
    name: datalyptica-control
    platform: datalyptica
    tier: control
  annotations:
    openshift.io/description: "Datalyptica Control Plane (Kafka, Schema Registry)"
    openshift.io/display-name: "Datalyptica Control"
---
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica-data
  labels:
    name: datalyptica-data
    platform: datalyptica
    tier: data
  annotations:
    openshift.io/description: "Datalyptica Data Layer (Trino, Spark, Flink)"
    openshift.io/display-name: "Datalyptica Data"
---
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica-management
  labels:
    name: datalyptica-management
    platform: datalyptica
    tier: management
  annotations:
    openshift.io/description: "Datalyptica Management (Monitoring, IAM)"
    openshift.io/display-name: "Datalyptica Management"
EOF

# Apply namespaces
oc apply -f namespaces.yaml

# Verify
oc get namespaces -l platform=datalyptica
```

### 4.2 Resource Quotas

Apply resource quotas to prevent resource exhaustion:

```bash
cat <<EOF > resource-quotas.yaml
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: datalyptica-storage-quota
  namespace: datalyptica-storage
spec:
  hard:
    requests.cpu: "32"
    requests.memory: "128Gi"
    limits.cpu: "64"
    limits.memory: "256Gi"
    persistentvolumeclaims: "50"
    requests.storage: "5Ti"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: datalyptica-control-quota
  namespace: datalyptica-control
spec:
  hard:
    requests.cpu: "24"
    requests.memory: "64Gi"
    limits.cpu: "48"
    limits.memory: "128Gi"
    persistentvolumeclaims: "30"
    requests.storage: "2Ti"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: datalyptica-data-quota
  namespace: datalyptica-data
spec:
  hard:
    requests.cpu: "64"
    requests.memory: "256Gi"
    limits.cpu: "128"
    limits.memory: "512Gi"
    persistentvolumeclaims: "20"
    requests.storage: "1Ti"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: datalyptica-management-quota
  namespace: datalyptica-management
spec:
  hard:
    requests.cpu: "16"
    requests.memory: "64Gi"
    limits.cpu: "32"
    limits.memory: "128Gi"
    persistentvolumeclaims: "20"
    requests.storage: "1Ti"
EOF

oc apply -f resource-quotas.yaml
```

### 4.3 Limit Ranges

Define default resource limits for containers:

```bash
cat <<EOF > limit-ranges.yaml
---
apiVersion: v1
kind: LimitRange
metadata:
  name: datalyptica-limits
  namespace: datalyptica-storage
spec:
  limits:
  - max:
      cpu: "16"
      memory: "64Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    default:
      cpu: "2"
      memory: "4Gi"
    defaultRequest:
      cpu: "1"
      memory: "2Gi"
    type: Container
  - max:
      storage: "1Ti"
    min:
      storage: "1Gi"
    type: PersistentVolumeClaim
---
apiVersion: v1
kind: LimitRange
metadata:
  name: datalyptica-limits
  namespace: datalyptica-control
spec:
  limits:
  - max:
      cpu: "8"
      memory: "32Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    default:
      cpu: "1"
      memory: "2Gi"
    defaultRequest:
      cpu: "500m"
      memory: "1Gi"
    type: Container
---
apiVersion: v1
kind: LimitRange
metadata:
  name: datalyptica-limits
  namespace: datalyptica-data
spec:
  limits:
  - max:
      cpu: "16"
      memory: "64Gi"
    min:
      cpu: "100m"
      memory: "256Mi"
    default:
      cpu: "2"
      memory: "4Gi"
    defaultRequest:
      cpu: "1"
      memory: "2Gi"
    type: Container
---
apiVersion: v1
kind: LimitRange
metadata:
  name: datalyptica-limits
  namespace: datalyptica-management
spec:
  limits:
  - max:
      cpu: "8"
      memory: "32Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    default:
      cpu: "1"
      memory: "2Gi"
    defaultRequest:
      cpu: "250m"
      memory: "512Mi"
    type: Container
EOF

oc apply -f limit-ranges.yaml
```

---

## 5. Pre-Deployment Setup

### 5.1 Generate Secrets

All passwords and keys must be generated before deployment:

```bash
#!/bin/bash
# File: generate-openshift-secrets.sh

set -e

SECRETS_DIR="./openshift-secrets"
mkdir -p $SECRETS_DIR

echo "Generating Datalyptica platform secrets..."

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# PostgreSQL
echo -n "$(generate_password)" > $SECRETS_DIR/postgres_password
echo -n "$(generate_password)" > $SECRETS_DIR/postgres_replication_password
echo -n "datalyptica" > $SECRETS_DIR/postgres_user
echo -n "$(generate_password)" > $SECRETS_DIR/datalyptica_password

# MinIO
echo -n "minioadmin" > $SECRETS_DIR/minio_root_user
echo -n "$(generate_password)" > $SECRETS_DIR/minio_root_password
echo -n "$(openssl rand -hex 20)" > $SECRETS_DIR/minio_access_key
echo -n "$(openssl rand -base64 40 | tr -d "=+/")" > $SECRETS_DIR/minio_secret_key

# Kafka
echo -n "$(generate_password)" > $SECRETS_DIR/kafka_admin_password
echo -n "$(generate_password)" > $SECRETS_DIR/schema_registry_password

# Keycloak
echo -n "admin" > $SECRETS_DIR/keycloak_admin_user
echo -n "$(generate_password)" > $SECRETS_DIR/keycloak_admin_password
echo -n "$(generate_password)" > $SECRETS_DIR/keycloak_db_password

# Monitoring
echo -n "admin" > $SECRETS_DIR/grafana_admin_user
echo -n "$(generate_password)" > $SECRETS_DIR/grafana_admin_password

# ClickHouse
echo -n "default" > $SECRETS_DIR/clickhouse_user
echo -n "$(generate_password)" > $SECRETS_DIR/clickhouse_password

# Nessie
echo -n "$(generate_password)" > $SECRETS_DIR/nessie_password

echo "Secrets generated in $SECRETS_DIR/"
echo "IMPORTANT: Store these secrets securely!"

# Display summary (without showing actual secrets)
echo ""
echo "Generated files:"
ls -1 $SECRETS_DIR/ | sed 's/^/  - /'
```

Run the script:

```bash
chmod +x generate-openshift-secrets.sh
./generate-openshift-secrets.sh
```

### 5.2 Create OpenShift Secrets

Create Kubernetes secrets from generated files:

```bash
#!/bin/bash
# File: create-openshift-secrets.sh

SECRETS_DIR="./openshift-secrets"

# Storage namespace
oc create secret generic postgresql-credentials \
  --from-file=postgres-password=$SECRETS_DIR/postgres_password \
  --from-file=replication-password=$SECRETS_DIR/postgres_replication_password \
  --from-file=datalyptica-password=$SECRETS_DIR/datalyptica_password \
  --namespace=datalyptica-storage

oc create secret generic minio-credentials \
  --from-file=root-user=$SECRETS_DIR/minio_root_user \
  --from-file=root-password=$SECRETS_DIR/minio_root_password \
  --from-file=access-key=$SECRETS_DIR/minio_access_key \
  --from-file=secret-key=$SECRETS_DIR/minio_secret_key \
  --namespace=datalyptica-storage

# Control namespace
oc create secret generic kafka-credentials \
  --from-file=admin-password=$SECRETS_DIR/kafka_admin_password \
  --from-file=schema-registry-password=$SECRETS_DIR/schema_registry_password \
  --namespace=datalyptica-control

# Data namespace
oc create secret generic nessie-credentials \
  --from-file=nessie-password=$SECRETS_DIR/nessie_password \
  --namespace=datalyptica-data

# Also create in data namespace for consumers
oc create secret generic minio-credentials \
  --from-file=root-user=$SECRETS_DIR/minio_root_user \
  --from-file=root-password=$SECRETS_DIR/minio_root_password \
  --from-file=access-key=$SECRETS_DIR/minio_access_key \
  --from-file=secret-key=$SECRETS_DIR/minio_secret_key \
  --namespace=datalyptica-data

oc create secret generic postgresql-credentials \
  --from-file=postgres-password=$SECRETS_DIR/postgres_password \
  --from-file=datalyptica-password=$SECRETS_DIR/datalyptica_password \
  --namespace=datalyptica-data

# Management namespace
oc create secret generic keycloak-credentials \
  --from-file=admin-user=$SECRETS_DIR/keycloak_admin_user \
  --from-file=admin-password=$SECRETS_DIR/keycloak_admin_password \
  --from-file=db-password=$SECRETS_DIR/keycloak_db_password \
  --namespace=datalyptica-management

oc create secret generic grafana-credentials \
  --from-file=admin-user=$SECRETS_DIR/grafana_admin_user \
  --from-file=admin-password=$SECRETS_DIR/grafana_admin_password \
  --namespace=datalyptica-management

oc create secret generic clickhouse-credentials \
  --from-file=user=$SECRETS_DIR/clickhouse_user \
  --from-file=password=$SECRETS_DIR/clickhouse_password \
  --namespace=datalyptica-data

# PostgreSQL for Keycloak
oc create secret generic postgresql-credentials \
  --from-file=postgres-password=$SECRETS_DIR/postgres_password \
  --from-file=keycloak-password=$SECRETS_DIR/keycloak_db_password \
  --namespace=datalyptica-management

echo "All secrets created successfully!"
```

Run the script:

```bash
chmod +x create-openshift-secrets.sh
./create-openshift-secrets.sh
```

Verify secrets:

```bash
oc get secrets -n datalyptica-storage | grep credentials
oc get secrets -n datalyptica-control | grep credentials
oc get secrets -n datalyptica-data | grep credentials
oc get secrets -n datalyptica-management | grep credentials
```

### 5.3 SSL/TLS Certificates

#### Option 1: Using cert-manager (Recommended)

```bash
# Install cert-manager operator (if not already installed)
oc apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: openshift-default
EOF

# Create self-signed issuer for internal services
cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

#### Option 2: Using OpenShift Service CA

OpenShift includes a built-in service CA for internal services:

```bash
# The service CA automatically creates certificates for services
# annotated with: service.beta.openshift.io/serving-cert-secret-name

# Example service with auto-generated cert:
apiVersion: v1
kind: Service
metadata:
  name: example-service
  annotations:
    service.beta.openshift.io/serving-cert-secret-name: example-tls
spec:
  ports:
  - name: https
    port: 443
    targetPort: 8443
  selector:
    app: example
```

---

## 6. Storage Configuration

### 6.1 Verify Storage Classes

Check available storage classes:

```bash
oc get storageclass

# Expected output (example):
# NAME                PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# fast-ssd (default)  kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer
# standard            kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer
# slow                kubernetes.io/aws-ebs   Delete          Immediate
```

If you need to create custom storage classes:

```yaml
# For fast SSD storage (databases, Kafka)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs # Change based on your provider
parameters:
  type: gp3 # AWS example
  iops: "10000"
  throughput: "500"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
---
# For standard storage (logs, monitoring)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

Apply if needed:

```bash
oc apply -f storage-classes.yaml
```

### 6.2 Pre-create PVCs (Optional)

For critical services, you can pre-create PVCs:

```yaml
# Example: PostgreSQL PVCs
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data-0
  namespace: datalyptica-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 500Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data-1
  namespace: datalyptica-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 500Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data-2
  namespace: datalyptica-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 500Gi
```

---

## 7. Operator Installation

### 7.1 Install CloudNativePG Operator

CloudNativePG provides PostgreSQL with HA:

```bash
# Method 1: Via OperatorHub (Recommended)
# Navigate to OpenShift Console > OperatorHub > Search "CloudNativePG"
# Click Install, select namespace: datalyptica-operators

# Method 2: Via CLI
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cloudnativepg
  namespace: datalyptica-operators
spec:
  channel: stable
  name: cloudnativepg
  source: operatorhubio-catalog
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator to be ready
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=cloudnative-pg -n datalyptica-operators --timeout=300s

# Verify installation
oc get csv -n datalyptica-operators | grep cloudnativepg
oc api-resources | grep postgresql.cnpg.io
```

### 7.2 Install Strimzi Kafka Operator

```bash
# Method 1: Via OperatorHub (Recommended)
# OpenShift Console > OperatorHub > Search "Strimzi" > Install

# Method 2: Via CLI
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: strimzi-kafka-operator
  namespace: datalyptica-operators
spec:
  channel: stable
  name: strimzi-kafka-operator
  source: operatorhubio-catalog
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator
oc wait --for=condition=Ready pod -l name=strimzi-cluster-operator -n datalyptica-operators --timeout=300s

# Verify
oc get csv -n datalyptica-operators | grep strimzi
oc api-resources | grep kafka.strimzi.io
```

### 7.3 Install MinIO Operator

```bash
# Method 1: Via OperatorHub
# OpenShift Console > OperatorHub > Search "MinIO Operator" > Install

# Method 2: Via kubectl/oc
kubectl apply -k github.com/minio/operator

# Or manually:
kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/resources/kustomization.yaml

# Wait for operator
oc wait --for=condition=Ready pod -l name=minio-operator -n minio-operator --timeout=300s

# Verify
oc get pods -n minio-operator
oc api-resources | grep minio.min.io
```

### 7.4 Verify All Operators

```bash
# Check all installed operators
oc get csv -n datalyptica-operators

# Expected output:
# NAME                            DISPLAY              VERSION   REPLACES   PHASE
# cloudnativepg.v1.22.0           CloudNativePG        1.22.0               Succeeded
# strimzi-cluster-operator.v0.39  Strimzi              0.39.0               Succeeded
# minio-operator.v5.0.11          MinIO Operator       5.0.11               Succeeded

# Check operator pods
oc get pods -n datalyptica-operators
```

All operators must be in `Succeeded` phase before proceeding.

---

## 8. Core Services Deployment

### 8.1 Deploy PostgreSQL Cluster (CloudNativePG)

Create a highly available PostgreSQL cluster:

```yaml
# File: postgresql-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql-ha
  namespace: datalyptica-storage
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:17.7

  # Bootstrap configuration
  bootstrap:
    initdb:
      database: datalyptica
      owner: datalyptica
      secret:
        name: postgresql-credentials
      postInitSQL:
        - CREATE DATABASE nessie;
        - CREATE DATABASE keycloak;

  # Storage configuration
  storage:
    storageClass: fast-ssd
    size: 500Gi

  # WAL storage (separate for performance)
  walStorage:
    storageClass: fast-ssd
    size: 100Gi

  # PostgreSQL configuration
  postgresql:
    parameters:
      max_connections: "500"
      shared_buffers: "4GB"
      effective_cache_size: "12GB"
      maintenance_work_mem: "1GB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "10MB"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
      max_worker_processes: "8"
      max_parallel_workers_per_gather: "4"
      max_parallel_workers: "8"
      max_parallel_maintenance_workers: "4"
    pg_hba:
      - host all all 0.0.0.0/0 md5

  # Replication configuration
  replica:
    minSyncReplicas: 1
    maxSyncReplicas: 2

  # Monitoring
  monitoring:
    enabled: true
    podMonitorSelector:
      matchLabels:
        prometheus: datalyptica

  # Backup configuration (to MinIO)
  backup:
    barmanObjectStore:
      destinationPath: s3://postgresql-backups/
      endpointURL: http://minio.datalyptica-storage.svc.cluster.local:9000
      s3Credentials:
        accessKeyId:
          name: minio-credentials
          key: access-key
        secretAccessKey:
          name: minio-credentials
          key: secret-key
    retentionPolicy: "30d"

  # Resource limits
  resources:
    requests:
      memory: "4Gi"
      cpu: "2"
    limits:
      memory: "8Gi"
      cpu: "4"

  # Affinity rules (spread across nodes)
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              cnpg.io/cluster: postgresql-ha
          topologyKey: kubernetes.io/hostname
---
# Scheduled backup
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: postgresql-backup-daily
  namespace: datalyptica-storage
spec:
  schedule: "0 2 * * *" # 2 AM daily
  backupOwnerReference: self
  cluster:
    name: postgresql-ha
```

Deploy:

```bash
oc apply -f postgresql-cluster.yaml

# Monitor deployment
oc get cluster -n datalyptica-storage -w

# Wait for cluster to be ready
oc wait --for=condition=Ready cluster/postgresql-ha -n datalyptica-storage --timeout=600s

# Check pods
oc get pods -n datalyptica-storage -l cnpg.io/cluster=postgresql-ha

# Check primary
oc exec -it postgresql-ha-1 -n datalyptica-storage -- psql -U datalyptica -c "SELECT pg_is_in_recovery();"
```

Create connection services:

```yaml
# File: postgresql-services.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-rw
  namespace: datalyptica-storage
  labels:
    app: postgresql
spec:
  type: ClusterIP
  ports:
    - port: 5432
      targetPort: 5432
      protocol: TCP
      name: postgresql
  selector:
    cnpg.io/cluster: postgresql-ha
    role: primary
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql-ro
  namespace: datalyptica-storage
  labels:
    app: postgresql
spec:
  type: ClusterIP
  ports:
    - port: 5432
      targetPort: 5432
      protocol: TCP
      name: postgresql
  selector:
    cnpg.io/cluster: postgresql-ha
    role: replica
```

Apply:

```bash
oc apply -f postgresql-services.yaml
```

### 8.2 Deploy MinIO Tenant

Create a distributed MinIO cluster:

```yaml
# File: minio-tenant.yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: datalyptica-minio
  namespace: datalyptica-storage
spec:
  # Image
  image: minio/minio:RELEASE.2024-11-07T00-52-20Z
  imagePullPolicy: IfNotPresent

  # Pools configuration (distributed mode)
  pools:
    - servers: 4 # 4 MinIO servers
      name: pool-0
      volumesPerServer: 4 # 4 drives per server
      volumeClaimTemplate:
        apiVersion: v1
        kind: persistentvolumeclaims
        metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Ti # 1TB per drive
          storageClassName: fast-ssd

      # Resources per server
      resources:
        requests:
          cpu: "2"
          memory: "8Gi"
        limits:
          cpu: "4"
          memory: "16Gi"

      # Security context
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        runAsNonRoot: true

      # Anti-affinity (spread across nodes)
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: v1.min.io/tenant
                    operator: In
                    values:
                      - datalyptica-minio
              topologyKey: kubernetes.io/hostname

  # Credentials
  credsSecret:
    name: minio-credentials

  # Configuration
  configuration:
    name: minio-config

  # Enable TLS
  requestAutoCert: false # Set to true if cert-manager is configured

  # Features
  features:
    bucketDNS: false
    domains: []

  # Prometheus metrics
  prometheusOperator: true

  # Log search API (optional)
  log:
    db:
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 10Gi
          storageClassName: standard
    image: minio/operator:v5.0.11
---
# MinIO configuration
apiVersion: v1
kind: Secret
metadata:
  name: minio-config
  namespace: datalyptica-storage
type: Opaque
stringData:
  config.env: |
    export MINIO_BROWSER="on"
    export MINIO_REGION="us-east-1"
    export MINIO_DOMAIN="minio.datalyptica-storage.svc.cluster.local"
    export MINIO_SERVER_URL="https://minio.datalyptica-storage.svc.cluster.local"
```

Deploy:

```bash
oc apply -f minio-tenant.yaml

# Monitor deployment
oc get tenant -n datalyptica-storage -w

# Wait for tenant to be ready
oc wait --for=condition=Ready tenant/datalyptica-minio -n datalyptica-storage --timeout=600s

# Check pods (should be 4)
oc get pods -n datalyptica-storage -l v1.min.io/tenant=datalyptica-minio

# Check services
oc get svc -n datalyptica-storage | grep minio
```

Create initial buckets:

```bash
# Port-forward to MinIO
oc port-forward -n datalyptica-storage svc/minio 9000:80 &

# Install mc (MinIO client)
# brew install minio/stable/mc  # macOS
# Or download from https://min.io/docs/minio/linux/reference/minio-mc.html

# Configure mc
mc alias set datalyptica http://localhost:9000 $(cat openshift-secrets/minio_root_user) $(cat openshift-secrets/minio_root_password)

# Create buckets
mc mb datalyptica/lakehouse
mc mb datalyptica/warehouse
mc mb datalyptica/postgresql-backups
mc mb datalyptica/mlflow-artifacts

# Enable versioning
mc version enable datalyptica/lakehouse
mc version enable datalyptica/warehouse

# Verify
mc ls datalyptica/

# Stop port-forward
kill %1
```

---

## 8.3 Deploy Kafka Cluster (Strimzi)

Create a KRaft-mode Kafka cluster (no ZooKeeper):

```yaml
# File: kafka-cluster.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: datalyptica-kafka
  namespace: datalyptica-control
spec:
  kafka:
    version: 3.6.0
    replicas: 3

    # Listeners
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
      - name: external
        port: 9094
        type: route
        tls: true

    # Storage
    storage:
      type: persistent-claim
      size: 500Gi
      class: fast-ssd
      deleteClaim: false

    # Configuration
    config:
      # Replication
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2

      # Retention
      log.retention.hours: 168
      log.segment.bytes: 1073741824
      log.retention.check.interval.ms: 300000

      # Performance
      num.network.threads: 3
      num.io.threads: 8
      socket.send.buffer.bytes: 102400
      socket.receive.buffer.bytes: 102400
      socket.request.max.bytes: 104857600
      num.partitions: 3
      num.recovery.threads.per.data.dir: 1
      log.flush.interval.messages: 10000
      log.flush.interval.ms: 1000

      # Cleanup
      log.cleanup.policy: delete
      auto.create.topics.enable: "true"
      delete.topic.enable: "true"

    # Resources
    resources:
      requests:
        memory: 8Gi
        cpu: "2"
      limits:
        memory: 16Gi
        cpu: "4"

    # JVM options
    jvmOptions:
      -Xms: 4096m
      -Xmx: 8192m

    # Metrics
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml

    # Rack awareness (spread across nodes)
    rack:
      topologyKey: kubernetes.io/hostname

  # ZooKeeper (not needed for KRaft, but kept for compatibility)
  # Remove this section if using pure KRaft mode
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 100Gi
      class: fast-ssd
      deleteClaim: false
    resources:
      requests:
        memory: 2Gi
        cpu: "1"
      limits:
        memory: 4Gi
        cpu: "2"
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: zookeeper-metrics-config.yml

  # Entity Operator (Topic & User management)
  entityOperator:
    topicOperator:
      resources:
        requests:
          memory: 512Mi
          cpu: "200m"
        limits:
          memory: 1Gi
          cpu: "500m"
    userOperator:
      resources:
        requests:
          memory: 512Mi
          cpu: "200m"
        limits:
          memory: 1Gi
          cpu: "500m"

  # Kafka Exporter for Prometheus
  kafkaExporter:
    topicRegex: ".*"
    groupRegex: ".*"
    resources:
      requests:
        memory: 128Mi
        cpu: "100m"
      limits:
        memory: 512Mi
        cpu: "500m"
---
# Kafka metrics configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-metrics
  namespace: datalyptica-control
data:
  kafka-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
      name: kafka_server_$1_$2
      type: GAUGE
      labels:
       clientId: "$3"
       topic: "$4"
       partition: "$5"
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
      name: kafka_server_$1_$2
      type: GAUGE
      labels:
       clientId: "$3"
       broker: "$4:$5"
  zookeeper-metrics-config.yml: |
    lowercaseOutputName: true
    rules: []
```

Deploy:

```bash
oc apply -f kafka-cluster.yaml

# Monitor deployment
oc get kafka -n datalyptica-control -w

# Wait for Kafka to be ready
oc wait --for=condition=Ready kafka/datalyptica-kafka -n datalyptica-control --timeout=900s

# Check pods
oc get pods -n datalyptica-control -l strimzi.io/cluster=datalyptica-kafka

# Check services
oc get svc -n datalyptica-control | grep kafka
```

Create Kafka topics:

```yaml
# File: kafka-topics.yaml
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: cdc.events
  namespace: datalyptica-control
  labels:
    strimzi.io/cluster: datalyptica-kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000 # 7 days
    segment.bytes: 1073741824
    min.insync.replicas: 2
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: data.ingestion
  namespace: datalyptica-control
  labels:
    strimzi.io/cluster: datalyptica-kafka
spec:
  partitions: 6
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
    min.insync.replicas: 2
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: analytics.events
  namespace: datalyptica-control
  labels:
    strimzi.io/cluster: datalyptica-kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 2592000000 # 30 days
    segment.bytes: 1073741824
    min.insync.replicas: 2
```

Apply:

```bash
oc apply -f kafka-topics.yaml

# Verify topics
oc get kafkatopic -n datalyptica-control
```

---

This is the first part of the comprehensive OpenShift deployment guide. Would you like me to continue with the remaining sections (8.4-18)?

The guide will continue with:

- Schema Registry deployment
- Nessie catalog
- Query engines (Trino, Spark, Flink)
- Analytics services (ClickHouse, dbt)
- Observability stack
- Security configurations
- Networking and ingress
- Validation procedures
- Operational runbooks
- Monitoring setup
- Backup/DR procedures
- Troubleshooting guides

Shall I continue creating the complete guide?
