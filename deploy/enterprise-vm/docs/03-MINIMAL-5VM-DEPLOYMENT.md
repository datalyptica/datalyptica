# Datalyptica Minimal 5-VM Deployment

**Version:** 2.1.0 - Minimal Configuration  
**Deployment Model:** Native VM Installation (No Docker)  
**High Availability:** Limited HA with 5 VMs  
**Last Updated:** December 3, 2025

---

## Overview

This document describes a **minimal production-ready deployment** of Datalyptica on just **5 VMs**. This configuration consolidates multiple services per VM while maintaining basic high availability for critical components.

### ⚠️ Limitations vs Full Deployment

| Aspect        | Full Deployment (50 VMs) | Minimal Deployment (5 VMs)  |
| ------------- | ------------------------ | --------------------------- |
| Total VMs     | 50                       | 5                           |
| HA Level      | Full (every component)   | Critical components only    |
| PostgreSQL    | 3-node cluster           | 3-node cluster (shared VMs) |
| Kafka         | 5 brokers                | 3 brokers                   |
| Spark Workers | 4 dedicated              | 2 shared                    |
| Trino Workers | 3 dedicated              | 2 shared                    |
| Failover Time | <30s                     | <1-2m                       |
| Scalability   | Excellent                | Limited                     |
| Use Case      | Production (large scale) | Production (small/medium)   |

---

## 5-VM Architecture Design

### Logical Distribution

```
┌─────────────────────────────────────────────────────────────────┐
│                          External Load Balancer                  │
│                    (HAProxy on VM1 + VM2 with VIP)              │
└─────────────────────────────────────────────────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
┌─────────────▼────┐    ┌─────────▼──────┐   ┌───────▼─────────┐
│     VM1          │    │      VM2        │   │      VM3        │
│  Control Plane   │    │  Control Plane  │   │  Control Plane  │
│                  │    │                 │   │                 │
│ • HAProxy        │    │ • HAProxy       │   │ • HAProxy       │
│ • PostgreSQL-1   │    │ • PostgreSQL-2  │   │ • PostgreSQL-3  │
│ • Patroni        │    │ • Patroni       │   │ • Patroni       │
│ • etcd-1         │    │ • etcd-2        │   │ • etcd-3        │
│ • Nessie         │    │ • Nessie        │   │ • Nessie        │
│ • Kafka Broker-1 │    │ • Kafka Broker-2│   │ • Kafka Broker-3│
│ • Schema Reg     │    │ • Schema Reg    │   │ • Redis Master  │
│ • Keycloak       │    │ • Keycloak      │   │ • Keycloak      │
│ • Redis Sentinel │    │ • Redis Replica │   │ • Redis Sentinel│
│ • Prometheus     │    │ • Grafana       │   │ • Loki          │
└──────────────────┘    └─────────────────┘   └─────────────────┘
                                  │
              ┌───────────────────┴───────────────────┐
              │                                       │
┌─────────────▼────────┐              ┌───────────────▼────────┐
│        VM4           │              │         VM5            │
│    Data Plane        │              │     Data Plane         │
│                      │              │                        │
│ • Spark Master       │              │ • Spark Worker         │
│ • Spark Worker       │              │ • Spark Worker         │
│ • Flink JobManager   │              │ • Flink TaskManager    │
│ • Flink TaskManager  │              │ • Flink TaskManager    │
│ • Trino Coordinator  │              │ • Trino Worker         │
│ • Trino Worker       │              │ • Trino Worker         │
│ • ClickHouse Shard-1 │              │ • ClickHouse Shard-2   │
│ • Airflow Scheduler  │              │ • Airflow Worker       │
│ • Airflow Web        │              │ • Airflow Worker       │
│ • JupyterHub         │              │ • MLflow               │
│ • Superset           │              │ • Kafka Connect        │
└──────────────────────┘              └────────────────────────┘
```

---

## VM Specifications

### Hardware Requirements

| VM        | Role            | vCPU    | RAM        | Storage   | Network |
| --------- | --------------- | ------- | ---------- | --------- | ------- |
| **VM1**   | Control Plane 1 | 32      | 128 GB     | 2 TB SSD  | 10 Gbps |
| **VM2**   | Control Plane 2 | 32      | 128 GB     | 2 TB SSD  | 10 Gbps |
| **VM3**   | Control Plane 3 | 32      | 128 GB     | 2 TB SSD  | 10 Gbps |
| **VM4**   | Data Plane 1    | 64      | 256 GB     | 4 TB SSD  | 10 Gbps |
| **VM5**   | Data Plane 2    | 64      | 256 GB     | 4 TB SSD  | 10 Gbps |
| **TOTAL** |                 | **224** | **896 GB** | **14 TB** |         |

### Minimum Acceptable Specifications

If the above is too much, absolute minimum:

| VM        | Role            | vCPU    | RAM        | Storage  | Notes                 |
| --------- | --------------- | ------- | ---------- | -------- | --------------------- |
| **VM1**   | Control Plane 1 | 16      | 64 GB      | 1 TB SSD | Will be constrained   |
| **VM2**   | Control Plane 2 | 16      | 64 GB      | 1 TB SSD | Will be constrained   |
| **VM3**   | Control Plane 3 | 16      | 64 GB      | 1 TB SSD | Will be constrained   |
| **VM4**   | Data Plane 1    | 32      | 128 GB     | 2 TB SSD | Processing bottleneck |
| **VM5**   | Data Plane 2    | 32      | 128 GB     | 2 TB SSD | Processing bottleneck |
| **TOTAL** |                 | **112** | **448 GB** | **7 TB** |                       |

⚠️ **Warning**: Minimum specs suitable only for small workloads (< 500 GB data, < 10 concurrent users)

---

## Detailed Service Distribution

### VM1 - Control Plane Node 1 (Primary)

**IP**: 10.20.0.11  
**Role**: Control Plane Primary with HA services  
**Services**:

| Service               | Port       | Memory     | CPU     | Notes                     |
| --------------------- | ---------- | ---------- | ------- | ------------------------- |
| HAProxy               | 80, 443    | 512 MB     | 0.5     | Load balancer             |
| Keepalived            | -          | 128 MB     | 0.1     | VIP management (MASTER)   |
| PostgreSQL 16.2       | 5432       | 16 GB      | 4       | Primary database          |
| Patroni 3.3.2         | 8008       | 512 MB     | 0.5     | PostgreSQL HA             |
| etcd 3.5.16           | 2379, 2380 | 2 GB       | 1       | Distributed config        |
| Nessie 0.98.2         | 19120      | 4 GB       | 2       | Catalog service           |
| Kafka 3.9.0           | 9092, 9093 | 16 GB      | 8       | Message broker (Broker 1) |
| Schema Registry 7.8.0 | 8085       | 2 GB       | 1       | Avro schemas              |
| Keycloak 26.0.7       | 8080       | 4 GB       | 2       | IAM                       |
| Redis Sentinel        | 26379      | 256 MB     | 0.5     | Redis monitoring          |
| Prometheus 3.0.1      | 9090       | 8 GB       | 2       | Metrics                   |
| Node Exporter         | 9100       | 128 MB     | 0.2     | VM metrics                |
| **Total**             |            | **~54 GB** | **~22** |                           |

---

### VM2 - Control Plane Node 2 (Secondary)

**IP**: 10.20.0.12  
**Role**: Control Plane Secondary with HA services  
**Services**:

| Service               | Port       | Memory     | CPU     | Notes                      |
| --------------------- | ---------- | ---------- | ------- | -------------------------- |
| HAProxy               | 80, 443    | 512 MB     | 0.5     | Load balancer              |
| Keepalived            | -          | 128 MB     | 0.1     | VIP management (BACKUP)    |
| PostgreSQL 16.2       | 5432       | 16 GB      | 4       | Standby (sync replication) |
| Patroni 3.3.2         | 8008       | 512 MB     | 0.5     | PostgreSQL HA              |
| etcd 3.5.16           | 2379, 2380 | 2 GB       | 1       | Distributed config         |
| Nessie 0.98.2         | 19120      | 4 GB       | 2       | Catalog service            |
| Kafka 3.9.0           | 9092, 9093 | 16 GB      | 8       | Message broker (Broker 2)  |
| Schema Registry 7.8.0 | 8085       | 2 GB       | 1       | Avro schemas               |
| Keycloak 26.0.7       | 8080       | 4 GB       | 2       | IAM                        |
| Redis 7.4.1           | 6379       | 4 GB       | 1       | Cache replica              |
| Redis Sentinel        | 26379      | 256 MB     | 0.5     | Redis monitoring           |
| Grafana 11.4.0        | 3000       | 4 GB       | 2       | Visualization              |
| Node Exporter         | 9100       | 128 MB     | 0.2     | VM metrics                 |
| **Total**             |            | **~54 GB** | **~23** |                            |

---

### VM3 - Control Plane Node 3 (Tertiary)

**IP**: 10.20.0.13  
**Role**: Control Plane Tertiary for quorum  
**Services**:

| Service             | Port       | Memory     | CPU     | Notes                       |
| ------------------- | ---------- | ---------- | ------- | --------------------------- |
| HAProxy             | 80, 443    | 512 MB     | 0.5     | Load balancer               |
| Keepalived          | -          | 128 MB     | 0.1     | VIP management (BACKUP)     |
| PostgreSQL 16.2     | 5432       | 16 GB      | 4       | Standby (async replication) |
| Patroni 3.3.2       | 8008       | 512 MB     | 0.5     | PostgreSQL HA               |
| etcd 3.5.16         | 2379, 2380 | 2 GB       | 1       | Distributed config          |
| Nessie 0.98.2       | 19120      | 4 GB       | 2       | Catalog service             |
| Kafka 3.9.0         | 9092, 9093 | 16 GB      | 8       | Message broker (Broker 3)   |
| Keycloak 26.0.7     | 8080       | 4 GB       | 2       | IAM                         |
| Redis 7.4.1         | 6379       | 4 GB       | 1       | Cache master                |
| Redis Sentinel      | 26379      | 256 MB     | 0.5     | Redis monitoring            |
| Loki 3.3.2          | 3100       | 8 GB       | 2       | Log aggregation             |
| Alertmanager 0.28.0 | 9093       | 2 GB       | 1       | Alert routing               |
| Node Exporter       | 9100       | 128 MB     | 0.2     | VM metrics                  |
| **Total**           |            | **~58 GB** | **~23** |                             |

---

### VM4 - Data Plane Node 1

**IP**: 10.20.0.21  
**Role**: Primary processing and query execution  
**Services**:

| Service                  | Port       | Memory      | CPU     | Notes                     |
| ------------------------ | ---------- | ----------- | ------- | ------------------------- |
| Spark Master 3.5.4       | 7077, 8080 | 4 GB        | 2       | Cluster manager           |
| Spark Worker 3.5.4       | 8081       | 48 GB       | 16      | Executor (48GB, 16 cores) |
| Flink JobManager 1.20.0  | 6123, 8081 | 8 GB        | 2       | Stream coordinator        |
| Flink TaskManager 1.20.0 | -          | 32 GB       | 12      | Stream executor           |
| Trino Coordinator 469    | 8080       | 32 GB       | 8       | Query coordinator         |
| Trino Worker 469         | 8080       | 32 GB       | 8       | Query worker              |
| ClickHouse 24.12.2.59    | 8123, 9000 | 32 GB       | 8       | OLAP shard 1              |
| ClickHouse Keeper        | 9181       | 1 GB        | 0.5     | Coordination              |
| Airflow Scheduler 2.10.4 | -          | 8 GB        | 4       | Workflow scheduler        |
| Airflow Webserver 2.10.4 | 8082       | 4 GB        | 2       | Web UI                    |
| JupyterHub 5.2.1         | 8000       | 8 GB        | 2       | Multi-user Jupyter        |
| Superset 4.1.1           | 8088       | 8 GB        | 2       | BI platform               |
| Node Exporter            | 9100       | 128 MB      | 0.2     | VM metrics                |
| **Total**                |            | **~217 GB** | **~65** |                           |

---

### VM5 - Data Plane Node 2

**IP**: 10.20.0.22  
**Role**: Secondary processing and query execution  
**Services**:

| Service                  | Port       | Memory      | CPU     | Notes                          |
| ------------------------ | ---------- | ----------- | ------- | ------------------------------ |
| Spark Worker 3.5.4       | 8081       | 48 GB       | 16      | Executor (48GB, 16 cores)      |
| Spark Worker 3.5.4       | 8082       | 48 GB       | 16      | Executor (48GB, 16 cores)      |
| Flink TaskManager 1.20.0 | -          | 32 GB       | 12      | Stream executor                |
| Flink TaskManager 1.20.0 | -          | 32 GB       | 12      | Stream executor                |
| Trino Worker 469         | 8080       | 32 GB       | 8       | Query worker                   |
| Trino Worker 469         | 8081       | 32 GB       | 8       | Query worker                   |
| ClickHouse 24.12.2.59    | 8123, 9000 | 32 GB       | 8       | OLAP shard 2 + replica         |
| ClickHouse Keeper        | 9181       | 1 GB        | 0.5     | Coordination                   |
| Airflow Worker 2.10.4    | -          | 16 GB       | 4       | Celery worker                  |
| Airflow Worker 2.10.4    | -          | 16 GB       | 4       | Celery worker                  |
| MLflow 2.19.0            | 5001       | 4 GB        | 2       | ML tracking                    |
| Kafka Connect 3.9.0      | 8083       | 4 GB        | 2       | CDC connectors                 |
| Node Exporter            | 9100       | 128 MB      | 0.2     | VM metrics                     |
| **Total**                |            | **~247 GB** | **~92** | Over-subscribed but manageable |

---

## High Availability Configuration

### Critical Services with HA

| Service             | HA Method            | Nodes        | Quorum       | Failover |
| ------------------- | -------------------- | ------------ | ------------ | -------- |
| **PostgreSQL**      | Patroni + etcd       | 3 (all VMs)  | 2/3          | <30s     |
| **etcd**            | Raft consensus       | 3 (all VMs)  | 2/3          | <5s      |
| **Kafka**           | KRaft quorum         | 3 (all VMs)  | 2/3          | <15s     |
| **Nessie**          | Active-Active        | 3 (all VMs)  | N/A          | <5s      |
| **Keycloak**        | Clustered            | 3 (all VMs)  | N/A          | <5s      |
| **Redis**           | Sentinel             | 3 (all VMs)  | 2/3          | <10s     |
| **HAProxy**         | Keepalived VIP       | 3 (all VMs)  | N/A          | <2s      |
| **ClickHouse**      | Replication + Keeper | 2 (VM4, VM5) | 2/3 (shared) | <30s     |
| **Schema Registry** | Leader election      | 2 (VM1, VM2) | N/A          | <5s      |

### Services Without HA (Single Point of Failure)

⚠️ These services run on single nodes:

- **Spark Master**: VM4 only (no standby master in minimal config)
- **Flink JobManager**: VM4 only (no HA due to resource constraints)
- **Trino Coordinator**: VM4 only (single coordinator)
- **Airflow Scheduler**: VM4 only
- **Grafana**: VM2 only
- **Prometheus**: VM1 only
- **Loki**: VM3 only

**Mitigation**:

- VM-level HA (vMotion, vSphere HA)
- Fast restart procedures
- Regular backups

---

## Network Configuration

### Simplified Network Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    External Network (DMZ)                    │
│                      VIP: 203.0.113.100                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              Management Network (10.10.0.0/24)               │
│  VM1: 10.10.0.11   VM2: 10.10.0.12   VM3: 10.10.0.13       │
│  VM4: 10.10.0.21   VM5: 10.10.0.22                          │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│             Application Network (10.20.0.0/24)               │
│  VM1: 10.20.0.11   VM2: 10.20.0.12   VM3: 10.20.0.13       │
│  VM4: 10.20.0.21   VM5: 10.20.0.22                          │
│                                                              │
│  VIPs:                                                       │
│    HAProxy VIP: 10.20.0.100                                 │
│    PostgreSQL VIP: 10.20.0.101 (managed by Patroni)        │
│    Redis VIP: 10.20.0.102 (managed by Sentinel)            │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              Storage Network (10.30.0.0/24)                  │
│  VM1: 10.30.0.11   VM2: 10.30.0.12   VM3: 10.30.0.13       │
│  VM4: 10.30.0.21   VM5: 10.30.0.22                          │
│                                                              │
│  Object Storage: 10.30.0.250 (Enterprise S3)                │
│  NFS Share: 10.30.0.251                                     │
└──────────────────────────────────────────────────────────────┘
```

### Network Interfaces per VM

Each VM requires **3 NICs**:

- **NIC1**: Management (1 Gbps) - 10.10.0.x
- **NIC2**: Application (10 Gbps) - 10.20.0.x
- **NIC3**: Storage (10 Gbps) - 10.30.0.x

### DNS Records

```
# Management
vm1.mgmt.datalyptica.local      -> 10.10.0.11
vm2.mgmt.datalyptica.local      -> 10.10.0.12
vm3.mgmt.datalyptica.local      -> 10.10.0.13
vm4.mgmt.datalyptica.local      -> 10.10.0.21
vm5.mgmt.datalyptica.local      -> 10.10.0.22

# Application
vm1.datalyptica.local           -> 10.20.0.11
vm2.datalyptica.local           -> 10.20.0.12
vm3.datalyptica.local           -> 10.20.0.13
vm4.datalyptica.local           -> 10.20.0.21
vm5.datalyptica.local           -> 10.20.0.22

# Virtual IPs
lb.datalyptica.local            -> 10.20.0.100 (HAProxy VIP)
postgres.datalyptica.local      -> 10.20.0.101 (Patroni VIP)
redis.datalyptica.local         -> 10.20.0.102 (Redis VIP)

# Service Endpoints (via load balancer)
grafana.datalyptica.local       -> 10.20.0.100
trino.datalyptica.local         -> 10.20.0.100
airflow.datalyptica.local       -> 10.20.0.100
jupyter.datalyptica.local       -> 10.20.0.100
```

---

## Storage Requirements

### Local Storage per VM

| VM  | OS/Apps | PostgreSQL | Kafka  | Processing | Total  |
| --- | ------- | ---------- | ------ | ---------- | ------ |
| VM1 | 100 GB  | 500 GB     | 500 GB | -          | 1.1 TB |
| VM2 | 100 GB  | 500 GB     | 500 GB | -          | 1.1 TB |
| VM3 | 100 GB  | 500 GB     | 500 GB | -          | 1.1 TB |
| VM4 | 100 GB  | -          | -      | 1.9 TB     | 2 TB   |
| VM5 | 100 GB  | -          | -      | 1.9 TB     | 2 TB   |

**Total Local Storage**: 7.3 TB SSD

**Storage Breakdown**:

- PostgreSQL (1.5 TB total): Data, WAL, backups
- Kafka (1.5 TB total): Log segments across 3 brokers
- Processing (3.8 TB): Spark shuffle, Flink state, ClickHouse data
- System (500 GB): OS, applications, logs

### Enterprise Object Storage

**Capacity**: 50 TB minimum (can scale as needed)  
**Access**: S3-compatible API via 10.30.0.250  
**Buckets**:

```
s3://datalyptica-warehouse/      # Iceberg tables (80% usage)
s3://datalyptica-staging/        # Staging data (10%)
s3://datalyptica-backups/        # Backups (10%)
s3://datalyptica-ml/             # ML models and artifacts
```

### Shared NFS Storage

**Capacity**: 1 TB  
**Mount Points**:

```
/opt/datalyptica/shared          # Common configs (10 GB)
/home/jupyter                    # JupyterHub homes (500 GB)
/opt/spark/recovery              # Spark HA state (10 GB)
```

---

## Operating System Requirements

### Supported OS

**Recommended**: RHEL 9.3 or Ubuntu 22.04 LTS

### Base Configuration

**Java Version**: OpenJDK 17 (for all JVM-based services)

```bash
# Install Java
yum install -y java-17-openjdk java-17-openjdk-devel  # RHEL
apt-get install -y openjdk-17-jdk openjdk-17-jre      # Ubuntu

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

**Python Version**: Python 3.11+ (for Airflow, JupyterHub, MLflow, Superset)

```bash
# Install Python 3.11
yum install -y python3.11 python3.11-pip              # RHEL
apt-get install -y python3.11 python3.11-venv         # Ubuntu
```

**Kernel Parameters** (`/etc/sysctl.conf`):

```ini
# Network
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 10000 65535

# File system
fs.file-max = 2097152
vm.max_map_count = 262144

# Memory
vm.swappiness = 1
vm.overcommit_memory = 1
```

**File Limits** (`/etc/security/limits.conf`):

```
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
```

---

## Installation Overview

### Installation Order

1. **Phase 1 - OS Preparation** (All VMs)

   - OS updates and hardening
   - Kernel parameter tuning
   - Network configuration
   - NTP synchronization
   - Firewall rules
   - Shared storage mounts

2. **Phase 2 - Coordination Layer** (VM1, VM2, VM3)

   - etcd cluster (3 nodes)
   - Keepalived + HAProxy with VIP

3. **Phase 3 - Data Layer** (VM1, VM2, VM3)

   - PostgreSQL 16.2 installation
   - Patroni HA setup
   - Database initialization

4. **Phase 4 - Streaming Layer** (VM1, VM2, VM3)

   - Kafka 3.9.0 (KRaft mode)
   - Schema Registry (VM1, VM2)
   - Kafka Connect (VM5)

5. **Phase 5 - Catalog Layer** (VM1, VM2, VM3)

   - Nessie catalog (3 nodes)
   - Integration with PostgreSQL

6. **Phase 6 - Processing Layer** (VM4, VM5)

   - Spark cluster (1 master, 3 workers)
   - Flink cluster (1 JobManager, 4 TaskManagers)
   - Iceberg integration

7. **Phase 7 - Query Layer** (VM4, VM5)

   - Trino cluster (1 coordinator, 3 workers)
   - ClickHouse cluster (2 nodes, 2 Keepers)
   - Catalog integration

8. **Phase 8 - Analytics Layer** (VM4, VM5)

   - Airflow (scheduler, web, 2 workers)
   - JupyterHub (VM4)
   - MLflow (VM5)
   - Superset (VM4)

9. **Phase 9 - IAM Layer** (VM1, VM2, VM3)

   - Keycloak cluster (3 nodes)
   - Redis cluster with Sentinel

10. **Phase 10 - Monitoring** (VM1, VM2, VM3)
    - Prometheus (VM1)
    - Grafana (VM2)
    - Loki (VM3)
    - Alertmanager (VM3)
    - Node exporters (all VMs)

---

## Resource Management Strategy

### Memory Allocation Strategy

With limited RAM, careful memory management is critical:

**VM1-3 (128 GB each)**:

- PostgreSQL: 16 GB (conservative, usually needs more)
- Kafka: 16 GB heap
- etcd: 2 GB
- Nessie: 4 GB
- Keycloak: 4 GB
- Monitoring: 8-10 GB
- **Remaining**: ~75 GB for OS cache and buffers

**VM4 (256 GB)**:

- Spark processes: ~50 GB total
- Flink processes: ~40 GB total
- Trino: ~64 GB total
- ClickHouse: ~32 GB
- Airflow: ~12 GB
- Others: ~20 GB
- **Remaining**: ~40 GB for OS

**VM5 (256 GB)**:

- Spark workers: ~96 GB total
- Flink TaskManagers: ~64 GB total
- Trino workers: ~64 GB total
- ClickHouse: ~32 GB
- **Remaining**: ~0 GB (tight!)

### CPU Allocation

CPUs are over-subscribed on VM4 and VM5. This is acceptable because:

- Not all services are CPU-intensive simultaneously
- Most services spend time waiting on I/O
- Modern hypervisors handle over-subscription well

**Recommendation**: Monitor CPU usage and scale to 6-7 VMs if consistently >80%

### Disk I/O Management

**Critical**: Use SSD for all VM storage, especially:

- PostgreSQL data and WAL directories
- Kafka log directories
- ClickHouse data directories
- Spark shuffle directories

**Mount Points**:

```
/data/postgresql     # PostgreSQL data
/data/kafka          # Kafka logs
/data/clickhouse     # ClickHouse tables
/data/spark          # Spark shuffle
/data/flink          # Flink state
```

---

## Limitations & Scaling Path

### Known Limitations

❌ **Single Points of Failure**:

- Spark Master (VM4)
- Flink JobManager (VM4)
- Trino Coordinator (VM4)
- Airflow Scheduler (VM4)
- All monitoring services

❌ **Performance Constraints**:

- Limited parallel processing capacity
- Smaller data cache size
- Fewer Kafka partitions per broker
- Limited concurrent query capacity

❌ **Scalability Limits**:

- ~10-20 concurrent users
- ~1-5 TB active data
- ~100-500 GB/day ingestion
- ~50-100 concurrent queries

### When to Scale

Scale from 5 VMs to more when you experience:

1. **CPU bottleneck**: Sustained >80% CPU on VM4 or VM5
2. **Memory pressure**: Frequent OOM errors or swapping
3. **Storage capacity**: >70% disk usage
4. **Performance degradation**: Query times 2x slower
5. **Availability concerns**: Frequent service disruptions

### Scaling Path

**5 VMs → 10 VMs**:

- Separate processing and query tiers
- Add dedicated Spark/Flink workers
- Add dedicated Trino workers
- Move monitoring to dedicated VMs

**10 VMs → 20 VMs**:

- Separate each service type to dedicated VMs
- Add more workers for horizontal scaling
- Implement proper HA for all services

**20 VMs → 50 VMs**:

- Full enterprise architecture (see main documentation)
- Complete redundancy for all components
- Geographic distribution ready

---

## Cost Estimation

### Hardware Costs (Estimated)

**VMs** (5 VMs):

- 3x Control Plane (32 vCPU, 128GB RAM): $15,000 each = $45,000
- 2x Data Plane (64 vCPU, 256GB RAM): $25,000 each = $50,000
- **Total VM Cost**: $95,000

**Storage**:

- Local SSD (14 TB total): Included in VM cost
- Enterprise Object Storage (50 TB): $250,000 - $500,000
- NFS/SAN (1 TB): $10,000

**Network**:

- Switches, NICs, cabling: $30,000

**Total CapEx**: $385,000 - $635,000

### Annual Operating Costs

- **Licenses** (RHEL/Ubuntu support): $12,000/year
- **Personnel** (2 engineers): $300,000/year
- **Power & Cooling**: $10,000/year
- **Maintenance**: $20,000/year

**Total OpEx**: $342,000/year

---

## Quick Deployment Checklist

### Pre-deployment

- [ ] 5 VMs provisioned with correct specifications
- [ ] RHEL 9.3 or Ubuntu 22.04 LTS installed
- [ ] 3 NICs configured per VM
- [ ] Network VLANs configured
- [ ] DNS records created
- [ ] Enterprise object storage accessible (S3 endpoint)
- [ ] NFS share mounted on all VMs
- [ ] SSH key access configured
- [ ] Sudo privileges granted
- [ ] Firewall rules documented

### Deployment

- [ ] Phase 1: OS preparation completed
- [ ] Phase 2: etcd + HAProxy cluster running
- [ ] Phase 3: PostgreSQL + Patroni HA verified
- [ ] Phase 4: Kafka cluster running (3 brokers)
- [ ] Phase 5: Nessie catalog accessible
- [ ] Phase 6: Spark cluster functional
- [ ] Phase 7: Trino accepting queries
- [ ] Phase 8: Airflow DAGs running
- [ ] Phase 9: Keycloak authentication working
- [ ] Phase 10: Monitoring dashboards visible

### Post-deployment

- [ ] All services passing health checks
- [ ] HA failover tested for critical services
- [ ] Sample data ingestion successful
- [ ] Sample queries executing
- [ ] Monitoring alerts configured
- [ ] Backup procedures tested
- [ ] Documentation updated
- [ ] Team training completed

---

## Summary

This 5-VM minimal deployment provides:

✅ **Core HA**: PostgreSQL, Kafka, etcd, Keycloak have full redundancy  
✅ **All Components**: Every service from the full platform  
✅ **Production Ready**: Suitable for small-to-medium workloads  
⚠️ **Limited Scalability**: Plan to scale when workload grows  
⚠️ **Some SPOFs**: Non-critical services lack redundancy  
⚠️ **Resource Constrained**: Careful monitoring required

**Best For**:

- Small to medium enterprises (10-50 users)
- Development/staging environments
- Proof of concept deployments
- Budget-constrained deployments
- Initial platform rollout

**Not Suitable For**:

- Mission-critical workloads requiring 99.99% uptime
- Large data volumes (>5 TB active data)
- High concurrency (>50 concurrent users)
- Strict compliance requirements

---

## Next Steps

1. Review this minimal architecture with your team
2. Provision the 5 VMs with recommended specifications
3. Proceed with installation using Ansible playbooks
4. Plan for scaling path when requirements grow

For installation guides and Ansible automation, refer to the main deployment documentation.
