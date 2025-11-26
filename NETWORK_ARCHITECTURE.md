# ShuDL Network Architecture

## Overview

ShuDL uses a **security-first network segregation design** with 4 isolated Docker bridge networks to provide defense-in-depth architecture.

## Network Topology

```text
┌─────────────────────────────────────────────────────────────────┐
│                    docker_management Network                     │
│                                                                   │
│  Services:                                                        │
│    • Prometheus (metrics scraper - multi-network)                │
│    • Grafana (dashboards)                                        │
│    • Loki (log aggregation)                                      │
│    • Alertmanager (alerting)                                     │
│    • Alloy (telemetry collector)                                 │
│                                                                   │
│  Purpose: Monitoring & Observability Layer                       │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    Prometheus Multi-Network
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                     docker_control Network                       │
│                                                                   │
│  Services:                                                        │
│    • Kafka (event streaming)                                     │
│    • Zookeeper (coordination)                                    │
│    • Schema Registry (Avro schemas)                              │
│    • Kafka Connect (CDC pipelines)                               │
│    • Kafka UI (management interface)                             │
│    • Prometheus (metrics scraper - multi-network)                │
│                                                                   │
│  Purpose: Event Streaming & Messaging Layer                      │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    Prometheus Multi-Network
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      docker_data Network                         │
│                                                                   │
│  Services:                                                        │
│    • Trino (distributed SQL)                                     │
│    • Spark Master/Workers (batch processing)                     │
│    • Flink (stream processing)                                   │
│    • DBT (transformations)                                       │
│    • ClickHouse (real-time OLAP)                                 │
│    • Prometheus (metrics scraper - multi-network)                │
│                                                                   │
│  Purpose: Data Processing & Analytics Layer                      │
└─────────────────────────────────────────────────────────────────┘
                              ↕
                    Prometheus Multi-Network
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                    docker_storage Network                        │
│                                                                   │
│  Services:                                                        │
│    • MinIO (S3-compatible object storage)                        │
│    • PostgreSQL (transactional metadata)                         │
│    • Nessie (data lakehouse catalog)                             │
│    • Keycloak (identity & access management)                     │
│    • Prometheus (metrics scraper - multi-network)                │
│                                                                   │
│  Purpose: Storage & Security Layer                               │
└─────────────────────────────────────────────────────────────────┘
```

## Network Details

### Network Assignments by Layer

| Network               | Driver | Purpose                     | Service Count |
| --------------------- | ------ | --------------------------- | ------------- |
| **docker_management** | bridge | Monitoring & Observability  | 5 services    |
| **docker_control**    | bridge | Event Streaming & Messaging | 6 services    |
| **docker_data**       | bridge | Data Processing & Analytics | 6 services    |
| **docker_storage**    | bridge | Storage & Security          | 5 services    |

### Service Distribution

#### Management Network (5 services)

- `prometheus` - Metrics aggregation and scraping (also on control, data, storage)
- `grafana` - Visualization dashboards
- `loki` - Log aggregation
- `alertmanager` - Alert routing and notifications
- `alloy` - OpenTelemetry collector

#### Control Network (6 services)

- `kafka` - Event streaming platform
- `zookeeper` - Distributed coordination for Kafka
- `schema-registry` - Avro schema management
- `kafka-connect` - CDC and data integration
- `kafka-ui` - Web UI for Kafka management
- `prometheus` - Metrics scraper (multi-network)

#### Data Network (6 services)

- `trino` - Distributed SQL query engine
- `spark-master` - Spark cluster master
- `spark-worker-1/2` - Spark execution workers
- `flink-jobmanager` - Flink job coordination
- `flink-taskmanager` - Flink task execution
- `dbt` - SQL transformations
- `clickhouse` - Real-time OLAP database
- `prometheus` - Metrics scraper (multi-network)

#### Storage Network (5 services)

- `minio` - S3-compatible object storage (data lake)
- `postgresql` - Transactional metadata store
- `nessie` - Git-like data lakehouse catalog
- `keycloak` - IAM and authentication
- `prometheus` - Metrics scraper (multi-network)

## Special Case: Prometheus Multi-Network Design

### Why Prometheus is on All Networks

Prometheus is the **only service** connected to all 4 networks to enable comprehensive metrics collection:

```bash
$ docker inspect docker-prometheus --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'
docker_control docker_data docker_management docker_storage
```

**Rationale**:

1. **Metrics Collection**: Prometheus needs to scrape `/metrics` endpoints from services across all network segments
2. **Security**: Other services remain isolated within their designated networks
3. **Observability**: Centralized monitoring without breaking network boundaries

### Internal vs. External Access

#### Internal Communication (Service-to-Service)

**Status**: ✅ **Working Perfectly**

```bash
$ docker exec docker-grafana wget -q -O- --timeout=5 http://prometheus:9090/-/healthy
Prometheus Server is Healthy.
```

Services communicate seamlessly within their networks using DNS-based service discovery (e.g., `http://prometheus:9090`, `http://kafka:9092`).

#### External Access (Host → Service)

**Status**: ⚠️ **Temporary Delays During WAL Replay**

- **Root Cause**: Multi-network routing + Prometheus WAL (Write-Ahead Log) replay on startup
- **Impact**: Initial external HTTP requests from host may experience 5-10 second delays
- **Duration**: Temporary - resolves after Prometheus completes WAL replay
- **Platform Impact**: **None** - Internal communication unaffected

## Security Benefits

### Defense-in-Depth Architecture

1. **Layer Isolation**: Each functional layer (storage, data, control, management) is network-isolated
2. **Blast Radius Containment**: Security issues in one layer cannot directly affect others
3. **Principle of Least Privilege**: Services only access networks they need
4. **Clear Trust Boundaries**: Network topology mirrors security boundaries

### Attack Surface Reduction

```text
Without Network Segregation:
┌────────────────────────────────────────┐
│  All Services on Single Network        │
│  • Full mesh connectivity              │
│  • Any service can reach any service   │
│  • Large blast radius                  │
└────────────────────────────────────────┘

With Network Segregation:
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Storage  │  │   Data   │  │ Control  │  │ Mgmt     │
│ Network  │  │ Network  │  │ Network  │  │ Network  │
│          │  │          │  │          │  │          │
│ Limited  │  │ Limited  │  │ Limited  │  │ Limited  │
│ Access   │  │ Access   │  │ Access   │  │ Access   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

## Performance Considerations

### Pros

- ✅ **Isolation**: Network-level traffic isolation prevents congestion
- ✅ **Security**: Reduced attack surface
- ✅ **Clarity**: Clear architectural boundaries

### Cons

- ⚠️ **Routing Overhead**: Multi-network services (Prometheus) have slight routing overhead
- ⚠️ **Complex Topology**: More networks to manage

### Optimization Opportunities

1. **Prometheus Configuration**: Adjust scrape intervals to reduce network traffic
2. **Retention Policy**: Reduce Prometheus retention period to speed up WAL replay
3. **Network Bridge**: Use custom bridge networks for better performance vs. default bridge

## Verification Commands

### List All Networks

```bash
docker network ls | grep docker
```

### Inspect Service Network Connectivity

```bash
# Check which networks a service is connected to
docker inspect <container-name> --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'

# Examples:
docker inspect docker-prometheus --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'
docker inspect docker-trino --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'
docker inspect docker-grafana --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'
```

### Test Internal Connectivity

```bash
# Test service-to-service communication within network
docker exec <source-container> wget -q -O- --timeout=5 http://<target-service>:<port>/<endpoint>

# Example: Grafana → Prometheus
docker exec docker-grafana wget -q -O- --timeout=5 http://prometheus:9090/-/healthy
```

### Inspect Network Details

```bash
# View all containers on a network
docker network inspect docker_management | jq '.[0].Containers'
docker network inspect docker_control | jq '.[0].Containers'
docker network inspect docker_data | jq '.[0].Containers'
docker network inspect docker_storage | jq '.[0].Containers'
```

## Design Decisions

### Why 4 Networks?

**Architectural Alignment**: The 4 networks map to the ShuDL lakehouse architecture layers:

```text
ShuDL Architecture Layers → Docker Networks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Management Layer        → docker_management
Control Layer           → docker_control
Processing Layer        → docker_data
Storage Layer           → docker_storage
```

### Why Not More/Fewer Networks?

**Too Few (1-2 networks)**:

- ❌ Reduced security isolation
- ❌ Larger blast radius for security incidents
- ❌ Unclear architectural boundaries

**Too Many (5+ networks)**:

- ❌ Increased complexity
- ❌ More routing overhead
- ❌ Harder to manage and debug

**Just Right (4 networks)**:

- ✅ Clear separation of concerns
- ✅ Security isolation
- ✅ Manageable complexity
- ✅ Aligns with architecture

## Troubleshooting

### Issue: Service Cannot Reach Another Service

**Symptoms**:

- Connection refused
- DNS resolution fails
- Timeout errors

**Diagnosis**:

```bash
# 1. Check if both services are on the same network
docker inspect <service1> --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'
docker inspect <service2> --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'

# 2. Test DNS resolution
docker exec <service1> nslookup <service2>

# 3. Test network connectivity
docker exec <service1> ping -c 3 <service2>
```

**Solution**:

- Ensure both services are on the same network or one has multi-network connectivity

### Issue: Slow External Access to Monitoring Services

**Symptoms**:

- Prometheus web UI slow to respond from host
- Grafana dashboards slow to load
- Curl timeouts from host machine

**Diagnosis**:

```bash
# 1. Check if internal communication works
docker exec docker-grafana wget -q -O- --timeout=5 http://prometheus:9090/-/healthy

# 2. Check Prometheus logs for WAL replay
docker logs docker-prometheus | grep -i "wal\|replay\|compaction"

# 3. Check Prometheus startup time
docker inspect docker-prometheus | jq '.[0].State.StartedAt'
```

**Solution**:

- ✅ **Normal behavior** during Prometheus WAL replay
- ⏳ Wait for WAL replay to complete (typically 1-2 minutes)
- 🔧 Reduce Prometheus retention period to speed up future startups

### Issue: New Service Cannot Access Existing Services

**Symptoms**:

- New service cannot reach services on other networks
- Network isolation too strict

**Solution**:

```bash
# Add service to additional networks in docker-compose.yml
services:
  new-service:
    networks:
      - management  # If needs monitoring
      - data        # If processes data
      # Add only necessary networks
```

## Best Practices

### Adding New Services

1. **Determine Functional Layer**: Which layer does the service belong to?

   - Storage & Security → `docker_storage`
   - Data Processing → `docker_data`
   - Event Streaming → `docker_control`
   - Monitoring → `docker_management`

2. **Assign Network**: Add service to appropriate network in `docker-compose.yml`

3. **Verify Connectivity**: Test that service can reach required dependencies

4. **Document**: Update this file with new service placement

### Security Hardening

1. **Principle of Least Privilege**: Only add services to networks they need
2. **Avoid Multi-Network**: Unless service needs cross-layer communication (like Prometheus)
3. **Use Custom Bridges**: Define explicit bridge networks vs. default
4. **Network Policies**: Consider Kubernetes NetworkPolicies for production

### Performance Tuning

1. **Monitor Network Traffic**: Use `docker stats` to monitor network I/O
2. **Optimize Prometheus**: Adjust scrape intervals and retention
3. **Use Service Mesh**: For advanced traffic management (Istio, Linkerd)

## Production Considerations

### Kubernetes Migration

When migrating to Kubernetes, this Docker network architecture maps to:

```yaml
# NetworkPolicy example for Kubernetes
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: storage-layer-policy
spec:
  podSelector:
    matchLabels:
      layer: storage
  ingress:
    - from:
        - podSelector:
            matchLabels:
              layer: data # Allow data layer to access storage
```

### High Availability

For HA deployments:

- Use overlay networks for multi-host Docker Swarm
- Implement service mesh for advanced routing
- Configure network redundancy

### Monitoring

Add network-level monitoring:

```bash
# Monitor network traffic
docker stats --format "table {{.Container}}\t{{.NetIO}}"

# Monitor network health
docker network inspect docker_management | jq '.[0].Containers | length'
```

## References

- Docker Networking: <https://docs.docker.com/network/>
- Docker Bridge Networks: <https://docs.docker.com/network/bridge/>
- Network Isolation Best Practices: <https://docs.docker.com/network/network-tutorial-standalone/>
- ShuDL Architecture: See `docs/reference/architecture.md`

---

**Document Version**: 1.0  
**Last Updated**: November 26, 2024  
**Maintained By**: ShuDL Team
