# ShuDL Network Segmentation

## Overview

ShuDL implements a **4-tier network architecture** to provide security isolation, performance optimization, and logical separation of concerns across the data lakehouse platform.

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Management Network                          │
│  Prometheus, Grafana, Loki, Alloy, Alertmanager, Kafka UI      │
│  Subnet: 172.20.0.0/16                                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ (cross-network access)
                            │
┌─────────────────────────────────────────────────────────────────┐
│                      Control Network                            │
│  Zookeeper, Kafka, Schema Registry                             │
│  Subnet: 172.21.0.0/16                                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ (streaming data)
                            │
┌─────────────────────────────────────────────────────────────────┐
│                       Data Network                              │
│  Trino, Spark (Master + Worker), Flink, DBT, Kafka            │
│  Subnet: 172.22.0.0/16                                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ (data access)
                            │
┌─────────────────────────────────────────────────────────────────┐
│                     Storage Network                             │
│  PostgreSQL, MinIO, Nessie, ClickHouse                         │
│  Subnet: 172.23.0.0/16                                         │
└─────────────────────────────────────────────────────────────────┘
```

## Network Definitions

### 1. Management Network (172.20.0.0/16)

**Purpose**: Monitoring, observability, and administrative tools

**Services**:

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards
- **Loki**: Log aggregation server
- **Alloy**: Log collector (multi-network for access to all services)
- **Alertmanager**: Alert routing and notifications
- **Kafka UI**: Kafka cluster management interface

**Access Pattern**: Read-only metrics scraping and log collection from all networks

### 2. Control Network (172.21.0.0/16)

**Purpose**: Orchestration, coordination, and streaming infrastructure

**Services**:

- **Zookeeper**: Distributed coordination service
- **Kafka**: Event streaming platform
- **Schema Registry**: Avro/JSON schema management

**Access Pattern**: Kafka brokers serve both control and data networks

### 3. Data Network (172.22.0.0/16)

**Purpose**: Data processing engines and compute workloads

**Services**:

- **Trino**: Distributed SQL query engine
- **Spark Master & Worker**: Big data processing framework
- **Flink JobManager & TaskManager**: Stream processing engine
- **DBT**: SQL transformation orchestration
- **Kafka**: Event streaming (dual network)
- **Kafka Connect**: Data integration connectors

**Access Pattern**: High-bandwidth data transfer, query execution, ETL processing

### 4. Storage Network (172.23.0.0/16)

**Purpose**: Data persistence and catalog services

**Services**:

- **PostgreSQL**: Relational metadata store (Nessie, Trino, system catalogs)
- **MinIO**: S3-compatible object storage
- **Nessie**: Git-like data catalog with versioning
- **ClickHouse**: OLAP database for analytics

**Access Pattern**: Read/write data access from data network, protected from direct external access

## Multi-Network Services

Some services require access to multiple networks to function properly:

### Services on 2 Networks

| Service                              | Networks             | Reason                                                        |
| ------------------------------------ | -------------------- | ------------------------------------------------------------- |
| **MinIO**                            | storage + data       | Object storage accessed by processing engines                 |
| **PostgreSQL**                       | storage + data       | Metadata store accessed by query engines                      |
| **Nessie**                           | storage only         | Catalog service, accessed via data network through PostgreSQL |
| **Trino**                            | data + storage       | Query engine needs direct access to storage                   |
| **Spark Master**                     | data + storage       | Compute engine needs storage access                           |
| **Kafka**                            | control + data       | Streaming platform bridges coordination and processing        |
| **ClickHouse**                       | storage + data       | OLAP database accessed by analytics tools                     |
| **DBT**                              | data + storage       | Transformation tool needs access to both layers               |
| **Kafka UI**                         | management + control | Monitoring tool needs Kafka access                            |
| **Flink (JobManager & TaskManager)** | data + control       | Stream processing needs Kafka and compute                     |

### Services on 3 Networks

| Service           | Networks                 | Reason                                          |
| ----------------- | ------------------------ | ----------------------------------------------- |
| **Spark Worker**  | data + storage + control | Workers need Kafka, storage, and compute access |
| **Kafka Connect** | data + control + storage | Data integration across all layers              |

### Services on 4 Networks (All)

| Service        | Networks     | Reason                            |
| -------------- | ------------ | --------------------------------- |
| **Prometheus** | all networks | Scrapes metrics from all services |
| **Alloy**      | all networks | Collects logs from all containers |

## Security Benefits

### 1. **Lateral Movement Prevention**

- Compromised storage service cannot directly access control plane
- Processing engines isolated from monitoring infrastructure
- Reduced attack surface through network segmentation

### 2. **Traffic Isolation**

- Heavy data transfer workloads stay on data network
- Monitoring traffic separated from production workloads
- Control plane coordination isolated from data processing

### 3. **Least Privilege Network Access**

- Services only join networks they require
- No unnecessary cross-network communication
- Clear network boundaries enforce architectural patterns

### 4. **Audit and Compliance**

- Network-level traffic monitoring and logging
- Easy identification of cross-network communication
- Simplified compliance reporting (e.g., PCI-DSS network segmentation)

## Performance Benefits

### 1. **Reduced Network Contention**

- Separate broadcast domains for each tier
- Isolated ARP traffic within networks
- Better network stack performance per service

### 2. **Optimized Routing**

- Direct container-to-container communication within networks
- Reduced overhead from routing through default bridge
- Better utilization of Docker's networking capabilities

### 3. **Resource Management**

- Clear separation of network resources
- Easier to implement QoS policies per network
- Simplified network troubleshooting

## Implementation Details

### Network Creation

Docker Compose automatically creates networks on first deployment:

```bash
cd /Users/karimhassan/development/projects/shudl/docker
docker compose up -d
```

Networks are created as:

- `docker_management` (172.20.0.0/16)
- `docker_control` (172.21.0.0/16)
- `docker_data` (172.22.0.0/16)
- `docker_storage` (172.23.0.0/16)

### Network Inspection

```bash
# List all ShuDL networks
docker network ls | grep docker_

# Inspect management network
docker network inspect docker_management

# View services on data network
docker network inspect docker_data --format '{{range .Containers}}{{.Name}} {{end}}'
```

### Service Network Assignment

View which networks a service is connected to:

```bash
# Example: Check Prometheus networks
docker inspect docker-prometheus --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'

# Example: Check Kafka networks (should show control_network and data_network)
docker inspect docker-kafka --format '{{json .NetworkSettings.Networks}}' | jq 'keys'
```

## Migration from Single Network

The previous architecture used a single `shunetwork` (${NETWORK_NAME}). The migration to segmented networks provides:

**Before** (Single Network):

- All 20 services on one bridge network
- No isolation between tiers
- Difficult to implement network policies
- Broadcast storm potential with many services

**After** (Segmented Networks):

- 4 isolated networks by function
- Clear security boundaries
- Optimized traffic patterns
- Scalable architecture for future services

## Troubleshooting

### Service Cannot Connect to Another Service

1. **Check network assignments**:

   ```bash
   docker inspect <container> --format '{{json .NetworkSettings.Networks}}' | jq 'keys'
   ```

2. **Verify both services share a common network**:

   - Example: Trino → PostgreSQL requires both on `data_network` and `storage_network`
   - Example: Kafka UI → Kafka requires both on `management_network` and `control_network`

3. **Test network connectivity**:
   ```bash
   docker exec docker-trino ping -c 3 docker-postgresql
   docker exec docker-prometheus wget -O- http://docker-grafana:3000/api/health
   ```

### DNS Resolution Issues

All services use Docker's embedded DNS server. Hostname format:

- Container name: `docker-<service>` (e.g., `docker-nessie`)
- Service name: `<service>` (e.g., `nessie`)

Both formats work within shared networks.

### Network Subnet Conflicts

If subnets conflict with existing infrastructure:

1. Edit `docker-compose.yml` networks section
2. Change subnet ranges (e.g., 172.24.0.0/16, 172.25.0.0/16)
3. Recreate networks:
   ```bash
   docker compose down
   docker network prune
   docker compose up -d
   ```

## Best Practices

### 1. **Add New Services Carefully**

- Determine primary function (management, control, data, storage)
- Assign minimal required networks
- Document multi-network rationale

### 2. **Monitor Cross-Network Traffic**

- Use Prometheus network metrics
- Watch for unexpected cross-network communication
- Investigate services communicating across unauthorized networks

### 3. **Document Service Dependencies**

- Update architecture diagrams when adding services
- Document why services need multiple networks
- Review network assignments during security audits

### 4. **Test Network Isolation**

- Verify services cannot access unauthorized networks
- Test firewall rules if using external firewalls
- Validate DNS resolution within networks

## Future Enhancements

### Phase 3: Advanced Network Security

- **Network Policies**: Implement Calico or similar for fine-grained rules
- **Encrypted Overlay Networks**: Enable Docker Swarm encryption
- **External Firewall Integration**: Connect to corporate firewall systems
- **VPN/VPC Integration**: Extend networks to cloud providers

### Phase 4: Kubernetes Migration

- **Network Policies**: Native Kubernetes NetworkPolicies
- **Service Mesh**: Istio or Linkerd for mTLS and traffic management
- **Multi-Cluster**: Cross-cluster networking with Submariner
- **CNI Plugins**: Advanced networking with Cilium or Calico

---

**Version**: 1.0.0  
**Last Updated**: November 26, 2025  
**Status**: Production Ready ✅
