# Datalyptica Platform - Technology Stack Specification

**Document Version:** 1.0.0  
**Date:** November 30, 2025  
**Status:** Production Specification

---

## 1. System Prerequisites

### 1.1 Hardware Requirements

#### **Minimum Requirements (Development)**

- **CPU:** 4 cores (x86_64 or ARM64)
- **RAM:** 8GB
- **Storage:** 50GB SSD
- **Network:** 1 Gbps

#### **Recommended Requirements (Development)**

- **CPU:** 8 cores (x86_64 or ARM64)
- **RAM:** 16GB
- **Storage:** 100GB NVMe SSD
- **Network:** 10 Gbps

#### **Production Requirements (per node)**

- **CPU:** 16+ cores (x86_64 recommended)
- **RAM:** 64GB+ (128GB for data-intensive workloads)
- **Storage:** 500GB+ NVMe SSD (OS + apps) + dedicated data volumes
- **Network:** 10-25 Gbps with jumbo frames (MTU 9000)

#### **Production Cluster Sizing**

**Small Deployment (< 10 users, < 10TB data)**

- 3 nodes × 16 cores, 64GB RAM, 1TB SSD
- Total: 48 cores, 192GB RAM, 3TB storage

**Medium Deployment (10-50 users, 10-100TB data)**

- 5 nodes × 32 cores, 128GB RAM, 2TB SSD
- Total: 160 cores, 640GB RAM, 10TB storage

**Large Deployment (50+ users, 100TB+ data)**

- 10+ nodes × 64 cores, 256GB RAM, 4TB SSD
- Total: 640+ cores, 2.5TB+ RAM, 40TB+ storage

### 1.2 Software Prerequisites

#### **Operating System**

| OS                           | Version        | Status         | Notes              |
| ---------------------------- | -------------- | -------------- | ------------------ |
| **Ubuntu LTS**               | 22.04, 24.04   | ✅ Recommended | Best tested        |
| **Red Hat Enterprise Linux** | 8.x, 9.x       | ✅ Supported   | Enterprise support |
| **CentOS Stream**            | 9              | ✅ Supported   | RHEL compatible    |
| **Rocky Linux**              | 8.x, 9.x       | ✅ Supported   | RHEL compatible    |
| **Debian**                   | 11, 12         | ✅ Supported   | Stable             |
| **macOS**                    | 13+ (Ventura+) | ⚠️ Dev Only    | ARM64 and x86_64   |
| **Windows**                  | 11 with WSL2   | ⚠️ Dev Only    | Via WSL2 Ubuntu    |

**Kernel Requirements:**

- Linux kernel 5.10+ (5.15+ recommended)
- cgroups v2 support
- OverlayFS support
- Namespace support (PID, NET, IPC, UTS, Mount)

#### **Container Runtime**

| Runtime           | Version | Status          | Notes                 |
| ----------------- | ------- | --------------- | --------------------- |
| **Docker Engine** | 24.0+   | ✅ Recommended  | Development & Testing |
| **containerd**    | 1.7+    | ✅ Recommended  | Production (K8s)      |
| **CRI-O**         | 1.28+   | ✅ Supported    | Production (K8s)      |
| **Podman**        | 4.0+    | ⚠️ Experimental | Rootless support      |

**Docker Compose:**

- Version: 2.20+ (v2 syntax required)
- Plugin-based installation (not standalone binary)

#### **Kubernetes** (Production Only)

| Distribution           | Version   | Status           | Notes         |
| ---------------------- | --------- | ---------------- | ------------- |
| **Vanilla Kubernetes** | 1.28-1.30 | ✅ Recommended   | Upstream K8s  |
| **Amazon EKS**         | 1.28-1.30 | ✅ Supported     | AWS managed   |
| **Azure AKS**          | 1.28-1.30 | ✅ Supported     | Azure managed |
| **Google GKE**         | 1.28-1.30 | ✅ Supported     | GCP managed   |
| **Red Hat OpenShift**  | 4.13-4.15 | ✅ Supported     | Enterprise    |
| **Rancher RKE2**       | v1.28+    | ✅ Supported     | On-prem       |
| **K3s**                | v1.28+    | ⚠️ Dev/Edge Only | Lightweight   |

**Kubernetes Minimum Cluster:**

- 3 control plane nodes (HA)
- 3+ worker nodes
- Storage provisioner (Rook/Ceph, Longhorn, or CSI driver)
- CNI plugin (Calico, Cilium, or Flannel)
- Ingress controller (Nginx, Traefik, or Istio)

#### **Additional Tools**

| Tool        | Version     | Purpose                | Required    |
| ----------- | ----------- | ---------------------- | ----------- |
| **git**     | 2.40+       | Version control        | ✅ Yes      |
| **kubectl** | matches K8s | K8s CLI                | K8s only    |
| **helm**    | 3.12+       | Package manager        | K8s only    |
| **openssl** | 3.0+        | Certificate generation | ✅ Yes      |
| **jq**      | 1.6+        | JSON processing        | ✅ Yes      |
| **curl**    | 7.88+       | HTTP client            | ✅ Yes      |
| **psql**    | 15+         | PostgreSQL client      | Recommended |

---

## 2. Component Specifications

### 2.1 Storage Layer

#### **PostgreSQL**

- **Version:** 17.7 (17.x series)
- **Base Image:** `postgres:17.7-alpine3.20`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/postgresql:v1.0.0`
- **Purpose:** Metadata storage for Nessie, Keycloak
- **Configuration:**
  - `wal_level: logical` (for CDC)
  - `max_connections: 100`
  - `shared_buffers: 25% of RAM`
  - `effective_cache_size: 75% of RAM`
  - `work_mem: RAM / (max_connections * 3)`
  - `maintenance_work_mem: RAM / 16`
- **Extensions:** None required (vanilla PostgreSQL)
- **Backup:** pg_dump, pg_basebackup, WAL archiving
- **HA Solution:**
  - Docker: Patroni 3.x + etcd 3.5.11 + HAProxy 2.9
  - Kubernetes: CloudNativePG Operator or Zalando Operator

#### **MinIO**

- **Version:** RELEASE.2024-latest
- **Base Image:** `minio/minio:latest`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/minio:v1.0.0`
- **Purpose:** S3-compatible object storage (data lake storage)
- **Configuration:**
  - Bucket: `lakehouse` (default warehouse)
  - Region: `us-east-1` (default)
  - Versioning: Enabled
  - Encryption: Server-side (SSE-C) for production
- **Performance:**
  - Throughput: 10+ GB/s per node
  - IOPS: 100k+ 4KB reads/writes
  - Latency: <10ms (local SSD)
- **HA Solution:**
  - Distributed MinIO (4+ nodes)
  - Erasure coding (EC:4+2 minimum)
  - MinIO Operator for Kubernetes

#### **Apache Iceberg**

- **Version:** 1.4.0+
- **Format Version:** v2 (row-level operations)
- **Catalog:** Nessie (REST catalog)
- **Features:**
  - ACID transactions
  - Schema evolution
  - Partition evolution
  - Time travel queries
  - Hidden partitioning
- **File Formats:**
  - Data: Parquet (default), ORC, Avro
  - Metadata: JSON
- **Compaction:** Auto-compaction via Spark/Flink

### 2.2 Catalog Layer

#### **Project Nessie**

- **Version:** 0.76.0+
- **Base Image:** `projectnessie/nessie:0.76.0`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/nessie:v1.0.0`
- **Purpose:** Git-like data catalog with version control
- **API:** REST API v2
- **Storage Backend:** PostgreSQL (JDBC)
- **Configuration:**
  - Default branch: `main`
  - Version store: `JDBC`
  - Connection pool: 10 initial, 50 max
- **Features:**
  - Multi-table transactions
  - Branch/merge/tag operations
  - Access control (via Keycloak)
  - Audit logging
- **Performance:**
  - Commit latency: <100ms
  - Query latency: <50ms
  - Concurrent users: 100+

### 2.3 Compute Layer

#### **Trino (SQL Query Engine)**

- **Version:** 440+
- **Base Image:** `trinodb/trino:440`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/trino:v1.0.0`
- **Purpose:** Interactive SQL queries, data exploration
- **Catalogs:**
  - `iceberg`: Nessie catalog for Iceberg tables
  - `postgresql`: JDBC connector for metadata
  - `system`: System information
- **Configuration:**
  - Coordinator: 1 node
  - Workers: 1+ nodes (scalable)
  - Memory: 80% of available RAM per node
  - Task concurrency: CPU cores × 2
- **Performance:**
  - Query latency: <1s for simple queries
  - Throughput: 10+ GB/s scan rate
  - Concurrency: 50+ simultaneous queries

#### **Apache Spark**

- **Version:** 3.5.0
- **Scala Version:** 2.12
- **Base Image:** `apache/spark:3.5.0-scala2.12-java17-python3`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/spark:v1.0.0`
- **Purpose:** Batch processing, ETL, ML
- **Components:**
  - Master: 1 node
  - Worker: 1+ nodes (scalable)
  - Executor memory: 4GB+ per worker
  - Executor cores: 4+ per worker
- **Iceberg Support:**
  - `iceberg-spark-runtime`: 1.4.0+
  - Write: Enabled
  - Read: Enabled
  - Merge: Enabled (Iceberg v2)
- **Performance:**
  - Processing: 1+ TB/hour per worker
  - Shuffle: 100+ MB/s
  - Join: 1B+ rows/minute

#### **Apache Flink**

- **Version:** 1.18.0
- **Base Image:** `flink:1.18.0-scala_2.12-java11`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/flink:v1.0.0`
- **Purpose:** Stream processing, real-time analytics
- **Components:**
  - JobManager: 1 node (3+ for HA)
  - TaskManager: 1+ nodes (scalable)
  - Task slots: 4+ per TaskManager
  - Memory: 4GB+ per TaskManager
- **Iceberg Support:**
  - `iceberg-flink-runtime`: 1.4.0+
  - Streaming writes: Enabled
  - CDC ingestion: Enabled
  - Upserts: Enabled (Iceberg v2)
- **Performance:**
  - Throughput: 1M+ events/sec
  - Latency: <100ms (end-to-end)
  - Checkpointing: Every 5 minutes

#### **ClickHouse**

- **Version:** 24.x
- **Base Image:** `clickhouse/clickhouse-server:24-alpine`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/clickhouse:v1.0.0`
- **Purpose:** OLAP, real-time analytics, aggregations
- **Configuration:**
  - Max memory: 75% of available RAM
  - Max concurrent queries: 100
  - Background pool size: CPU cores
- **Performance:**
  - Query latency: <10ms for aggregations
  - Ingestion: 100k+ rows/sec
  - Compression: 10:1 typical ratio

#### **dbt (Data Build Tool)**

- **Version:** 1.7+
- **Base Image:** `ghcr.io/dbt-labs/dbt-core:1.7-latest`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/dbt:v1.0.0`
- **Purpose:** Data transformation, modeling, testing
- **Adapters:**
  - `dbt-trino`: SQL transformations via Trino
  - `dbt-postgres`: Metadata operations
- **Features:**
  - SQL-based transformations
  - Data quality tests
  - Documentation generation
  - Lineage tracking

### 2.4 Streaming Layer

#### **Apache Kafka**

- **Version:** 3.6+ (KRaft mode, no ZooKeeper)
- **Base Image:** `confluentinc/cp-kafka:7.5.0`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/kafka:v1.0.0`
- **Purpose:** Message broker, event streaming
- **Configuration:**
  - Mode: KRaft (controller + broker)
  - Replication factor: 1 (dev), 3 (prod)
  - Min in-sync replicas: 1 (dev), 2 (prod)
  - Log retention: 168 hours (7 days)
  - Log segment size: 1 GB
  - Partitions: 3+ per topic
- **Performance:**
  - Throughput: 1M+ msg/sec per broker
  - Latency: <10ms (p99)
  - Storage: 10+ TB per broker

#### **Confluent Schema Registry**

- **Version:** 7.5+
- **Base Image:** `confluentinc/cp-schema-registry:7.5.0`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/schema-registry:v1.0.0`
- **Purpose:** Schema management for Kafka (Avro, JSON Schema, Protobuf)
- **Storage:** Internal Kafka topic (`_schemas`)
- **Compatibility:** BACKWARD (default), FORWARD, FULL
- **Performance:**
  - Schema lookups: <5ms
  - Schema registrations: <50ms
  - Concurrent clients: 1000+

#### **Kafka Connect (Debezium)**

- **Version:** Kafka Connect 3.6 + Debezium 2.5
- **Base Image:** `debezium/connect:2.5`
- **Custom Image:** `ghcr.io/datalyptica/datalyptica/kafka-connect:v1.0.0`
- **Purpose:** Change Data Capture (CDC) from databases
- **Connectors:**
  - Debezium PostgreSQL: CDC from PostgreSQL
  - Debezium MySQL: CDC from MySQL (optional)
  - JDBC Source: Batch ingestion
  - S3 Sink: Export to MinIO/S3
- **Configuration:**
  - Group ID: `debezium-connect-cluster`
  - Offset storage: Kafka topic
  - Config storage: Kafka topic
  - Status storage: Kafka topic
- **Performance:**
  - Throughput: 10k+ changes/sec
  - Latency: <1s (commit to Kafka)

### 2.5 Observability Layer

#### **Prometheus**

- **Version:** 2.48.0
- **Image:** `prom/prometheus:v2.48.0`
- **Purpose:** Metrics collection and storage
- **Configuration:**
  - Scrape interval: 15s
  - Retention: 15 days
  - Storage: 1GB per million active series per day
- **Exporters:**
  - Node Exporter: System metrics
  - Kafka Exporter: Kafka metrics
  - PostgreSQL Exporter: Database metrics
  - JMX Exporter: Java application metrics
- **Performance:**
  - Ingestion: 1M+ samples/sec
  - Query latency: <100ms
  - Active series: 10M+

#### **Grafana**

- **Version:** 10.2.2
- **Image:** `grafana/grafana:10.2.2`
- **Purpose:** Visualization, dashboards, alerting
- **Datasources:**
  - Prometheus (metrics)
  - Loki (logs)
  - PostgreSQL (metadata)
- **Dashboards:**
  - Platform overview
  - Component-specific dashboards
  - Business metrics
- **Authentication:** Keycloak (SSO)

#### **Loki**

- **Version:** 2.9.3
- **Image:** `grafana/loki:2.9.3`
- **Purpose:** Log aggregation and querying
- **Configuration:**
  - Retention: 30 days
  - Chunk size: 1MB
  - Max query length: 12000h
- **Performance:**
  - Ingestion: 100MB/s
  - Query latency: <1s
  - Storage: 10GB per million log lines

#### **Grafana Alloy**

- **Version:** 1.0.0
- **Image:** `grafana/alloy:v1.0.0`
- **Purpose:** Log collection agent (replaces Promtail)
- **Features:**
  - Multi-format parsing
  - Label extraction
  - Filtering and routing
- **Performance:**
  - Throughput: 100k+ lines/sec
  - CPU: <5% per collector
  - Memory: <100MB per collector

#### **Alertmanager**

- **Version:** 0.27.0
- **Image:** `prom/alertmanager:v0.27.0`
- **Purpose:** Alert routing and notification
- **Integrations:**
  - Email (SMTP)
  - Slack
  - PagerDuty
  - Webhook (custom)
- **Features:**
  - Grouping and deduplication
  - Silencing
  - Inhibition rules

### 2.6 Identity & Access Management

#### **Keycloak**

- **Version:** 23.0
- **Image:** `quay.io/keycloak/keycloak:23.0`
- **Purpose:** SSO, Identity Provider, RBAC
- **Protocols:**
  - OAuth 2.0
  - OpenID Connect
  - SAML 2.0
- **Features:**
  - Multi-factor authentication (MFA)
  - Social login providers
  - User federation (LDAP/AD)
  - Fine-grained authorization
- **Performance:**
  - Concurrent users: 10k+
  - Login latency: <200ms
  - Token validation: <10ms

---

## 3. Network Requirements

### 3.1 Port Mappings

#### **External Ports (Host → Container)**

| Service               | Port  | Protocol  | Purpose              | Access Level |
| --------------------- | ----- | --------- | -------------------- | ------------ |
| **PostgreSQL**        | 5432  | TCP       | Database             | Internal     |
| **MinIO API**         | 9000  | TCP/HTTP  | S3 API               | Internal     |
| **MinIO Console**     | 9001  | TCP/HTTP  | Web UI               | Admin        |
| **MinIO HTTPS**       | 9443  | TCP/HTTPS | S3 API (SSL)         | External     |
| **Nessie HTTP**       | 19120 | TCP/HTTP  | REST API             | Internal     |
| **Nessie HTTPS**      | 19443 | TCP/HTTPS | REST API (SSL)       | External     |
| **Trino**             | 8080  | TCP/HTTP  | SQL Query            | Internal     |
| **Spark Master**      | 7077  | TCP       | Spark Protocol       | Internal     |
| **Spark UI**          | 8082  | TCP/HTTP  | Web UI               | Monitoring   |
| **Flink JobManager**  | 8081  | TCP/HTTP  | Web UI + API         | Monitoring   |
| **Kafka**             | 9092  | TCP       | Kafka Protocol       | Internal     |
| **Kafka SSL**         | 9093  | TCP       | Kafka Protocol (SSL) | External     |
| **Schema Registry**   | 8081  | TCP/HTTP  | REST API             | Internal     |
| **Kafka Connect**     | 8083  | TCP/HTTP  | REST API             | Internal     |
| **Kafka UI**          | 8090  | TCP/HTTP  | Web UI               | Monitoring   |
| **ClickHouse HTTP**   | 8123  | TCP/HTTP  | SQL API              | Internal     |
| **ClickHouse Native** | 9000  | TCP       | Native Protocol      | Internal     |
| **Prometheus**        | 9090  | TCP/HTTP  | Metrics API + UI     | Monitoring   |
| **Grafana**           | 3000  | TCP/HTTP  | Web UI               | Users        |
| **Loki**              | 3100  | TCP/HTTP  | Logs API             | Internal     |
| **Alertmanager**      | 9095  | TCP/HTTP  | Alerts API + UI      | Monitoring   |
| **Keycloak**          | 8180  | TCP/HTTP  | Web UI + API         | Users        |
| **Keycloak HTTPS**    | 8543  | TCP/HTTPS | Web UI + API (SSL)   | External     |

#### **Internal Ports (Container-only)**

| Service              | Port | Purpose                   |
| -------------------- | ---- | ------------------------- |
| **Patroni REST API** | 8008 | Health checks, switchover |
| **etcd Client**      | 2379 | etcd API                  |
| **etcd Peer**        | 2380 | etcd replication          |
| **HAProxy Stats**    | 8404 | Statistics dashboard      |
| **Kafka Controller** | 9094 | KRaft coordination        |

### 3.2 Network Segmentation

#### **Management Network** (`172.20.0.0/16`)

- Purpose: Monitoring, logging, authentication
- Services: Grafana, Prometheus, Loki, Alloy, Alertmanager, Keycloak
- Firewall: Restricted to admin IPs

#### **Control Network** (`172.21.0.0/16`)

- Purpose: Coordination, message broker
- Services: Kafka, Schema Registry, Kafka UI, Flink, Spark
- Firewall: Internal only

#### **Data Network** (`172.22.0.0/16`)

- Purpose: Query engines, data access
- Services: Trino, Nessie, Kafka Connect, ClickHouse, dbt
- Firewall: Internal + authenticated external

#### **Storage Network** (`172.23.0.0/16`)

- Purpose: Persistent storage, metadata
- Services: PostgreSQL, Patroni, etcd, HAProxy, MinIO
- Firewall: Internal only, most restricted

### 3.3 Bandwidth Requirements

**Per Node:**

- Minimum: 1 Gbps
- Recommended: 10 Gbps
- Production: 25 Gbps with jumbo frames

**Inter-Service Communication:**

- Kafka replication: 1-10 Gbps
- MinIO operations: 5-20 Gbps
- Trino distributed queries: 2-10 Gbps

### 3.4 DNS & Service Discovery

**Docker Compose:**

- Built-in DNS: `<service>.<project>.internal`
- Example: `postgresql.docker.internal`

**Kubernetes:**

- CoreDNS: `<service>.<namespace>.svc.cluster.local`
- Example: `postgresql.datalyptica.svc.cluster.local`

---

## 4. Storage Requirements

### 4.1 Volume Types

#### **Data Volumes (Hot Storage)**

- **Purpose:** Active data, Iceberg tables
- **Technology:** MinIO distributed
- **IOPS:** 10k+ read/write
- **Throughput:** 1+ GB/s
- **Capacity:** 10TB+ per node
- **Redundancy:** Erasure coding (EC:4+2 or higher)

#### **Metadata Volumes**

- **Purpose:** PostgreSQL, Nessie catalog
- **Technology:** Local SSD or NVMe
- **IOPS:** 5k+ read/write
- **Throughput:** 500+ MB/s
- **Capacity:** 100GB+ per node
- **Redundancy:** Patroni replication or K8s PVC replication

#### **Log Volumes**

- **Purpose:** Application logs, Loki storage
- **Technology:** SSD
- **IOPS:** 1k+ write
- **Throughput:** 100+ MB/s
- **Capacity:** 1TB+ per node
- **Retention:** 30 days

#### **Checkpoint/State Volumes**

- **Purpose:** Flink checkpoints, Spark shuffle
- **Technology:** SSD
- **IOPS:** 5k+ read/write
- **Throughput:** 1+ GB/s
- **Capacity:** 500GB+ per worker
- **Redundancy:** Application-level (not required)

### 4.2 Capacity Planning

**Development Environment:**

- Total: 200GB
  - Data: 50GB
  - Metadata: 10GB
  - Logs: 10GB
  - Application: 30GB
  - OS: 50GB
  - Buffer: 50GB

**Small Production (10TB data):**

- Total per node: 4TB
  - Data: 3TB (10TB × 3 replicas / 10 nodes)
  - Metadata: 100GB
  - Logs: 100GB
  - Checkpoints: 500GB
  - Buffer: 300GB

**Medium Production (100TB data):**

- Total per node: 25TB
  - Data: 20TB
  - Metadata: 500GB
  - Logs: 500GB
  - Checkpoints: 2TB
  - Buffer: 2TB

**Large Production (1PB+ data):**

- Total per node: 100TB+
  - Data: 80TB+
  - Metadata: 2TB
  - Logs: 2TB
  - Checkpoints: 10TB
  - Buffer: 6TB

### 4.3 Backup Storage

**Strategy:** 3-2-1 Rule

- 3 copies of data
- 2 different media types
- 1 off-site copy

**Requirements:**

- Capacity: 2× production data size
- Retention: 30 days (daily) + 12 months (monthly)
- Location: Off-site or different availability zone

---

## 5. Compatibility Matrix

### 5.1 Component Interdependencies

| Component         | Depends On                         | Min Version        | Notes           |
| ----------------- | ---------------------------------- | ------------------ | --------------- |
| **Nessie**        | PostgreSQL                         | 15+                | JDBC compatible |
| **Trino**         | Nessie                             | 0.76.0+            | REST catalog v2 |
| **Spark**         | Nessie, MinIO                      | 0.76.0+, any       | Iceberg runtime |
| **Flink**         | Nessie, MinIO, Kafka               | 0.76.0+, any, 3.6+ | Streaming       |
| **Kafka Connect** | Kafka, Schema Registry, PostgreSQL | 3.6+, 7.5+, 15+    | CDC             |
| **Keycloak**      | PostgreSQL                         | 15+                | JDBC compatible |
| **Grafana**       | Prometheus, Loki                   | 2.48+, 2.9+        | Datasources     |

### 5.2 Version Compatibility

#### **Iceberg Support Matrix**

| Engine         | Iceberg Version | Read v1 | Read v2 | Write v1 | Write v2 | Row-level Ops              |
| -------------- | --------------- | ------- | ------- | -------- | -------- | -------------------------- |
| **Trino 440+** | 1.4.0+          | ✅      | ✅      | ✅       | ✅       | ✅ (MERGE, DELETE)         |
| **Spark 3.5**  | 1.4.0+          | ✅      | ✅      | ✅       | ✅       | ✅ (MERGE, UPDATE, DELETE) |
| **Flink 1.18** | 1.4.0+          | ✅      | ✅      | ✅       | ✅       | ✅ (UPSERT)                |

#### **Nessie Catalog Compatibility**

| Client                | Nessie Version | API Version | Features     |
| --------------------- | -------------- | ----------- | ------------ |
| **Trino**             | 0.76.0+        | v2          | Full support |
| **Spark**             | 0.76.0+        | v2          | Full support |
| **Flink**             | 0.76.0+        | v2          | Full support |
| **Python (pynessie)** | 0.76.0+        | v2          | Full support |

#### **Kafka Ecosystem Compatibility**

| Component           | Kafka Version | Compatible | Notes                |
| ------------------- | ------------- | ---------- | -------------------- |
| **Schema Registry** | 3.6+          | ✅         | Same major version   |
| **Kafka Connect**   | 3.6+          | ✅         | Same version         |
| **Debezium**        | 3.4-3.7       | ✅         | Protocol compatible  |
| **Flink Connector** | 3.0+          | ✅         | Backwards compatible |

### 5.3 Cloud Provider Compatibility

#### **AWS**

- ✅ EC2 instances (all types)
- ✅ EKS (Managed Kubernetes)
- ✅ EBS volumes
- ✅ S3 (alternative to MinIO)
- ✅ RDS PostgreSQL (alternative to self-hosted)

#### **Azure**

- ✅ Virtual Machines (all series)
- ✅ AKS (Managed Kubernetes)
- ✅ Managed Disks
- ✅ Blob Storage (via S3 gateway)
- ✅ Azure Database for PostgreSQL

#### **Google Cloud**

- ✅ Compute Engine (all types)
- ✅ GKE (Managed Kubernetes)
- ✅ Persistent Disks
- ✅ Cloud Storage (via S3 gateway)
- ✅ Cloud SQL for PostgreSQL

#### **On-Premises**

- ✅ VMware vSphere
- ✅ Red Hat OpenStack
- ✅ Nutanix AHV
- ✅ Bare metal

---

## 6. Performance Baselines

### 6.1 Measured Performance (Current)

Based on comprehensive testing:

| Metric                     | Value         | Methodology                           |
| -------------------------- | ------------- | ------------------------------------- |
| **Kafka Throughput**       | 990 msg/sec   | 1000 messages produced, measured time |
| **PostgreSQL Connections** | 10 concurrent | Connection pool test                  |
| **Trino Query Latency**    | <1s           | Simple SELECT on 1M rows              |
| **Failover Time (HA)**     | 2-15s         | Patroni switchover tests              |
| **Replication Lag**        | 0 bytes       | Streaming replication                 |
| **Startup Time (Dev)**     | 2 min         | docker compose up -d                  |
| **Startup Time (HA)**      | 5 min         | docker compose -f ha.yml up -d        |

### 6.2 Expected Production Performance

| Metric               | Expected    | Conditions                     |
| -------------------- | ----------- | ------------------------------ |
| **Kafka Throughput** | 1M+ msg/sec | Per broker, 3+ brokers         |
| **PostgreSQL QPS**   | 10k+        | Read-heavy, connection pooling |
| **Trino Scan Rate**  | 10+ GB/s    | Per worker, local storage      |
| **Spark Processing** | 1+ TB/hour  | Per worker, batch ETL          |
| **Flink Latency**    | <100ms      | End-to-end, simple pipeline    |
| **MinIO Throughput** | 10+ GB/s    | Per node, sequential           |

### 6.3 Scalability Targets

| Dimension              | Target         | Notes                   |
| ---------------------- | -------------- | ----------------------- |
| **Data Volume**        | 1 PB+          | With distributed MinIO  |
| **Tables**             | 100k+          | Nessie catalog          |
| **Concurrent Users**   | 1000+          | Query engines           |
| **Concurrent Queries** | 100+           | Trino/Spark             |
| **Streaming Events**   | 1M+ events/sec | Kafka + Flink           |
| **Data Retention**     | 5+ years       | Compliance requirements |

---

## 7. License Compliance

### 7.1 Open Source Licenses

| Component             | License    | Commercial Use | Modifications | Distribution        | Attribution |
| --------------------- | ---------- | -------------- | ------------- | ------------------- | ----------- |
| **Apache Components** | Apache 2.0 | ✅             | ✅            | ✅                  | ✅          |
| **PostgreSQL**        | PostgreSQL | ✅             | ✅            | ✅                  | ❌          |
| **Grafana**           | AGPL 3.0   | ✅             | ✅            | ⚠️ Network copyleft | ✅          |
| **Loki**              | AGPL 3.0   | ✅             | ✅            | ⚠️ Network copyleft | ✅          |
| **MinIO**             | AGPL 3.0   | ✅             | ✅            | ⚠️ Network copyleft | ✅          |
| **Keycloak**          | Apache 2.0 | ✅             | ✅            | ✅                  | ✅          |

**Apache 2.0 Components:**

- Kafka, Spark, Flink, Iceberg, Nessie, Trino, ClickHouse, dbt
- Prometheus, Alertmanager, Alloy
- Most connectors and libraries

**AGPL 3.0 Note:**

- Modifications must be shared if software is provided as a service
- Does not affect internal use
- Grafana Cloud and MinIO Enterprise offer commercial licenses

### 7.2 Compliance Recommendations

1. **Track Dependencies:** Use SBOM (Software Bill of Materials)
2. **Review Regularly:** Check for license changes (quarterly)
3. **Document Modifications:** Keep change logs for AGPL components
4. **Commercial Alternatives:** Consider if AGPL is problematic:
   - Grafana Enterprise
   - MinIO Enterprise
   - Altinity ClickHouse (commercial support)

---

## 8. Version Lifecycle

### 8.1 Update Policy

**Critical Security Updates:**

- Apply within 7 days of disclosure
- Test in dev/staging first
- Rollback plan required

**Minor Updates:**

- Apply quarterly (Q1, Q2, Q3, Q4)
- 2-week testing window
- Update dev → staging → prod

**Major Updates:**

- Plan annually
- 1-month testing window
- May require data migration

### 8.2 End-of-Life (EOL) Tracking

| Component           | Current Version | EOL Date      | Next Major Version |
| ------------------- | --------------- | ------------- | ------------------ |
| **PostgreSQL 17**   | 17.7            | Nov 2029      | 18.x (Nov 2025)    |
| **Kafka 3.6**       | 3.6.0           | TBD           | 3.7 (Q1 2025)      |
| **Trino 440**       | 440             | N/A (rolling) | 441+ (monthly)     |
| **Keycloak 23**     | 23.0            | TBD           | 24.x (Q1 2025)     |
| **Kubernetes 1.28** | 1.28            | Oct 2024      | 1.31 (Aug 2024)    |

---

## 9. Certification & Testing

### 9.1 Test Coverage

- ✅ Unit tests: Core functionality
- ✅ Integration tests: Service-to-service
- ✅ End-to-end tests: Full pipeline
- ✅ Performance tests: Throughput, latency
- ✅ Failover tests: HA scenarios
- ⚠️ Chaos engineering: Planned
- ⚠️ Load tests (TPC-H): Planned

### 9.2 Certification Status

- ✅ Docker Compose: Validated
- ✅ Docker Swarm: Compatible (not recommended)
- ⚠️ Kubernetes: In progress
- ⚠️ OpenShift: Planned
- ⚠️ Cloud providers: AWS (in progress), Azure (planned), GCP (planned)

---

## Appendices

### A. Quick Reference

**Default Credentials:**

- PostgreSQL: `postgres` / see Docker Secrets
- MinIO: `minioadmin` / see Docker Secrets
- Grafana: `admin` / see Docker Secrets
- Keycloak: `admin` / see Docker Secrets

**Default Ports:**

- Web UIs: 3000 (Grafana), 8090 (Kafka UI), 9001 (MinIO)
- Databases: 5432 (PostgreSQL), 9000 (ClickHouse)
- APIs: 8080 (Trino), 19120 (Nessie), 8081 (Flink)

### B. Troubleshooting

**Common Issues:**

1. **Out of memory:** Increase Docker memory limit or node RAM
2. **Port conflicts:** Check for services using default ports
3. **Volume permissions:** Ensure correct ownership (user 1000)
4. **Network issues:** Verify DNS resolution and firewall rules

**Support:**

- Documentation: `docs/`
- GitHub Issues: github.com/datalyptica/datalyptica/issues
- Community: discussions forum

---

**Document Control:**

- **Version:** 1.0.0
- **Last Updated:** November 30, 2025
- **Next Review:** February 28, 2026
- **Owner:** Platform Architecture Team




