# Datalyptica Enterprise VM Architecture Design

**Version:** 2.0.0  
**Deployment Model:** Native VM Installation (No Docker)  
**High Availability:** Full HA for All Components  
**Storage Backend:** Enterprise Object Storage (S3-Compatible)  
**Last Updated:** December 3, 2025

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [High Availability Design](#high-availability-design)
3. [VM Distribution & Sizing](#vm-distribution--sizing)
4. [Network Architecture](#network-architecture)
5. [Storage Architecture](#storage-architecture)
6. [Component Details](#component-details)
7. [Disaster Recovery](#disaster-recovery)

---

## Architecture Overview

### Design Principles

1. **Native Installation**: All services installed directly on VMs (no containers)
2. **High Availability**: Minimum 3 nodes for critical services, active-active where possible
3. **Enterprise Storage**: Integration with enterprise S3-compatible object storage
4. **No Zookeeper**: Kafka KRaft mode, etcd for coordination where needed
5. **Scalability**: Horizontal scaling for processing and query layers
6. **Security**: TLS everywhere, network segmentation, centralized IAM

### Logical Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Load Balancer Tier                          │
│              HAProxy (3 nodes) + Keepalived (VIP)                   │
│                    Active-Active with Failover                      │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
┌───────────────────▼───┐  ┌──────▼──────────┐  ┌─────▼─────────────┐
│   Catalog Tier (HA)   │  │  IAM Tier (HA)  │  │  Storage Tier     │
│  ┌─────────────────┐  │  │  ┌───────────┐  │  │  ┌─────────────┐  │
│  │ PostgreSQL (3)  │  │  │  │ Keycloak  │  │  │  │ Enterprise  │  │
│  │ Patroni + etcd  │  │  │  │ (3 nodes) │  │  │  │ Object      │  │
│  │ Sync Replication│  │  │  │ Cluster   │  │  │  │ Storage     │  │
│  └─────────────────┘  │  │  └───────────┘  │  │  │ (S3 API)    │  │
│  ┌─────────────────┐  │  │  ┌───────────┐  │  │  └─────────────┘  │
│  │ Nessie (3)      │  │  │  │ Redis (3) │  │  │  ┌─────────────┐  │
│  │ Active-Active   │  │  │  │ Sentinel  │  │  │  │ NFS/SAN     │  │
│  └─────────────────┘  │  │  └───────────┘  │  │  │ Shared      │  │
└───────────────────────┘  └─────────────────┘  │  │ Storage     │  │
                                                │  └─────────────┘  │
                                                └───────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
┌───────────────────▼───┐  ┌──────▼──────────┐  ┌─────▼─────────────┐
│  Streaming Tier (HA)  │  │ Processing Tier │  │  Query Tier (HA)  │
│  ┌─────────────────┐  │  │  ┌───────────┐  │  │  ┌─────────────┐  │
│  │ Kafka (5 nodes) │  │  │  │ Spark (HA)│  │  │  │ Trino (HA)  │  │
│  │ KRaft Mode      │  │  │  │ 1 Master  │  │  │  │ 1 Coord HA  │  │
│  │ Quorum 5        │  │  │  │ N Workers │  │  │  │ N Workers   │  │
│  └─────────────────┘  │  │  └───────────┘  │  │  └─────────────┘  │
│  ┌─────────────────┐  │  │  ┌───────────┐  │  │  ┌─────────────┐  │
│  │ Schema Registry │  │  │  │ Flink (HA)│  │  │  │ ClickHouse  │  │
│  │ (3 nodes)       │  │  │  │ JobMgr HA │  │  │  │ Cluster (3) │  │
│  └─────────────────┘  │  │  │ N TaskMgr │  │  │  │ + Keeper(3) │  │
│  ┌─────────────────┐  │  │  └───────────┘  │  │  └─────────────┘  │
│  │ Kafka Connect   │  │  └─────────────────┘  └───────────────────┘
│  │ Cluster (3)     │  │
│  └─────────────────┘  │
└───────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
┌───────────────────▼───┐  ┌──────▼──────────┐
│   Analytics Tier      │  │ Monitoring Tier │
│  ┌─────────────────┐  │  │  ┌───────────┐  │
│  │ Airflow (HA)    │  │  │  │ Prometheus│  │
│  │ Scheduler: 2    │  │  │  │ (3 nodes) │  │
│  │ Workers: N      │  │  │  │ HA Setup  │  │
│  │ WebServer: 2    │  │  │  └───────────┘  │
│  └─────────────────┘  │  │  ┌───────────┐  │
│  ┌─────────────────┐  │  │  │ Grafana   │  │
│  │ JupyterHub (HA) │  │  │  │ (3 nodes) │  │
│  │ Hub: 2          │  │  │  │ SQLite→PG │  │
│  │ Spawner: Dyn    │  │  │  └───────────┘  │
│  └─────────────────┘  │  │  ┌───────────┐  │
│  ┌─────────────────┐  │  │  │ Loki (3)  │  │
│  │ MLflow (HA)     │  │  │  │ Cluster   │  │
│  │ Tracking: 2     │  │  │  └───────────┘  │
│  └─────────────────┘  │  │  ┌───────────┐  │
│  ┌─────────────────┐  │  │  │ Alert Mgr │  │
│  │ Superset (HA)   │  │  │  │ (3 nodes) │  │
│  │ WebServer: 2    │  │  │  │ Cluster   │  │
│  │ Workers: N      │  │  │  └───────────┘  │
│  └─────────────────┘  │  └─────────────────┘
└───────────────────────┘
```

---

## High Availability Design

### HA Summary by Component

| Component       | HA Strategy          | Min Nodes | Quorum | Failover Time | RPO  | RTO  |
| --------------- | -------------------- | --------- | ------ | ------------- | ---- | ---- |
| HAProxy         | Keepalived VIP       | 3         | N/A    | <1s           | 0    | <5s  |
| PostgreSQL      | Patroni + etcd       | 3         | 2/3    | <30s          | 0    | <1m  |
| Nessie          | Active-Active        | 3         | N/A    | <1s           | 0    | <5s  |
| Kafka           | KRaft Quorum         | 5         | 3/5    | <10s          | 0    | <30s |
| Schema Registry | Leader Election      | 3         | 2/3    | <5s           | 0    | <10s |
| Redis           | Sentinel             | 3         | 2/3    | <5s           | <1s  | <10s |
| Spark           | Standby Master       | 2         | N/A    | <1m           | 0    | <2m  |
| Flink           | Standby JobMgr       | 2         | N/A    | <30s          | <1s  | <1m  |
| Trino           | Multiple Coord       | 2         | N/A    | <1s           | N/A  | <5s  |
| ClickHouse      | Replication + Keeper | 3         | 2/3    | <5s           | 0    | <30s |
| Airflow         | Active Scheduler     | 2         | N/A    | <30s          | <1m  | <2m  |
| Keycloak        | Clustered            | 3         | N/A    | <1s           | 0    | <5s  |
| Prometheus      | Federation           | 3         | N/A    | N/A           | <15s | <1m  |
| Grafana         | Load Balanced        | 3         | N/A    | <1s           | 0    | <5s  |
| Loki            | Clustered            | 3         | N/A    | <5s           | <30s | <1m  |

### HA Patterns Used

1. **Active-Active**: HAProxy, Nessie, Trino Workers, All Web Services
2. **Active-Standby**: PostgreSQL (Patroni), Spark Master, Flink JobManager
3. **Quorum-Based**: Kafka (KRaft), etcd, ClickHouse Keeper, Redis Sentinel
4. **Federated**: Prometheus (with global query layer)
5. **Shared-Nothing with Replication**: Kafka, ClickHouse

---

## VM Distribution & Sizing

### Production Environment (Recommended)

#### Cluster Overview

- **Total VMs**: 50 VMs
- **Total vCPUs**: 640 cores
- **Total RAM**: 2,560 GB (2.5 TB)
- **Total Storage**: ~50 TB (excluding object storage)

### VM Groups

#### 1. Load Balancer Tier (3 VMs)

| VM Name | Role                 | vCPU | RAM  | Storage | OS     |
| ------- | -------------------- | ---- | ---- | ------- | ------ |
| lb01    | HAProxy + Keepalived | 4    | 8 GB | 50 GB   | RHEL 9 |
| lb02    | HAProxy + Keepalived | 4    | 8 GB | 50 GB   | RHEL 9 |
| lb03    | HAProxy + Keepalived | 4    | 8 GB | 50 GB   | RHEL 9 |

**Services**: HAProxy, Keepalived  
**Network**: Public-facing interface + Internal interface  
**VIP**: 1 Virtual IP for external access

---

#### 2. Catalog Tier (6 VMs)

**PostgreSQL Cluster (3 VMs)**

| VM Name | Role            | vCPU | RAM   | Storage  | Notes               |
| ------- | --------------- | ---- | ----- | -------- | ------------------- |
| pg01    | Patroni Primary | 16   | 64 GB | 2 TB SSD | Hot standby capable |
| pg02    | Patroni Standby | 16   | 64 GB | 2 TB SSD | Sync replication    |
| pg03    | Patroni Standby | 16   | 64 GB | 2 TB SSD | Sync replication    |

**Services**: PostgreSQL 16.2, Patroni 3.3.2, etcd client  
**Storage**: Local SSD for data, WAL, and pg_wal

**Nessie Cluster (3 VMs)**

| VM Name  | Role          | vCPU | RAM   | Storage | Notes  |
| -------- | ------------- | ---- | ----- | ------- | ------ |
| nessie01 | Nessie Server | 8    | 32 GB | 200 GB  | Active |
| nessie02 | Nessie Server | 8    | 32 GB | 200 GB  | Active |
| nessie03 | Nessie Server | 8    | 32 GB | 200 GB  | Active |

**Services**: Nessie 0.98.2 (connects to PostgreSQL cluster)

---

#### 3. Coordination Tier (3 VMs)

| VM Name | Role        | vCPU | RAM   | Storage    | Notes         |
| ------- | ----------- | ---- | ----- | ---------- | ------------- |
| etcd01  | etcd Member | 4    | 16 GB | 100 GB SSD | Quorum member |
| etcd02  | etcd Member | 4    | 16 GB | 100 GB SSD | Quorum member |
| etcd03  | etcd Member | 4    | 16 GB | 100 GB SSD | Quorum member |

**Services**: etcd 3.5.16 (for Patroni and general coordination)  
**Critical**: Required for PostgreSQL HA

---

#### 4. Streaming Tier (11 VMs)

**Kafka Cluster (5 VMs)**

| VM Name | Role                | vCPU | RAM   | Storage  | Notes            |
| ------- | ------------------- | ---- | ----- | -------- | ---------------- |
| kafka01 | Broker (Controller) | 16   | 64 GB | 4 TB SSD | KRaft controller |
| kafka02 | Broker (Controller) | 16   | 64 GB | 4 TB SSD | KRaft controller |
| kafka03 | Broker (Controller) | 16   | 64 GB | 4 TB SSD | KRaft controller |
| kafka04 | Broker              | 16   | 64 GB | 4 TB SSD | Data broker      |
| kafka05 | Broker              | 16   | 64 GB | 4 TB SSD | Data broker      |

**Services**: Apache Kafka 3.9.0 (KRaft mode, no Zookeeper)  
**Replication Factor**: 3  
**Min ISR**: 2

**Schema Registry Cluster (3 VMs)**

| VM Name  | Role            | vCPU | RAM   | Storage | Notes           |
| -------- | --------------- | ---- | ----- | ------- | --------------- |
| schema01 | Schema Registry | 4    | 16 GB | 100 GB  | Leader election |
| schema02 | Schema Registry | 4    | 16 GB | 100 GB  | Follower        |
| schema03 | Schema Registry | 4    | 16 GB | 100 GB  | Follower        |

**Services**: Confluent Schema Registry 7.8.0

**Kafka Connect Cluster (3 VMs)**

| VM Name   | Role           | vCPU | RAM   | Storage | Notes            |
| --------- | -------------- | ---- | ----- | ------- | ---------------- |
| connect01 | Connect Worker | 8    | 32 GB | 500 GB  | Distributed mode |
| connect02 | Connect Worker | 8    | 32 GB | 500 GB  | Distributed mode |
| connect03 | Connect Worker | 8    | 32 GB | 500 GB  | Distributed mode |

**Services**: Kafka Connect 3.9.0, Debezium 2.7

---

#### 5. Processing Tier (12 VMs)

**Spark Cluster**

| VM Name        | Role             | vCPU | RAM    | Storage  | Notes          |
| -------------- | ---------------- | ---- | ------ | -------- | -------------- |
| spark-master01 | Master (Active)  | 8    | 32 GB  | 200 GB   | Primary master |
| spark-master02 | Master (Standby) | 8    | 32 GB  | 200 GB   | Hot standby    |
| spark-worker01 | Worker           | 32   | 128 GB | 1 TB SSD | Executor node  |
| spark-worker02 | Worker           | 32   | 128 GB | 1 TB SSD | Executor node  |
| spark-worker03 | Worker           | 32   | 128 GB | 1 TB SSD | Executor node  |
| spark-worker04 | Worker           | 32   | 128 GB | 1 TB SSD | Executor node  |

**Services**: Apache Spark 3.5.4  
**Total Spark Capacity**: 128 cores, 512 GB RAM

**Flink Cluster**

| VM Name    | Role                 | vCPU | RAM   | Storage | Notes       |
| ---------- | -------------------- | ---- | ----- | ------- | ----------- |
| flink-jm01 | JobManager (Active)  | 8    | 32 GB | 200 GB  | Primary JM  |
| flink-jm02 | JobManager (Standby) | 8    | 32 GB | 200 GB  | Hot standby |
| flink-tm01 | TaskManager          | 16   | 64 GB | 500 GB  | Worker node |
| flink-tm02 | TaskManager          | 16   | 64 GB | 500 GB  | Worker node |
| flink-tm03 | TaskManager          | 16   | 64 GB | 500 GB  | Worker node |
| flink-tm04 | TaskManager          | 16   | 64 GB | 500 GB  | Worker node |

**Services**: Apache Flink 1.20.0  
**Total Flink Capacity**: 64 cores, 256 GB RAM

---

#### 6. Query Tier (9 VMs)

**Trino Cluster**

| VM Name        | Role        | vCPU | RAM    | Storage    | Notes              |
| -------------- | ----------- | ---- | ------ | ---------- | ------------------ |
| trino-coord01  | Coordinator | 16   | 64 GB  | 200 GB     | Active             |
| trino-coord02  | Coordinator | 16   | 64 GB  | 200 GB     | Active (discovery) |
| trino-worker01 | Worker      | 32   | 128 GB | 500 GB SSD | Query execution    |
| trino-worker02 | Worker      | 32   | 128 GB | 500 GB SSD | Query execution    |
| trino-worker03 | Worker      | 32   | 128 GB | 500 GB SSD | Query execution    |

**Services**: Trino 469  
**Total Trino Capacity**: 96 cores, 384 GB RAM

**ClickHouse Cluster**

| VM Name | Role            | vCPU | RAM   | Storage  | Notes              |
| ------- | --------------- | ---- | ----- | -------- | ------------------ |
| ch01    | ClickHouse Node | 16   | 64 GB | 2 TB SSD | Shard 1, Replica 1 |
| ch02    | ClickHouse Node | 16   | 64 GB | 2 TB SSD | Shard 1, Replica 2 |
| ch03    | ClickHouse Node | 16   | 64 GB | 2 TB SSD | Shard 2, Replica 1 |

**Services**: ClickHouse 24.12.2.59, ClickHouse Keeper (replaces ZooKeeper)  
**Configuration**: 2 shards, 2 replicas per shard

---

#### 7. Analytics Tier (7 VMs)

**Airflow Cluster**

| VM Name          | Role       | vCPU | RAM   | Storage | Notes           |
| ---------------- | ---------- | ---- | ----- | ------- | --------------- |
| airflow-web01    | Web Server | 4    | 16 GB | 100 GB  | Load balanced   |
| airflow-web02    | Web Server | 4    | 16 GB | 100 GB  | Load balanced   |
| airflow-sched01  | Scheduler  | 8    | 32 GB | 200 GB  | Active          |
| airflow-worker01 | Worker     | 16   | 64 GB | 500 GB  | Celery executor |
| airflow-worker02 | Worker     | 16   | 64 GB | 500 GB  | Celery executor |

**Services**: Apache Airflow 2.10.4, Celery, Redis (connects to Redis cluster)

**Other Analytics**

| VM Name   | Role            | vCPU | RAM   | Storage | Notes          |
| --------- | --------------- | ---- | ----- | ------- | -------------- |
| jupyter01 | JupyterHub      | 16   | 64 GB | 1 TB    | Multi-user hub |
| mlflow01  | MLflow Tracking | 8    | 32 GB | 500 GB  | Model registry |

**Note**: Superset can run on airflow-web nodes or separate VMs if needed

---

#### 8. Monitoring Tier (9 VMs)

**Prometheus Cluster**

| VM Name | Role       | vCPU | RAM   | Storage | Notes          |
| ------- | ---------- | ---- | ----- | ------- | -------------- |
| prom01  | Prometheus | 8    | 32 GB | 2 TB    | Time-series DB |
| prom02  | Prometheus | 8    | 32 GB | 2 TB    | Time-series DB |
| prom03  | Prometheus | 8    | 32 GB | 2 TB    | Time-series DB |

**Services**: Prometheus 3.0.1 (federation setup)

**Grafana Cluster**

| VM Name   | Role    | vCPU | RAM   | Storage | Notes         |
| --------- | ------- | ---- | ----- | ------- | ------------- |
| grafana01 | Grafana | 4    | 16 GB | 100 GB  | Load balanced |
| grafana02 | Grafana | 4    | 16 GB | 100 GB  | Load balanced |
| grafana03 | Grafana | 4    | 16 GB | 100 GB  | Load balanced |

**Services**: Grafana 11.4.0 (shared PostgreSQL backend)

**Loki Cluster & Alertmanager**

| VM Name    | Role         | vCPU | RAM   | Storage | Notes           |
| ---------- | ------------ | ---- | ----- | ------- | --------------- |
| loki01     | Loki         | 8    | 32 GB | 2 TB    | Log aggregation |
| loki02     | Loki         | 8    | 32 GB | 2 TB    | Log aggregation |
| alertmgr01 | Alertmanager | 4    | 16 GB | 100 GB  | Clustered       |

**Services**: Loki 3.3.2, Alertmanager 0.28.0

---

#### 9. IAM Tier (6 VMs)

**Keycloak Cluster**

| VM Name    | Role     | vCPU | RAM   | Storage | Notes     |
| ---------- | -------- | ---- | ----- | ------- | --------- |
| keycloak01 | Keycloak | 8    | 32 GB | 100 GB  | Clustered |
| keycloak02 | Keycloak | 8    | 32 GB | 100 GB  | Clustered |
| keycloak03 | Keycloak | 8    | 32 GB | 100 GB  | Clustered |

**Services**: Keycloak 26.0.7 (connects to PostgreSQL cluster)

**Redis Cluster (for caching & Airflow)**

| VM Name | Role             | vCPU | RAM   | Storage | Notes   |
| ------- | ---------------- | ---- | ----- | ------- | ------- |
| redis01 | Redis + Sentinel | 4    | 16 GB | 100 GB  | Master  |
| redis02 | Redis + Sentinel | 4    | 16 GB | 100 GB  | Replica |
| redis03 | Redis + Sentinel | 4    | 16 GB | 100 GB  | Replica |

**Services**: Redis 7.4.1 with Redis Sentinel

---

## Network Architecture

### Network Segmentation

```
┌─────────────────────────────────────────────────────────────────┐
│                     External Network (DMZ)                       │
│                 Public IPs: Load Balancers Only                  │
│                      VIP: 203.0.113.100                          │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                   Management Network (VLAN 10)                   │
│                     Network: 10.10.0.0/24                        │
│           SSH, Ansible, Monitoring Agents, Bastion               │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                  Application Network (VLAN 20)                   │
│                     Network: 10.20.0.0/16                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Load Balancer Subnet: 10.20.1.0/24                      │  │
│  │  HAProxy VMs: 10.20.1.11-13                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Catalog Subnet: 10.20.10.0/24                           │  │
│  │  PostgreSQL: 10.20.10.11-13                              │  │
│  │  Nessie: 10.20.10.21-23                                  │  │
│  │  etcd: 10.20.10.31-33                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Streaming Subnet: 10.20.20.0/24                         │  │
│  │  Kafka: 10.20.20.11-15                                   │  │
│  │  Schema Registry: 10.20.20.21-23                         │  │
│  │  Kafka Connect: 10.20.20.31-33                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Processing Subnet: 10.20.30.0/24                        │  │
│  │  Spark Masters: 10.20.30.11-12                           │  │
│  │  Spark Workers: 10.20.30.21-24                           │  │
│  │  Flink JMs: 10.20.30.31-32                               │  │
│  │  Flink TMs: 10.20.30.41-44                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Query Subnet: 10.20.40.0/24                             │  │
│  │  Trino Coordinators: 10.20.40.11-12                      │  │
│  │  Trino Workers: 10.20.40.21-23                           │  │
│  │  ClickHouse: 10.20.40.31-33                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Analytics Subnet: 10.20.50.0/24                         │  │
│  │  Airflow Web: 10.20.50.11-12                             │  │
│  │  Airflow Sched: 10.20.50.21                              │  │
│  │  Airflow Workers: 10.20.50.31-32                         │  │
│  │  JupyterHub: 10.20.50.41                                 │  │
│  │  MLflow: 10.20.50.51                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Monitoring Subnet: 10.20.60.0/24                        │  │
│  │  Prometheus: 10.20.60.11-13                              │  │
│  │  Grafana: 10.20.60.21-23                                 │  │
│  │  Loki: 10.20.60.31-32                                    │  │
│  │  Alertmanager: 10.20.60.41                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  IAM Subnet: 10.20.70.0/24                               │  │
│  │  Keycloak: 10.20.70.11-13                                │  │
│  │  Redis: 10.20.70.21-23                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                   Storage Network (VLAN 30)                      │
│                     Network: 10.30.0.0/24                        │
│      Enterprise Object Storage, NFS/SAN, Backup Storage          │
│                   High Bandwidth (10Gb/40Gb)                     │
└─────────────────────────────────────────────────────────────────┘
```

### Network Requirements

| Network Type | Bandwidth | Latency | Usage                          |
| ------------ | --------- | ------- | ------------------------------ |
| Management   | 1 Gbps    | <5ms    | SSH, Ansible, Monitoring       |
| Application  | 10 Gbps   | <1ms    | Inter-service communication    |
| Storage      | 40 Gbps   | <0.5ms  | Object storage, NFS/SAN access |
| External     | 1-10 Gbps | N/A     | User access via load balancer  |

### Firewall Rules

**Inbound (External → DMZ)**

- HTTPS (443) → Load Balancer VIP
- SSH (22) → Bastion Host only (from specific IPs)

**Internal Application Network**

- All VMs can communicate within their tier
- Cross-tier communication via specific ports only
- No direct external access (must go through LB)

**Storage Network**

- Read/Write access to object storage (S3 API: 443, 9000)
- NFS access (2049) for shared configuration
- iSCSI/FC for block storage if needed

---

## Storage Architecture

### Enterprise Object Storage Integration

**Storage Backend**: S3-Compatible Enterprise Object Storage  
**Examples**: Dell ECS, NetApp StorageGRID, Scality RING, Hitachi Content Platform

#### Bucket Organization

```
s3://datalyptica-warehouse/
├── iceberg/                 # Iceberg table data
│   ├── prod/               # Production namespace
│   │   ├── sales/
│   │   ├── customers/
│   │   └── transactions/
│   ├── staging/            # Staging namespace
│   └── dev/                # Development namespace
│
├── raw/                     # Raw ingestion data
│   ├── kafka-snapshots/
│   ├── batch-uploads/
│   └── streaming/
│
├── spark/                   # Spark work directory
│   ├── checkpoints/
│   ├── eventlogs/
│   └── temp/
│
├── flink/                   # Flink state backend
│   ├── checkpoints/
│   ├── savepoints/
│   └── ha/
│
├── ml/                      # ML artifacts
│   ├── models/
│   ├── features/
│   └── experiments/
│
└── backups/                 # Backup storage
    ├── postgresql/
    ├── kafka/
    └── configs/
```

#### Access Configuration

**S3 Endpoint**: `https://s3.enterprise.local` (example)  
**Authentication**: IAM roles or access keys  
**Encryption**: Server-side encryption (SSE-S3 or SSE-KMS)  
**Versioning**: Enabled for compliance  
**Lifecycle Policies**:

- Hot data: 0-90 days
- Warm data: 91-365 days (transition to archive tier)
- Cold data: 365+ days (archive or delete)

### Shared File Storage (NFS/SAN)

**Purpose**: Shared configurations, JupyterHub home directories, temporary shared storage

**Mount Points**:

- `/opt/datalyptica/shared` - Common configurations
- `/home/jupyter` - JupyterHub user homes
- `/opt/datalyptica/logs` - Centralized log storage (before Loki ingestion)

**Requirements**:

- 5-10 TB capacity
- High availability (clustered NFS or replicated SAN)
- Snapshot capabilities for backup

### Local Storage Requirements

**Per VM Type**:

- **PostgreSQL**: High-performance SSD for WAL and data (2 TB per node)
- **Kafka**: High-throughput SSD for log segments (4 TB per broker)
- **Spark Workers**: Fast local SSD for shuffle data (1 TB per worker)
- **ClickHouse**: High-performance SSD for tables (2 TB per node)
- **Prometheus/Loki**: High-capacity storage for time-series data (2 TB per node)

---

## Component Details

### 1. PostgreSQL HA with Patroni

**Architecture**: Active-Standby with Synchronous Replication

**Components**:

- PostgreSQL 16.2
- Patroni 3.3.2 (HA management)
- etcd 3.5.16 (distributed configuration store)
- HAProxy (connection pooling on catalog tier)

**Configuration**:

```yaml
Replication Mode: Synchronous
Synchronous Standbys: 1 (at least one standby must confirm)
Max Connections: 500
Shared Buffers: 16 GB (25% of RAM)
Effective Cache Size: 48 GB (75% of RAM)
WAL Level: replica
Archive Mode: on (to object storage)
```

**Databases**:

- `datalyptica` - Main platform database
- `nessie` - Nessie catalog metadata
- `keycloak` - Keycloak IAM data
- `airflow` - Airflow metadata
- `superset` - Superset metadata
- `grafana` - Grafana configuration
- `mlflow` - MLflow tracking data

**Backup Strategy**:

- Continuous WAL archiving to object storage
- Daily full backups using pg_basebackup
- PITR (Point-in-Time Recovery) capability
- Retention: 30 days

---

### 2. Apache Kafka (KRaft Mode)

**Architecture**: No Zookeeper - KRaft Consensus

**KRaft Configuration**:

- 5 brokers total
- 3 controllers (quorum nodes: kafka01, kafka02, kafka03)
- 5 brokers (all nodes participate in data)
- Quorum size: 3 (majority of 5)

**Kafka Configuration**:

```properties
# KRaft Mode
process.roles=broker,controller  # On controller nodes
controller.quorum.voters=1@kafka01:9093,2@kafka02:9093,3@kafka03:9093

# Replication
default.replication.factor=3
min.insync.replicas=2
unclean.leader.election.enable=false

# Performance
num.network.threads=8
num.io.threads=16
socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576

# Log Configuration
log.dirs=/data/kafka/logs
log.retention.hours=168  # 7 days
log.segment.bytes=1073741824  # 1 GB
log.retention.check.interval.ms=300000

# Compression
compression.type=lz4
```

**Topic Strategy**:

- Replication factor: 3
- Partitions: Based on throughput (12-24 per topic typically)
- Retention: 7 days (default), adjust per topic

---

### 3. Nessie Catalog (Active-Active)

**Architecture**: Stateless active-active cluster

**Configuration**:

- 3 Nessie servers behind load balancer
- Shared PostgreSQL database for state
- All nodes can handle read/write operations
- Version store type: JDBC (PostgreSQL)

**Nessie Configuration**:

```properties
nessie.version.store.type=JDBC
quarkus.datasource.jdbc.url=jdbc:postgresql://pg-vip:5432/nessie
nessie.version.store.persist.compression=GZIP
nessie.version.store.persist.max-batch-size=500
```

---

### 4. Apache Spark (HA Master)

**Architecture**: Active-Standby Master with Shared State

**HA Configuration**:

- 2 Spark Masters (active-standby)
- Automatic failover via etcd/ZooKeeper-free method
- Recovery mode: FILESYSTEM (NFS shared storage)
- 4 Worker nodes for execution

**Spark Configuration**:

```bash
SPARK_MASTER_OPTS="-Dspark.deploy.recoveryMode=FILESYSTEM \
  -Dspark.deploy.recoveryDirectory=/opt/datalyptica/shared/spark-recovery"

# On workers
SPARK_WORKER_CORES=28
SPARK_WORKER_MEMORY=120g
SPARK_WORKER_INSTANCES=1
```

**Iceberg Integration**:

```properties
spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.nessie.uri=http://nessie-vip:19120/api/v1
spark.sql.catalog.nessie.warehouse=s3a://datalyptica-warehouse/iceberg
spark.sql.catalog.nessie.io-impl=org.apache.iceberg.aws.s3.S3FileIO
```

---

### 5. Apache Flink (HA JobManager)

**Architecture**: Active-Standby JobManager with HA

**HA Configuration**:

- 2 JobManagers (active-standby)
- State backend: RocksDB with S3 checkpoints
- HA storage: S3 (flink/ha/)
- 4 TaskManagers for execution

**Flink Configuration**:

```yaml
# HA Configuration (no Zookeeper!)
high-availability: kubernetes # Or use standalone with custom impl
high-availability.storageDir: s3://datalyptica-warehouse/flink/ha

# State Backend
state.backend: rocksdb
state.checkpoints.dir: s3://datalyptica-warehouse/flink/checkpoints
state.savepoints.dir: s3://datalyptica-warehouse/flink/savepoints

# TaskManager
taskmanager.numberOfTaskSlots: 8
taskmanager.memory.process.size: 60g
```

---

### 6. Trino (Active-Active Coordinators)

**Architecture**: Multiple coordinators with discovery service

**HA Configuration**:

- 2 Trino coordinators (both active)
- Load balanced via HAProxy
- Discovery service for worker registration
- 3 Worker nodes for query execution

**Trino Configuration**:

```properties
# Coordinator
coordinator=true
node-scheduler.include-coordinator=false
discovery.uri=http://trino-coord01:8080

# Iceberg Catalog
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.catalog.uri=http://nessie-vip:19120/api/v1
iceberg.catalog.warehouse=s3://datalyptica-warehouse/iceberg
fs.native-s3.enabled=true
s3.endpoint=https://s3.enterprise.local
```

---

### 7. ClickHouse Cluster

**Architecture**: Replicated tables with ClickHouse Keeper (no Zookeeper)

**Configuration**:

- 3 ClickHouse nodes
- 3 ClickHouse Keeper nodes (embedded or separate)
- 2 shards, 2 replicas per shard
- Distributed queries across cluster

**ClickHouse Configuration**:

```xml
<clickhouse>
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>1</server_id>
        <raft_configuration>
            <server><id>1</id><hostname>ch01</hostname><port>9234</port></server>
            <server><id>2</id><hostname>ch02</hostname><port>9234</port></server>
            <server><id>3</id><hostname>ch03</hostname><port>9234</port></server>
        </raft_configuration>
    </keeper_server>

    <zookeeper>
        <node><host>ch01</host><port>9181</port></node>
        <node><host>ch02</host><port>9181</port></node>
        <node><host>ch03</host><port>9181</port></node>
    </zookeeper>

    <remote_servers>
        <analytics_cluster>
            <shard>
                <replica><host>ch01</host><port>9000</port></replica>
                <replica><host>ch02</host><port>9000</port></replica>
            </shard>
            <shard>
                <replica><host>ch03</host><port>9000</port></replica>
                <replica><host>ch01</host><port>9000</port></replica>
            </shard>
        </analytics_cluster>
    </remote_servers>
</clickhouse>
```

---

### 8. Airflow (Celery Executor with HA)

**Architecture**: HA Scheduler with Celery Workers

**Components**:

- 2 Web servers (load balanced)
- 1-2 Schedulers (HA mode with DB locking)
- N Celery workers (autoscaling)
- Redis cluster for Celery broker
- PostgreSQL for metadata

**Airflow Configuration**:

```python
# airflow.cfg
executor = CeleryExecutor
sql_alchemy_conn = postgresql://airflow:password@pg-vip:5432/airflow
celery_broker_url = redis://redis-vip:6379/0
celery_result_backend = db+postgresql://airflow:password@pg-vip:5432/airflow

# HA Scheduler
scheduler_health_check_threshold = 30
scheduler_zombie_task_threshold = 300
```

---

### 9. Monitoring Stack

**Prometheus HA**: Federation model with global query layer  
**Grafana HA**: Shared PostgreSQL backend, load balanced  
**Loki HA**: Distributed deployment with object storage  
**Alertmanager HA**: Clustered with gossip protocol

---

## Disaster Recovery

### Backup Strategy

| Component      | Backup Method            | Frequency          | Retention  | Storage          |
| -------------- | ------------------------ | ------------------ | ---------- | ---------------- |
| PostgreSQL     | WAL + pg_basebackup      | Continuous + Daily | 30 days    | Object Storage   |
| Kafka          | Mirror Maker 2           | Real-time          | 7 days     | DR Kafka Cluster |
| Object Storage | Cross-region replication | Real-time          | 90 days    | Secondary region |
| Configurations | Git + Ansible            | On change          | Indefinite | Git repository   |
| etcd           | Snapshot                 | Hourly             | 7 days     | Object Storage   |
| ClickHouse     | Backup tool              | Daily              | 30 days    | Object Storage   |

### Recovery Procedures

**RTO (Recovery Time Objective)**:

- Critical services: 15 minutes
- Non-critical services: 1 hour

**RPO (Recovery Point Objective)**:

- PostgreSQL: 0 (synchronous replication)
- Kafka: 0 (min.insync.replicas=2)
- Object Storage: 0 (synchronous writes)
- ClickHouse: <1 hour

---

## Next Steps

1. Review and approve architecture design
2. Provision VMs with specified configurations
3. Set up network segmentation and VLANs
4. Configure enterprise object storage endpoints
5. Proceed with installation guides (next document)

---

## Document Control

| Version | Date       | Author           | Changes                      |
| ------- | ---------- | ---------------- | ---------------------------- |
| 2.0.0   | 2025-12-03 | Datalyptica Team | Initial enterprise VM design |
