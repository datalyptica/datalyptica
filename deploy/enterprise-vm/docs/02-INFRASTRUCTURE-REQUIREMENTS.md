# Datalyptica Enterprise Infrastructure Requirements

**Version:** 2.0.0  
**Last Updated:** December 3, 2025

---

## Executive Summary

This document details the infrastructure requirements for deploying Datalyptica Data Platform in an enterprise environment using native VM installations with full high availability.

### Key Requirements

- **Total VMs**: 50
- **Total vCPUs**: 640 cores
- **Total RAM**: 2,560 GB (2.5 TB)
- **Local Storage**: ~50 TB SSD
- **Object Storage**: 100+ TB (enterprise S3-compatible)
- **Network**: 10/40 Gbps with VLAN segmentation
- **Operating System**: RHEL 9.3 or Ubuntu 22.04 LTS

---

## Infrastructure Bill of Materials

### Compute Resources

#### VM Resource Summary by Tier

| Tier          | VMs    | Total vCPUs | Total RAM (GB) | Total Storage (TB) |
| ------------- | ------ | ----------- | -------------- | ------------------ |
| Load Balancer | 3      | 12          | 24             | 0.15               |
| Catalog       | 6      | 80          | 320            | 6.5                |
| Coordination  | 3      | 12          | 48             | 0.3                |
| Streaming     | 11     | 148         | 592            | 25.3               |
| Processing    | 12     | 272         | 1,088          | 8.4                |
| Query         | 9      | 208         | 832            | 8.9                |
| Analytics     | 7      | 80          | 320            | 2.8                |
| Monitoring    | 9      | 68          | 272            | 10.3               |
| IAM           | 6      | 40          | 160            | 0.6                |
| **TOTAL**     | **66** | **920**     | **3,656**      | **63.25**          |

### Storage Requirements

#### Enterprise Object Storage

**Type**: S3-Compatible Enterprise Solution  
**Vendors**: Dell ECS, NetApp StorageGRID, Scality RING, Hitachi HCP, MinIO Enterprise

**Capacity Planning**:

```
Initial Deployment:  100 TB raw capacity
Growth Rate:         20% per quarter (estimated)
3-Year Capacity:     500 TB
Recommended:         1 PB for future-proofing
```

**Performance Requirements**:

- **Throughput**: 10 GB/s read, 5 GB/s write (aggregate)
- **IOPS**: 100,000 read IOPS, 50,000 write IOPS
- **Latency**: <10ms for metadata operations, <50ms for data
- **Availability**: 99.99% (4 nines)
- **Durability**: 99.999999999% (11 nines)

**Features Required**:

- S3 API compatibility (v4 signatures)
- Multi-part upload support
- Server-side encryption (SSE-S3 or SSE-KMS)
- Versioning
- Lifecycle policies
- Cross-region replication (for DR)
- IAM integration
- Audit logging

**Bucket Configuration**:

```
datalyptica-warehouse/     # Main data lake (80% of capacity)
datalyptica-staging/        # Staging area (10%)
datalyptica-backups/        # Backups (10%)
datalyptica-ml/             # ML artifacts (5%)
datalyptica-logs/           # Application logs (5%)
```

#### Shared File Storage (NFS/SAN)

**Purpose**: Shared configurations, user home directories, HA state

**Capacity**: 10 TB  
**Performance**:

- Throughput: 1 GB/s
- IOPS: 10,000
- Latency: <5ms

**Mount Points**:

```
/opt/datalyptica/shared     # Common configs (100 GB)
/home/jupyter               # JupyterHub homes (5 TB)
/opt/spark/recovery         # Spark HA state (50 GB)
/opt/datalyptica/logs       # Log staging (2 TB)
```

**HA Requirements**:

- Clustered NFS (e.g., RHEL HA Cluster, NetApp ONTAP)
- Active-active or active-standby
- Automatic failover <30s
- Snapshot capability (hourly snapshots, 7-day retention)

#### Local Storage per VM

| VM Type           | Storage Type | Capacity   | Purpose        | IOPS   | Throughput |
| ----------------- | ------------ | ---------- | -------------- | ------ | ---------- |
| PostgreSQL        | NVMe SSD     | 2 TB       | Data + WAL     | 50,000 | 2 GB/s     |
| Kafka Broker      | NVMe SSD     | 4 TB       | Log segments   | 30,000 | 1.5 GB/s   |
| Spark Worker      | SSD          | 1 TB       | Shuffle data   | 20,000 | 1 GB/s     |
| Flink TaskManager | SSD          | 500 GB     | State + temp   | 15,000 | 800 MB/s   |
| Trino Worker      | SSD          | 500 GB     | Spill to disk  | 15,000 | 800 MB/s   |
| ClickHouse        | NVMe SSD     | 2 TB       | Tables + parts | 40,000 | 1.5 GB/s   |
| Prometheus        | SSD          | 2 TB       | Time-series DB | 10,000 | 500 MB/s   |
| Loki              | SSD          | 2 TB       | Log storage    | 10,000 | 500 MB/s   |
| Other VMs         | SSD          | 100-200 GB | OS + apps      | 5,000  | 300 MB/s   |

**Note**: Use RAID 10 for critical data (PostgreSQL, Kafka) where possible

---

## Network Requirements

### Physical Network Infrastructure

#### Network Tiers

**1. Management Network (Out-of-band)**

- VLAN: 10
- Subnet: 10.10.0.0/24
- Speed: 1 Gbps
- Purpose: SSH, IPMI, Ansible, Bastion access
- Switches: Dedicated management switches

**2. Application Network**

- VLAN: 20-29 (multiple subnets)
- Subnet: 10.20.0.0/16
- Speed: 10 Gbps (minimum), 25 Gbps (recommended)
- Purpose: Inter-service communication
- Switches: Core 10/25/40Gb switches with redundancy

**3. Storage Network**

- VLAN: 30
- Subnet: 10.30.0.0/24
- Speed: 40 Gbps (or 10Gb bonded)
- Purpose: Object storage access, NFS/SAN
- Switches: High-performance storage switches
- Jumbo Frames: MTU 9000 enabled

**4. External/DMZ Network**

- VLAN: 100
- Subnet: Public IP range
- Speed: 1-10 Gbps
- Purpose: Load balancer external interface
- Firewall: Required between DMZ and internal

#### Network Topology

```
                    ┌─────────────────┐
                    │  Core Routers   │
                    │  (Redundant)    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼────────┐    │    ┌─────────▼────────┐
     │  Firewall HA    │    │    │  Storage Network │
     │   (Active-Act)  │    │    │  40Gb Switches   │
     └────────┬────────┘    │    └──────────────────┘
              │             │
     ┌────────▼────────┐    │
     │  DMZ Switch     │    │
     │  (Load Balance) │    │
     └─────────────────┘    │
                            │
              ┌─────────────▼──────────────┐
              │  Application Core Switches │
              │  10/25Gb - Redundant Pair  │
              └─────────────┬──────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
    ┌─────▼─────┐    ┌──────▼──────┐   ┌─────▼─────┐
    │ToR Switch │    │ ToR Switch  │   │ToR Switch │
    │  Rack 1   │    │   Rack 2    │   │  Rack N   │
    └───────────┘    └─────────────┘   └───────────┘
```

#### Network Interface Configuration

**Per VM NIC Requirements**:

| VM Tier                  | NICs | Config                                                 | Purpose                 |
| ------------------------ | ---- | ------------------------------------------------------ | ----------------------- |
| Load Balancer            | 3    | 1x Mgmt (1G)<br>1x Internal (10G)<br>1x External (10G) | Multi-homed for DMZ     |
| Catalog (PostgreSQL)     | 3    | 1x Mgmt (1G)<br>1x App (10G)<br>1x Storage (10G)       | DB replication + backup |
| Kafka                    | 3    | 1x Mgmt (1G)<br>1x App (10G)<br>1x Storage (10G)       | High throughput         |
| Processing (Spark/Flink) | 3    | 1x Mgmt (1G)<br>1x App (10G)<br>1x Storage (10G)       | Data processing         |
| Query (Trino/CH)         | 3    | 1x Mgmt (1G)<br>1x App (10G)<br>1x Storage (10G)       | Query execution         |
| Analytics                | 2    | 1x Mgmt (1G)<br>1x App (10G)                           | General services        |
| Monitoring               | 2    | 1x Mgmt (1G)<br>1x App (10G)                           | Metrics collection      |

**Bonding/Teaming**:

- Application NICs: LACP (802.3ad) with active-active
- Storage NICs: LACP with active-active
- Management: Single interface (no bonding needed)

#### IP Address Allocation

**Subnet Plan**:

```
10.10.0.0/24        Management Network
  10.10.0.1-10        Reserved (gateway, DNS)
  10.10.0.11-30       Load Balancers
  10.10.0.31-50       Catalog tier
  10.10.0.51-70       Coordination
  10.10.0.71-100      Streaming tier
  10.10.0.101-130     Processing tier
  10.10.0.131-150     Query tier
  10.10.0.151-170     Analytics tier
  10.10.0.171-190     Monitoring tier
  10.10.0.191-210     IAM tier

10.20.1.0/24        Load Balancer subnet
10.20.10.0/24       Catalog subnet
10.20.20.0/24       Streaming subnet
10.20.30.0/24       Processing subnet
10.20.40.0/24       Query subnet
10.20.50.0/24       Analytics subnet
10.20.60.0/24       Monitoring subnet
10.20.70.0/24       IAM subnet

10.30.0.0/24        Storage network
  10.30.0.1-10        Object storage endpoints
  10.30.0.11-20       NFS/SAN endpoints
  10.30.0.21-250      VM storage interfaces
```

#### DNS Requirements

**Internal DNS Zones**:

```
datalyptica.local               # Main domain
catalog.datalyptica.local       # Catalog services
stream.datalyptica.local        # Streaming services
process.datalyptica.local       # Processing services
query.datalyptica.local         # Query services
analytics.datalyptica.local     # Analytics services
monitor.datalyptica.local       # Monitoring services
```

**Required DNS Records**:

```
# Virtual IPs (for HA services)
pg-vip.catalog.datalyptica.local        -> 10.20.10.100
nessie-vip.catalog.datalyptica.local    -> 10.20.10.101
kafka-vip.stream.datalyptica.local      -> 10.20.20.100
redis-vip.datalyptica.local             -> 10.20.70.100
trino-vip.query.datalyptica.local       -> 10.20.40.100

# Individual nodes (for direct access)
pg01.catalog.datalyptica.local          -> 10.20.10.11
pg02.catalog.datalyptica.local          -> 10.20.10.12
pg03.catalog.datalyptica.local          -> 10.20.10.13
...
```

**External DNS** (public-facing):

```
datalyptica.company.com         -> Load Balancer VIP (public IP)
*.datalyptica.company.com       -> Load Balancer VIP (wildcard)
```

#### Firewall Rules

**External → DMZ (Inbound)**:

```
Source: ANY
Destination: Load Balancer VIP
Ports: 443/tcp (HTTPS)
Action: ALLOW

Source: Trusted IPs (admin ranges)
Destination: Bastion Host
Ports: 22/tcp (SSH)
Action: ALLOW

All other: DENY
```

**DMZ → Internal**:

```
Source: Load Balancers
Destination: Application subnets
Ports: Application ports (8080, 8081, etc.)
Action: ALLOW

All other: DENY
```

**Internal Application Network** (inter-subnet):

```
PostgreSQL:       5432/tcp
Nessie:           19120/tcp
Kafka:            9092/tcp, 9093/tcp (controller)
Schema Registry:  8085/tcp
Redis:            6379/tcp
Spark:            7077/tcp, 4040-4041/tcp, 18080/tcp
Flink:            6123/tcp, 8081/tcp
Trino:            8080/tcp
ClickHouse:       8123/tcp, 9000/tcp, 9181/tcp (keeper)
Airflow:          8082/tcp
Prometheus:       9090/tcp
Grafana:          3000/tcp
Keycloak:         8080/tcp
etcd:             2379-2380/tcp

Action: ALLOW (within application network)
```

**Storage Network**:

```
Source: All application VMs
Destination: Object storage endpoints
Ports: 443/tcp, 9000/tcp (S3 API)
Action: ALLOW

Source: NFS clients
Destination: NFS servers
Ports: 2049/tcp (NFS), 111/tcp (portmap)
Action: ALLOW
```

#### Network Security

**TLS/SSL Requirements**:

- All external traffic: TLS 1.3 minimum
- Internal traffic: TLS 1.2 minimum (service-to-service)
- Certificate management: Internal CA or enterprise PKI
- Certificate rotation: Automated via Ansible/scripts

**Network Segmentation**:

- Microsegmentation between tiers
- East-west traffic inspection (optional, for advanced security)
- Zero trust network principles

---

## Operating System Requirements

### Supported OS Versions

**Recommended**:

1. **Red Hat Enterprise Linux (RHEL) 9.3** (Primary recommendation)

   - Extended lifecycle support
   - Enterprise support
   - SELinux integration
   - Better ecosystem for Java/JVM applications

2. **Ubuntu Server 22.04 LTS** (Alternative)
   - Long-term support until 2027
   - Wider community support
   - Simpler package management

### OS Configuration Standards

#### Base Packages (All VMs)

**RHEL 9**:

```bash
# System utilities
yum install -y epel-release
yum install -y vim git wget curl net-tools bind-utils telnet tcpdump
yum install -y sysstat iotop htop ntp chrony
yum install -y python3 python3-pip
yum install -y openssl ca-certificates
yum install -y firewalld fail2ban
yum install -y ansible  # On management/bastion only
```

**Ubuntu 22.04**:

```bash
# System utilities
apt-get update
apt-get install -y vim git wget curl net-tools dnsutils telnet tcpdump
apt-get install -y sysstat iotop htop ntp chrony
apt-get install -y python3 python3-pip
apt-get install -y openssl ca-certificates
apt-get install -y ufw fail2ban
apt-get install -y ansible  # On management/bastion only
```

#### Java/JVM Installation

Most components require Java (OpenJDK):

```bash
# RHEL
yum install -y java-17-openjdk java-17-openjdk-devel

# Ubuntu
apt-get install -y openjdk-17-jdk openjdk-17-jre

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> /etc/profile.d/java.sh
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile.d/java.sh
```

**Required Java Version by Component**:

- Kafka 3.9: Java 11 or 17 (17 recommended)
- Spark 3.5: Java 11 or 17 (17 recommended)
- Flink 1.20: Java 11 or 17 (17 recommended)
- Trino 469: Java 17 (required)
- Nessie 0.98: Java 17 (required)

#### System Tuning

**Kernel Parameters** (`/etc/sysctl.conf`):

```ini
# Network tuning
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10000 65535

# File system
fs.file-max = 2097152
fs.nr_open = 2097152

# Virtual memory
vm.swappiness = 1
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# For Kafka and high-throughput services
vm.max_map_count = 262144
```

**File Limits** (`/etc/security/limits.conf`):

```
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
```

**Disable Transparent Huge Pages** (for databases):

```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# Make persistent
cat >> /etc/rc.local <<EOF
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
EOF
chmod +x /etc/rc.local
```

#### Time Synchronization

**Critical**: All VMs must have synchronized time (±100ms tolerance)

```bash
# Configure chrony
cat > /etc/chrony.conf <<EOF
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF

systemctl enable chronyd
systemctl restart chronyd
```

#### Security Hardening

**SELinux (RHEL)**:

```bash
# Set to enforcing mode (after testing in permissive)
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
```

**Firewall**:

```bash
# RHEL (firewalld)
systemctl enable firewalld
systemctl start firewalld

# Ubuntu (ufw)
systemctl enable ufw
ufw enable
```

**SSH Hardening** (`/etc/ssh/sshd_config`):

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

---

## Software Prerequisites

### Version Matrix

| Component       | Version    | Installation Method | Package Source           |
| --------------- | ---------- | ------------------- | ------------------------ |
| PostgreSQL      | 16.2       | RPM/DEB             | Official PostgreSQL repo |
| Patroni         | 3.3.2      | pip                 | PyPI                     |
| etcd            | 3.5.16     | Binary              | GitHub releases          |
| Kafka           | 3.9.0      | Binary              | Apache mirror            |
| Schema Registry | 7.8.0      | Binary              | Confluent                |
| Nessie          | 0.98.2     | Binary/Java         | GitHub releases          |
| Spark           | 3.5.4      | Binary              | Apache mirror            |
| Flink           | 1.20.0     | Binary              | Apache mirror            |
| Trino           | 469        | Binary/RPM          | Trino.io                 |
| ClickHouse      | 24.12.2.59 | RPM/DEB             | ClickHouse repo          |
| Airflow         | 2.10.4     | pip (venv)          | PyPI                     |
| Redis           | 7.4.1      | Source/RPM          | Redis.io                 |
| Prometheus      | 3.0.1      | Binary              | GitHub releases          |
| Grafana         | 11.4.0     | RPM/DEB             | Grafana repo             |
| Loki            | 3.3.2      | Binary              | GitHub releases          |
| Alertmanager    | 0.28.0     | Binary              | GitHub releases          |
| HAProxy         | 2.9.x      | RPM/DEB             | OS repository            |
| Keepalived      | 2.2.x      | RPM/DEB             | OS repository            |
| Keycloak        | 26.0.7     | Binary/Java         | Keycloak.org             |
| JupyterHub      | 5.2.1      | pip (venv)          | PyPI                     |
| MLflow          | 2.19.0     | pip (venv)          | PyPI                     |
| Superset        | 4.1.1      | pip (venv)          | PyPI                     |

### Python Environment

**Python Version**: 3.11+ (for Airflow, JupyterHub, MLflow, Superset)

**Virtual Environment Strategy**:

```bash
# Install python 3.11
## RHEL
yum install -y python3.11 python3.11-pip python3.11-venv

## Ubuntu
add-apt-repository ppa:deadsnakes/ppa
apt-get update
apt-get install -y python3.11 python3.11-venv python3.11-dev

# Create venvs per application
python3.11 -m venv /opt/airflow/venv
python3.11 -m venv /opt/jupyterhub/venv
python3.11 -m venv /opt/mlflow/venv
python3.11 -m venv /opt/superset/venv
```

---

## Monitoring & Observability

### Monitoring Endpoints

**Node Exporter** (on all VMs):

- Port: 9100
- Metrics: CPU, Memory, Disk, Network

**Service-Specific Exporters**:

- PostgreSQL Exporter: 9187
- Kafka Exporter: 9308
- Redis Exporter: 9121
- Spark Metrics: 4040 (built-in)
- Flink Metrics: 8081 (built-in)
- Trino Metrics: 8080/metrics (built-in)
- ClickHouse Metrics: 8123/metrics (built-in)

### Log Collection

**Promtail** (on all VMs):

- Collects logs from /var/log and application logs
- Forwards to Loki cluster
- Port: 9080 (HTTP)

### Health Checks

**Load Balancer Health Checks**:

- Interval: 10 seconds
- Timeout: 5 seconds
- Unhealthy threshold: 3 consecutive failures
- Healthy threshold: 2 consecutive successes

---

## Backup & Recovery Infrastructure

### Backup Storage Requirements

**Capacity**: 20% of primary data (estimated 10-20 TB initially)  
**Location**: Separate from primary object storage (ideally different region/site)  
**Retention**:

- Daily backups: 30 days
- Weekly backups: 90 days
- Monthly backups: 1 year

### Backup Network

**Dedicated backup VLAN** (optional but recommended):

- Separate from production traffic
- Lower priority QoS
- Scheduled during maintenance windows

---

## Cost Estimation

### CapEx (Capital Expenditure)

**Compute** (50 VMs @ $5,000/VM average): $250,000  
**Network** (Switches, routers, firewalls): $150,000  
**Storage**:

- Object Storage (1 PB): $500,000 - $2,000,000 (depending on vendor)
- SAN/NFS (10 TB): $50,000
- Local SSD (63 TB across VMs): Included in VM cost

**Total CapEx**: $950,000 - $2,450,000

### OpEx (Operating Expenditure) - Annual

**Licenses**:

- RHEL subscriptions (50 VMs): $60,000/year
- Enterprise support contracts: $100,000/year

**Personnel**:

- Platform engineers (3 FTEs): $450,000/year
- DevOps engineers (2 FTEs): $300,000/year

**Power & Cooling**: $50,000/year

**Total OpEx**: $960,000/year

---

## Procurement Checklist

- [ ] VM/Server procurement approved
- [ ] Network equipment ordered
- [ ] Storage solution selected and ordered
- [ ] OS licenses procured
- [ ] IP address ranges allocated
- [ ] DNS zones delegated
- [ ] VLANs configured
- [ ] Firewall rules defined
- [ ] Backup solution implemented
- [ ] Monitoring infrastructure ready
- [ ] DR site identified (if required)

---

## Next Document

See `02-INSTALLATION-GUIDE.md` for detailed installation procedures.
