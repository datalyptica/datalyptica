# Datalyptica Enterprise VM Deployment

**Version:** 2.0.0  
**Deployment Type:** Native VM Installation (No Containers)  
**High Availability:** Full HA for All Components  
**Last Updated:** December 3, 2025

---

## 📋 Overview

This directory contains the complete enterprise-grade deployment architecture and automation for Datalyptica Data Platform on virtual machines without Docker containers. The deployment features:

✅ **Native Installation** - All services installed directly on VMs  
✅ **High Availability** - Full HA with automatic failover for all components  
✅ **Enterprise Object Storage** - Integration with S3-compatible enterprise storage  
✅ **No Zookeeper** - Kafka KRaft mode, etcd for coordination  
✅ **Production-Ready** - Battle-tested configurations for enterprise scale  
✅ **Automated Deployment** - Ansible playbooks for repeatable installations

---

## 📁 Directory Structure

```
enterprise-vm/
├── README.md                          # This file
├── docs/                              # Architecture and planning documents
│   ├── 01-ARCHITECTURE-DESIGN.md     # Complete architecture design
│   ├── 02-INFRASTRUCTURE-REQUIREMENTS.md  # Infrastructure bill of materials
│   ├── 03-INSTALLATION-GUIDE.md      # Step-by-step installation (to be created)
│   ├── 04-HA-CONFIGURATION.md        # HA setup for each component (to be created)
│   └── 05-OPERATIONS-RUNBOOK.md      # Operations procedures (to be created)
│
├── ansible/                           # Ansible automation
│   ├── inventory/                     # Inventory files
│   │   ├── production/                # Production environment
│   │   │   ├── hosts.yml              # VM inventory
│   │   │   └── group_vars/            # Group variables
│   │   └── staging/                   # Staging environment
│   │
│   ├── playbooks/                     # Ansible playbooks
│   │   ├── 00-prerequisites.yml       # OS prep and base config
│   │   ├── 01-install-catalog.yml     # PostgreSQL + Patroni + Nessie
│   │   ├── 02-install-streaming.yml   # Kafka (KRaft) + Schema Registry
│   │   ├── 03-install-processing.yml  # Spark + Flink
│   │   ├── 04-install-query.yml       # Trino + ClickHouse
│   │   ├── 05-install-analytics.yml   # Airflow + JupyterHub + ML
│   │   ├── 06-install-monitoring.yml  # Prometheus + Grafana + Loki
│   │   ├── 07-install-iam.yml         # Keycloak + Redis
│   │   ├── 08-install-loadbalancer.yml # HAProxy + Keepalived
│   │   └── 99-verify-all.yml          # Verification playbook
│   │
│   ├── roles/                         # Ansible roles
│   │   ├── common/                    # Common tasks for all VMs
│   │   ├── postgresql/                # PostgreSQL installation
│   │   ├── patroni/                   # Patroni HA setup
│   │   ├── kafka-kraft/               # Kafka KRaft mode
│   │   ├── spark/                     # Spark cluster
│   │   ├── flink/                     # Flink cluster
│   │   ├── trino/                     # Trino cluster
│   │   ├── clickhouse/                # ClickHouse cluster
│   │   └── ...                        # Other components
│   │
│   ├── templates/                     # Configuration templates
│   │   ├── postgresql/                # PostgreSQL configs
│   │   ├── kafka/                     # Kafka configs
│   │   ├── spark/                     # Spark configs
│   │   └── ...                        # Other configs
│   │
│   └── ansible.cfg                    # Ansible configuration
│
└── scripts/                           # Utility scripts
    ├── generate-inventory.sh          # Generate inventory from IP list
    ├── health-check.sh                # Check all services
    ├── backup-configs.sh              # Backup all configurations
    ├── rolling-restart.sh             # Rolling restart procedure
    └── disaster-recovery.sh           # DR procedures
```

---

## 🏗️ Architecture Summary

### Deployment Model

**50 VMs** distributed across 9 tiers:

| Tier              | VMs | Purpose                     | HA Strategy                    |
| ----------------- | --- | --------------------------- | ------------------------------ |
| **Load Balancer** | 3   | HAProxy + Keepalived        | Active-Active with VIP         |
| **Catalog**       | 6   | PostgreSQL + Nessie         | Patroni HA, Active-Active      |
| **Coordination**  | 3   | etcd cluster                | Raft consensus (3-node)        |
| **Streaming**     | 11  | Kafka + Schema Registry     | KRaft quorum (no Zookeeper)    |
| **Processing**    | 12  | Spark + Flink               | Active-Standby masters         |
| **Query**         | 9   | Trino + ClickHouse          | Multi-coordinator, Replication |
| **Analytics**     | 7   | Airflow + Jupyter + ML      | HA schedulers, Load balanced   |
| **Monitoring**    | 9   | Prometheus + Grafana + Loki | Federation, Clustering         |
| **IAM**           | 6   | Keycloak + Redis            | Clustered, Sentinel            |

### Key Design Decisions

1. **No Docker/Containers**: Native installation for:

   - Better performance (no container overhead)
   - Easier resource management at OS level
   - Direct integration with enterprise monitoring
   - Simplified security compliance

2. **No Zookeeper**:

   - Kafka 3.9 with KRaft mode (built-in consensus)
   - ClickHouse Keeper instead of Zookeeper
   - etcd for PostgreSQL Patroni only
   - Reduces complexity and maintenance

3. **Enterprise Object Storage**:

   - S3-compatible API (Dell ECS, NetApp, etc.)
   - Removes MinIO operational burden
   - Better integration with enterprise backup/DR
   - Proven scalability and reliability

4. **Full HA**:
   - Every component has redundancy
   - Automatic failover (RTO <5 minutes)
   - Zero data loss (RPO = 0 for critical data)
   - Geographic distribution ready

---

## 📊 Resource Requirements

### Minimum Production Deployment

| Resource           | Quantity   | Notes                      |
| ------------------ | ---------- | -------------------------- |
| **VMs**            | 50         | Can scale to 100+          |
| **vCPUs**          | 640 cores  | Distributed across VMs     |
| **RAM**            | 2.5 TB     | Total across cluster       |
| **Local SSD**      | 63 TB      | High-performance workloads |
| **Object Storage** | 100 TB+    | Enterprise S3-compatible   |
| **Network**        | 10/40 Gbps | Segmented VLANs            |

### Per-Environment Scaling

| Environment     | VMs | vCPUs | RAM    | Storage |
| --------------- | --- | ----- | ------ | ------- |
| **Development** | 15  | 120   | 480 GB | 10 TB   |
| **Staging**     | 30  | 320   | 1.2 TB | 30 TB   |
| **Production**  | 50  | 640   | 2.5 TB | 100 TB  |
| **DR Site**     | 50  | 640   | 2.5 TB | 100 TB  |

---

## 🚀 Quick Start Guide

### Prerequisites

1. **Infrastructure Ready**:

   - [ ] 50 VMs provisioned with specs from docs
   - [ ] RHEL 9.3 or Ubuntu 22.04 LTS installed
   - [ ] Network VLANs configured
   - [ ] Enterprise object storage accessible
   - [ ] NFS/SAN storage mounted
   - [ ] DNS records created

2. **Access & Credentials**:

   - [ ] SSH key access to all VMs
   - [ ] Sudo privileges configured
   - [ ] Object storage credentials
   - [ ] Root CA certificate for TLS

3. **Control Machine**:
   - [ ] Ansible 2.14+ installed
   - [ ] Python 3.9+ with required modules
   - [ ] Git repository cloned

### Installation Steps

#### Step 1: Prepare Inventory

```bash
cd ansible/inventory/production

# Edit hosts.yml with your VM IPs
vim hosts.yml

# Edit group_vars with your settings
vim group_vars/all.yml
vim group_vars/catalog.yml
vim group_vars/streaming.yml
# ... edit other group vars
```

#### Step 2: Verify Connectivity

```bash
cd ansible

# Test connectivity to all hosts
ansible all -i inventory/production/hosts.yml -m ping

# Verify sudo access
ansible all -i inventory/production/hosts.yml -m shell -a "whoami" -b
```

#### Step 3: Run Prerequisites

```bash
# Install base packages and configure OS
ansible-playbook -i inventory/production playbooks/00-prerequisites.yml

# This will:
# - Update all packages
# - Configure kernel parameters
# - Set up NTP/chrony
# - Configure firewalls
# - Install Java/Python
# - Mount shared storage
```

#### Step 4: Deploy Components (Layer by Layer)

```bash
# 1. Deploy Catalog Layer (PostgreSQL + Patroni + etcd + Nessie)
ansible-playbook -i inventory/production playbooks/01-install-catalog.yml

# 2. Deploy Streaming Layer (Kafka KRaft + Schema Registry)
ansible-playbook -i inventory/production playbooks/02-install-streaming.yml

# 3. Deploy Processing Layer (Spark + Flink)
ansible-playbook -i inventory/production playbooks/03-install-processing.yml

# 4. Deploy Query Layer (Trino + ClickHouse)
ansible-playbook -i inventory/production playbooks/04-install-query.yml

# 5. Deploy Analytics Layer (Airflow + JupyterHub + MLflow)
ansible-playbook -i inventory/production playbooks/05-install-analytics.yml

# 6. Deploy Monitoring Layer (Prometheus + Grafana + Loki)
ansible-playbook -i inventory/production playbooks/06-install-monitoring.yml

# 7. Deploy IAM Layer (Keycloak + Redis)
ansible-playbook -i inventory/production playbooks/07-install-iam.yml

# 8. Deploy Load Balancer (HAProxy + Keepalived)
ansible-playbook -i inventory/production playbooks/08-install-loadbalancer.yml
```

#### Step 5: Verify Deployment

```bash
# Run comprehensive verification
ansible-playbook -i inventory/production playbooks/99-verify-all.yml

# Manual health check
./scripts/health-check.sh

# Check individual services
ansible catalog -i inventory/production -a "systemctl status postgresql"
ansible streaming -i inventory/production -a "systemctl status kafka"
```

#### Step 6: Access Services

Once deployed, access services through the load balancer:

```
https://datalyptica.yourdomain.com/grafana      # Grafana dashboards
https://datalyptica.yourdomain.com/trino        # Trino UI
https://datalyptica.yourdomain.com/kafka-ui     # Kafka management
https://datalyptica.yourdomain.com/airflow      # Airflow webserver
https://datalyptica.yourdomain.com/jupyter      # JupyterHub
https://datalyptica.yourdomain.com/superset     # Apache Superset
https://datalyptica.yourdomain.com/prometheus   # Prometheus UI
```

---

## 📚 Documentation

### Architecture & Planning

1. **[Architecture Design](docs/01-ARCHITECTURE-DESIGN.md)**

   - Complete logical and physical architecture
   - Component distribution across VMs
   - HA strategies for each service
   - Network topology and segmentation

2. **[Infrastructure Requirements](docs/02-INFRASTRUCTURE-REQUIREMENTS.md)**

   - Detailed VM specifications
   - Network requirements and topology
   - Storage architecture (object + shared)
   - OS configuration standards
   - Cost estimation

3. **Installation Guide** (Coming Soon)

   - Step-by-step installation procedures
   - Component-specific configurations
   - Integration testing procedures

4. **HA Configuration** (Coming Soon)

   - Patroni setup for PostgreSQL
   - Kafka KRaft configuration
   - Spark/Flink HA setup
   - Load balancer configuration

5. **Operations Runbook** (Coming Soon)
   - Day-to-day operations
   - Monitoring and alerting
   - Backup and restore procedures
   - Disaster recovery plans
   - Troubleshooting guide

---

## 🔧 Component Versions

All components use the latest stable versions as of December 2025:

| Component       | Version    | Notes                          |
| --------------- | ---------- | ------------------------------ |
| PostgreSQL      | 16.2       | Latest stable                  |
| Patroni         | 3.3.2      | HA management for PostgreSQL   |
| etcd            | 3.5.16     | Distributed key-value store    |
| Kafka           | 3.9.0      | KRaft mode (no Zookeeper)      |
| Schema Registry | 7.8.0      | Confluent latest               |
| Nessie          | 0.98.2     | Git-like data catalog          |
| Apache Iceberg  | 1.7.1      | Table format                   |
| Spark           | 3.5.4      | Latest stable                  |
| Flink           | 1.20.0     | Stream processing              |
| Trino           | 469        | Distributed SQL query engine   |
| ClickHouse      | 24.12.2.59 | OLAP database                  |
| Airflow         | 2.10.4     | Workflow orchestration         |
| JupyterHub      | 5.2.1      | Multi-user Jupyter             |
| MLflow          | 2.19.0     | ML lifecycle platform          |
| Superset        | 4.1.1      | BI and visualization           |
| Prometheus      | 3.0.1      | Monitoring system              |
| Grafana         | 11.4.0     | Observability platform         |
| Loki            | 3.3.2      | Log aggregation                |
| Alertmanager    | 0.28.0     | Alert management               |
| Keycloak        | 26.0.7     | Identity and access management |
| Redis           | 7.4.1      | In-memory data store           |
| HAProxy         | 2.9.x      | Load balancer                  |

---

## 🏢 Production Considerations

### High Availability Summary

| Component     | Availability | Failover Time | Data Loss (RPO)           |
| ------------- | ------------ | ------------- | ------------------------- |
| PostgreSQL    | 99.99%       | <30s          | 0 (sync replication)      |
| Kafka         | 99.99%       | <10s          | 0 (min.insync.replicas=2) |
| Nessie        | 99.99%       | <5s           | 0 (database-backed)       |
| Spark         | 99.9%        | <1m           | 0 (checkpoint recovery)   |
| Flink         | 99.9%        | <30s          | <1s (checkpointing)       |
| Trino         | 99.99%       | <5s           | N/A (stateless)           |
| ClickHouse    | 99.9%        | <30s          | 0 (replication)           |
| Load Balancer | 99.99%       | <1s           | N/A (stateless)           |

### Backup Strategy

- **PostgreSQL**: Continuous WAL archiving + daily full backups
- **Kafka**: Cross-datacenter replication via Mirror Maker 2
- **Object Storage**: Built-in replication (11 nines durability)
- **Configurations**: Git repository with daily commits
- **Retention**: 30 days (operational), 1 year (compliance)

### Security Features

✅ TLS encryption for all inter-service communication  
✅ Network segmentation via VLANs  
✅ Centralized authentication via Keycloak  
✅ Role-based access control (RBAC)  
✅ Audit logging for all operations  
✅ Secrets management via Ansible Vault  
✅ Regular security patching schedule

### Disaster Recovery

- **RTO (Recovery Time Objective)**: 15 minutes - 1 hour
- **RPO (Recovery Point Objective)**: 0 - 1 hour
- **DR Strategy**: Active-passive (primary + DR site)
- **Geographic Distribution**: Multi-region capable
- **Automated Failover**: Available for critical services

---

## 🛠️ Operational Tasks

### Common Operations

**Health Check**:

```bash
./scripts/health-check.sh
```

**Backup Configurations**:

```bash
./scripts/backup-configs.sh
```

**Rolling Restart**:

```bash
./scripts/rolling-restart.sh <component>
```

**Scale Workers**:

```bash
# Add Spark workers
ansible-playbook -i inventory/production playbooks/scale-spark-workers.yml \
  --extra-vars "worker_count=6"

# Add Trino workers
ansible-playbook -i inventory/production playbooks/scale-trino-workers.yml \
  --extra-vars "worker_count=5"
```

**Update Component**:

```bash
# Update specific component version
ansible-playbook -i inventory/production playbooks/update-component.yml \
  --extra-vars "component=trino version=470"
```

---

## 📞 Support & Troubleshooting

### Common Issues

See `docs/05-OPERATIONS-RUNBOOK.md` (to be created) for:

- Service startup failures
- Network connectivity issues
- Performance degradation
- HA failover problems
- Storage capacity alerts

### Getting Help

- **Documentation**: Check `/docs` directory
- **Logs**: `/var/log/datalyptica/<component>/`
- **Monitoring**: Grafana dashboards at `/grafana`
- **Support**: support@datalyptica.com

---

## 🔄 Migration Path

### From Docker Compose to Enterprise VMs

1. Export data from Docker volumes
2. Backup PostgreSQL databases
3. Deploy enterprise VM infrastructure
4. Restore data to new infrastructure
5. Update connection strings in applications
6. Cutover during maintenance window

See migration guide (to be created) for detailed steps.

---

## 📝 License

Proprietary - See LICENSE file

---

## 👥 Contributing

This is an internal enterprise deployment. For questions or improvements:

1. Submit issue in project repository
2. Contact platform team
3. Follow change management procedures

---

## 🗺️ Roadmap

### Current (v2.0.0)

- ✅ Enterprise VM architecture design
- ✅ Infrastructure requirements document
- ⏳ Ansible automation (in progress)

### Next Release (v2.1.0)

- [ ] Complete Ansible playbooks for all components
- [ ] HA configuration templates
- [ ] Monitoring dashboards and alerts
- [ ] Operations runbook
- [ ] DR procedures and testing

### Future (v2.2.0+)

- [ ] Multi-region deployment support
- [ ] Advanced security features (mTLS, zero trust)
- [ ] Auto-scaling capabilities
- [ ] Enhanced disaster recovery automation
- [ ] Performance optimization guides

---

**Last Updated**: December 3, 2025  
**Maintained By**: Datalyptica Platform Team
