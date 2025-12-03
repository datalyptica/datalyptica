# OpenShift HA Deployment with Operators

This directory contains manifests and guides for deploying the Datalyptica Data Platform with High Availability (HA) using OpenShift Operators.

## Overview

We'll deploy the platform in phases using operators where available:

- **Phase 1: Core Infrastructure** (PostgreSQL, Redis, etcd)
- **Phase 2: Object Storage** (MinIO with distributed mode)
- **Phase 3: Catalog Service** (Nessie)
- **Phase 4: Streaming & Processing** (Kafka, Flink)
- **Phase 5: Query & Analytics** (Trino, Spark, ClickHouse)
- **Phase 6: Orchestration & BI** (Airflow, Superset)

## Operators Used

| Component  | Operator                                      | HA Mode                                |
| ---------- | --------------------------------------------- | -------------------------------------- |
| PostgreSQL | Crunchy Postgres Operator or Patroni Operator | 3-node cluster with automatic failover |
| Redis      | Redis Enterprise Operator or Sentinel         | Redis Sentinel 3-node                  |
| MinIO      | MinIO Operator                                | 4-node distributed mode                |
| Kafka      | Strimzi Operator                              | 3-broker cluster                       |
| Flink      | Flink Kubernetes Operator                     | JobManager HA with ZooKeeper           |
| etcd       | etcd Operator                                 | 3-node cluster                         |

## Directory Structure

```
ha-operators/
├── README.md                          # This file
├── 00-prerequisites/
│   ├── namespaces.yaml               # Project/namespace definitions
│   ├── storage-classes.yaml          # Storage class configurations
│   └── operator-subscriptions.yaml   # Operator catalog subscriptions
├── 01-postgresql-ha/
│   ├── README.md                     # PostgreSQL HA deployment guide
│   ├── operator-install.yaml         # Operator installation
│   ├── postgres-cluster.yaml         # 3-node PostgreSQL cluster
│   └── monitoring.yaml               # PostgreSQL monitoring
├── 02-redis-ha/
│   ├── README.md                     # Redis HA deployment guide
│   ├── redis-sentinel.yaml           # Redis Sentinel configuration
│   └── redis-cluster.yaml            # Redis cluster definition
├── 03-etcd-ha/
│   ├── README.md                     # etcd HA deployment guide
│   └── etcd-cluster.yaml             # 3-node etcd cluster
├── 04-minio-ha/
│   ├── README.md                     # MinIO HA deployment guide
│   ├── operator-install.yaml         # MinIO Operator
│   └── minio-tenant.yaml             # 4-node MinIO distributed
├── 05-nessie/
│   ├── README.md                     # Nessie deployment guide
│   └── nessie-deployment.yaml        # Nessie with HA backend
└── deployment-order.md               # Step-by-step deployment sequence
```

## Prerequisites

Before starting the deployment:

1. **OpenShift Cluster Requirements:**

   - OpenShift 4.10 or higher
   - Cluster admin access (for operator installation)
   - Minimum 10 worker nodes for proper HA distribution
   - CPU: 40+ cores available
   - Memory: 128Gi+ available
   - Storage: 500Gi+ with RWX and RWO support

2. **Storage Classes:**

   - **RWO (ReadWriteOnce)**: For stateful sets (databases, persistent queues)
   - **RWX (ReadWriteMany)**: For shared storage (logs, configs)
   - Recommended: Ceph RBD, OpenShift Data Foundation, or cloud provider storage

3. **Network Requirements:**

   - Pod network with sufficient bandwidth
   - Load balancer or router for external access
   - Internal DNS resolution working

4. **Operator Catalog:**
   - OperatorHub available
   - Community operators enabled
   - Certified operators enabled

## Quick Start

### Step 1: Review Prerequisites

```bash
# Check cluster version
oc version

# Check available storage classes
oc get sc

# Check worker nodes
oc get nodes --show-labels

# Verify you have cluster-admin
oc auth can-i create operators --all-namespaces
```

### Step 2: Create Projects

```bash
# Apply namespace definitions
oc apply -f 00-prerequisites/namespaces.yaml

# Verify projects created
oc get projects | grep datalyptica
```

### Step 3: Install Operators

```bash
# Subscribe to operators (this will take 5-10 minutes)
oc apply -f 00-prerequisites/operator-subscriptions.yaml

# Watch operator installation
watch oc get csv -n openshift-operators
```

### Step 4: Deploy Core Components (Follow Phase 1)

```bash
# Start with PostgreSQL HA
cd 01-postgresql-ha
# Follow README.md for detailed steps
```

## Deployment Timeline

| Phase         | Duration       | Services                 |
| ------------- | -------------- | ------------------------ |
| Prerequisites | 30 min         | Operators installation   |
| Phase 1       | 45 min         | PostgreSQL, Redis, etcd  |
| Phase 2       | 30 min         | MinIO distributed        |
| Phase 3       | 15 min         | Nessie                   |
| Phase 4       | 45 min         | Kafka, Flink             |
| Phase 5       | 60 min         | Trino, Spark, ClickHouse |
| Phase 6       | 45 min         | Airflow, Superset        |
| **Total**     | **~4-5 hours** | Full HA stack            |

## HA Characteristics

### PostgreSQL (3-node Patroni Cluster)

- **Availability**: 99.95%
- **RPO**: < 10 seconds (synchronous replication)
- **RTO**: < 30 seconds (automatic failover)
- **Architecture**: 1 primary + 2 replicas with automatic promotion

### Redis (Sentinel Mode)

- **Availability**: 99.9%
- **RPO**: < 5 seconds
- **RTO**: < 20 seconds
- **Architecture**: 3 Redis nodes + 3 Sentinel monitors

### MinIO (Distributed Mode)

- **Availability**: 99.99%
- **RPO**: 0 (erasure coding)
- **RTO**: 0 (no failover needed)
- **Architecture**: 4 nodes with N/2 erasure coding

### Kafka (Strimzi)

- **Availability**: 99.95%
- **RPO**: Configurable (acks=all for zero data loss)
- **RTO**: < 1 minute (ISR election)
- **Architecture**: 3 brokers with replication factor 3

## Anti-Affinity Rules

All HA components use pod anti-affinity to ensure replicas are spread across different nodes:

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - <service-name>
        topologyKey: kubernetes.io/hostname
```

## Monitoring

Each HA component includes:

- **Liveness probes**: Restart unhealthy pods
- **Readiness probes**: Remove pods from load balancing
- **Metrics export**: Prometheus integration
- **Alerting**: PagerDuty/email notifications for failures

## Backup Strategy

| Component  | Backup Method      | Frequency        | Retention |
| ---------- | ------------------ | ---------------- | --------- |
| PostgreSQL | pgBackRest         | Every 6 hours    | 30 days   |
| Redis      | RDB snapshots      | Every 1 hour     | 7 days    |
| MinIO      | Bucket replication | Continuous       | N/A       |
| etcd       | Snapshot           | Every 30 minutes | 7 days    |
| Kafka      | MirrorMaker 2      | Continuous       | 7 days    |

## Disaster Recovery

### PostgreSQL

- Automated backups to S3-compatible storage
- Point-in-time recovery (PITR) available
- Cross-region replication (optional)

### MinIO

- Built-in versioning enabled
- Lifecycle policies for data retention
- Bucket replication to secondary cluster

### Kafka

- Topic replication factor: 3
- MirrorMaker for cross-cluster replication
- Consumer offset backup

## Troubleshooting

### Operator Issues

```bash
# Check operator status
oc get csv -n openshift-operators

# Check operator logs
oc logs -n openshift-operators -l name=<operator-name>

# Force operator reconciliation
oc delete pod -n openshift-operators -l name=<operator-name>
```

### Cluster Health

```bash
# PostgreSQL cluster status
oc exec -it <postgres-pod> -- patronictl list

# Redis sentinel status
oc exec -it <redis-pod> -- redis-cli SENTINEL masters

# MinIO cluster status
oc exec -it <minio-pod> -- mc admin info local

# Kafka cluster status
oc exec -it <kafka-pod> -- kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

### Pod Anti-Affinity Issues

```bash
# Check pod placement
oc get pods -o wide -n <namespace>

# Check node labels
oc get nodes --show-labels

# If pods are pending due to anti-affinity, you may need more nodes
oc get events -n <namespace> --sort-by='.lastTimestamp'
```

## Security Considerations

1. **Network Policies**: Implement network policies to restrict inter-pod communication
2. **TLS**: Enable TLS for all inter-component communication
3. **RBAC**: Use service accounts with minimal permissions
4. **Secrets**: Use sealed secrets or external secrets operator
5. **Pod Security**: Use restricted SCC or custom SCC with minimal privileges

## Next Steps

1. Review `deployment-order.md` for the complete step-by-step guide
2. Start with `00-prerequisites/` to prepare your cluster
3. Follow each phase directory in sequence
4. Validate each phase before proceeding to the next

## Support

For issues or questions:

- Check `docs/TROUBLESHOOTING.md`
- Review operator documentation
- Check OpenShift logs and events
