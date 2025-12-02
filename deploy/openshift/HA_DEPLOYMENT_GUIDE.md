# OpenShift HA Deployment Guide

Complete guide for deploying the Datalyptica data lakehouse platform on OpenShift 4.13+ in High Availability (HA) mode.

---

## Architecture Overview

### Service Inventory

**Total Services: 25** (100% complete)

| Layer | Services | Count | HA Strategy |
|-------|----------|-------|-------------|
| **Storage** | PostgreSQL (Patroni), MinIO | 2 | Cluster replication (3-4 replicas) |
| **Control** | Kafka, Schema Registry, Kafka Connect | 3 | Leader election (2-3 replicas) |
| **Data** | Nessie, Trino, Spark, Flink, ClickHouse, dbt | 6 | Multi-instance (1-3 replicas) |
| **Management** | Prometheus, Grafana, Loki, Alertmanager, Alloy, Kafka-UI | 6 | Distributed (2-3+ replicas) |
| **Infrastructure** | Keycloak, Redis | 2 | Cluster mode (2-3 replicas) |
| **Analytics** | Airflow, JupyterHub, MLflow, Superset, Great Expectations | 6 | Multi-replica (2-3 replicas) |

### Network & Security

- **10 OpenShift Routes** with TLS edge termination
- **8 NetworkPolicy sets** for cross-namespace security
- **2 SecurityContextConstraints** (StatefulSets, DaemonSets)

### Namespaces

```
datalyptica-storage        # PostgreSQL (Patroni), MinIO
datalyptica-control        # Kafka, Schema Registry, Kafka Connect
datalyptica-data           # Nessie, Trino, Spark, Flink, ClickHouse, dbt
datalyptica-management     # Prometheus, Grafana, Loki, Alertmanager, Alloy, Kafka-UI, Airflow, JupyterHub, MLflow, Superset, Great Expectations
datalyptica-infrastructure # Keycloak, Redis
```

---

## Prerequisites

### Cluster Requirements

- **OpenShift**: 4.13 or later
- **Nodes**: 3+ worker nodes (for anti-affinity)
- **CPU**: 120 vCPUs (requests), 240 vCPUs (limits)
- **Memory**: 240 GB (requests), 480 GB (limits)
- **Storage**: 2.5 TB (fast-ssd storage class)

### Quick Start

```bash
cd deploy/openshift

# Create namespaces
oc create namespace datalyptica-storage
oc create namespace datalyptica-control
oc create namespace datalyptica-data
oc create namespace datalyptica-management
oc create namespace datalyptica-infrastructure

# Generate secrets
./scripts/01-generate-secrets.sh
./scripts/02-create-secrets-ha.sh

# Deploy full stack
./scripts/deploy-all.sh --mode=ha

# Validate
./scripts/validate-deployment.sh
```

---

## Deployment Layers

### 1. Storage Layer

**PostgreSQL with Patroni:**
- 3-replica cluster with automatic failover
- Kubernetes-based DCS
- Sub-30s failover time
- REST API on port 8008

```bash
oc apply -k storage/postgresql
oc exec -it postgresql-0 -n datalyptica-storage -- patronictl list
```

**MinIO:**
- 4-node distributed object storage
- EC:2 erasure coding

```bash
oc apply -k storage/minio
oc exec -it minio-0 -n datalyptica-storage -- mc admin info local
```

### 2-6. Other Layers

See full deployment steps in `DEPLOYMENT_COMPLETE_SUMMARY.md`.

---

## Access Services

```bash
# Get all routes
oc get routes -A | grep datalyptica

# Example URLs:
# - Grafana: https://grafana.apps.cluster.local
# - Trino UI: https://trino.apps.cluster.local
# - JupyterHub: https://jupyter.apps.cluster.local
# - Superset: https://superset.apps.cluster.local
```

---

## For More Details

- **Complete Summary**: `DEPLOYMENT_COMPLETE_SUMMARY.md`
- **Standalone Mode**: `STANDALONE_DEPLOYMENT_GUIDE.md`
- **Status**: `HA_DEPLOYMENT_STATUS.md`
