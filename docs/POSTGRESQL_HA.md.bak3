# PostgreSQL High Availability with Patroni

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [Deployment](#deployment)
- [Operations](#operations)
- [Failover & Switchover](#failover--switchover)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Performance Tuning](#performance-tuning)
- [Backup & Recovery](#backup--recovery)

---

## Overview

The Datalyptica platform implements **PostgreSQL High Availability (HA)** using:

- **Patroni**: Automated failover and cluster management
- **etcd**: Distributed consensus and leader election
- **PgBouncer**: Connection pooling and load balancing
- **Streaming Replication**: Real-time data synchronization

### Key Features

✅ **Automatic Failover**: Patroni detects failures and promotes replicas  
✅ **Zero-Downtime Maintenance**: Rolling upgrades and restarts  
✅ **Split-Brain Protection**: etcd quorum prevents conflicts  
✅ **Connection Pooling**: PgBouncer manages 1000+ connections  
✅ **Resource Efficient**: 2 PostgreSQL nodes + 1 etcd arbiter  
✅ **SSL/TLS Encrypted**: All communication secured  

---

## Architecture

### Topology

```
┌─────────────────────────────────────────────────────────┐
│                     APPLICATIONS                         │
│         (Nessie, Keycloak, Analytics Tools)             │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                  PGBOUNCER                               │
│            (Connection Pooling)                          │
│         Port 6432 - Transaction Mode                    │
│         Max: 1000 connections, Pool: 25                 │
└─────────┬───────────────┬───────────────────────────────┘
          │               │
    ┌─────▼─────────┐  ┌──▼────────────┐
    │    NODE 1     │  │    NODE 2     │     ┌─────────────┐
    │ ┌───────────┐ │  │ ┌───────────┐ │     │   NODE 3    │
    │ │  PATRONI  │ │  │ │  PATRONI  │ │     │             │
    │ │PostgreSQL │◄┼──┼►│PostgreSQL │ │     │             │
    │ │ PRIMARY   │ │  │ │  REPLICA  │ │     │             │
    │ │ :5432     │ │  │ │  :5433    │ │     │             │
    │ │ API: 8008 │ │  │ │ API: 8009 │ │     │             │
    │ └─────┬─────┘ │  │ └─────┬─────┘ │     │             │
    │       │       │  │       │       │     │             │
    │ ┌─────▼─────┐ │  │ ┌─────▼─────┐ │     │ ┌─────────┐ │
    │ │   etcd-1  │◄┼──┼►│   etcd-2  │◄┼─────┼►│ etcd-3  │ │
    │ │  :2379    │ │  │ │ :23791    │ │     │ │:23792   │ │
    │ │  :2380    │ │  │ │ :23801    │ │     │ │:23802   │ │
    │ └───────────┘ │  │ └───────────┘ │     │ └─────────┘ │
    └───────────────┘  └───────────────┘     └─────────────┘
    
    PRIMARY NODE      REPLICA NODE         ARBITER NODE
    (Full Stack)      (Full Stack)         (etcd only)
    Resources: 4GB    Resources: 4GB       Resources: 512MB
```

### Design Rationale

**Why 2 PostgreSQL + 3 etcd (not 3 PostgreSQL)?**

- **Cost Efficient**: Saves ~30% resources vs 3-node PostgreSQL
- **HA Maintained**: etcd quorum (2 of 3) sufficient for consensus
- **Performance**: Read scaling across 2 nodes adequate for workload
- **Scalability**: Can add more replicas or convert arbiter to full node

**Why Co-located etcd?**

- **Low Latency**: etcd on same host as PostgreSQL reduces network hops
- **Simplicity**: Fewer separate hosts to manage
- **Reliability**: etcd failures correlated with PostgreSQL node failures

---

## Components

### 1. etcd Cluster (3 Nodes)

**Purpose**: Distributed key-value store for Patroni coordination

| Node   | Host Port (Client) | Host Port (Peer) | Container Port | Role               |
|--------|-------------------|------------------|----------------|--------------------|
| etcd-1 | 2379              | 2380             | 2379/2380      | Leader/Follower    |
| etcd-2 | 23791             | 23801            | 2379/2380      | Leader/Follower    |
| etcd-3 | 23792             | 23802            | 2379/2380      | Arbiter (quorum)   |

**Key Configuration**:
- Cluster Token: `etcd-cluster-datalyptica`
- Data Directory: `/etcd-data` (persisted volume)
- Auto Compaction: Enabled (1 hour retention)
- Health Checks: 30s interval

**Health Check**:
```bash
# Check etcd cluster health
docker exec -it docker-etcd-1 etcdctl endpoint health
docker exec -it docker-etcd-2 etcdctl endpoint health
docker exec -it docker-etcd-3 etcdctl endpoint health

# Check cluster members
docker exec -it docker-etcd-1 etcdctl member list
```

### 2. PostgreSQL with Patroni (2 Nodes)

**Purpose**: High-availability PostgreSQL with automatic failover

| Node                  | PostgreSQL Port | Patroni API | Volume         | Role                    |
|-----------------------|----------------|-------------|----------------|-------------------------|
| postgresql-patroni-1  | 5432           | 8008        | patroni1_data  | Primary (elected)       |
| postgresql-patroni-2  | 5433           | 8009        | patroni2_data  | Replica (auto-follows)  |

**Key Configuration**:
- Scope: `lakehouse` (cluster name)
- Replication: Asynchronous streaming
- WAL Archive: Enabled (`/var/lib/postgresql/archive`)
- pg_rewind: Enabled (for timeline divergence recovery)
- Replication Slots: Enabled (ensures WAL retention)

**Patroni REST API**:
```bash
# Check cluster status
curl http://localhost:8008/patroni
curl http://localhost:8009/patroni

# Check primary/replica role
curl http://localhost:8008/primary   # 200 if primary
curl http://localhost:8009/replica   # 200 if replica

# Health check
curl http://localhost:8008/health
```

**PostgreSQL Users**:
| User           | Purpose                         | Password Secret                  |
|----------------|---------------------------------|----------------------------------|
| `postgres`     | Superuser                       | `postgres_password`              |
| `datalyptica`        | Application user                | `datalyptica_password`                 |
| `replicator`   | Replication user                | `postgres_replication_password`  |
| `rewind_user`  | pg_rewind (for failback)        | Env var `POSTGRESQL_REWIND_PASSWORD` |

**Databases Created**:
- `postgres` (default)
- `datalyptica` (application database)
- `nessie` (Nessie catalog)

### 3. PgBouncer (Connection Pooler)

**Purpose**: Connection pooling to reduce overhead and improve performance

| Parameter               | Value              | Description                          |
|-------------------------|-------------------|--------------------------------------|
| Port                    | 6432              | Pooled connections                   |
| Pool Mode               | `transaction`     | Connection released after transaction|
| Max Client Connections  | 1000              | Total client connections allowed     |
| Default Pool Size       | 25                | Connections per database             |
| Reserve Pool Size       | 5                 | Emergency connections                |
| Max DB Connections      | 100               | Max backend PostgreSQL connections   |
| Server Idle Timeout     | 600s              | Close idle server connections        |

**Health Check**:
```bash
# Check PgBouncer status
docker exec -it docker-pgbouncer pg_isready -h localhost -p 6432

# View PgBouncer stats
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW STATS;"
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"
```

---

## Deployment

### Prerequisites

1. **Docker Secrets Generated**:
   ```bash
   ls -1 secrets/passwords/
   # Should show:
   # postgres_password
   # datalyptica_password
   # postgres_replication_password
   ```

2. **SSL Certificates Generated**:
   ```bash
   bash scripts/generate-certificates.sh
   
   # Verify certificates exist
   ls -1 secrets/certificates/
   # Should include: etcd-1, etcd-2, etcd-3, postgresql
   ```

3. **Environment Variables** (in `docker/.env`):
   ```bash
   POSTGRES_PORT=5432
   POSTGRES_PORT_REPLICA=5433
   PGBOUNCER_PORT=6432
   PATRONI_API_PASSWORD=<secure_password>
   POSTGRESQL_REWIND_PASSWORD=<secure_password>
   ```

### Step-by-Step Deployment

#### 1. Stop Old PostgreSQL (if running)

```bash
cd docker

# Stop existing postgresql service (if any)
docker compose stop postgresql
docker compose rm -f postgresql

# Backup data (IMPORTANT!)
docker run --rm -v docker_postgresql_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/postgresql_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

#### 2. Start etcd Cluster

```bash
# Start etcd cluster (3 nodes)
docker compose up -d etcd-1 etcd-2 etcd-3

# Wait for cluster to form (30-60 seconds)
sleep 60

# Verify cluster health
docker exec -it docker-etcd-1 etcdctl endpoint health --endpoints=http://etcd-1:2379,http://etcd-2:2379,http://etcd-3:2379
```

**Expected Output**:
```
http://etcd-1:2379 is healthy: successfully committed proposal: took = 2.345ms
http://etcd-2:2379 is healthy: successfully committed proposal: took = 3.123ms
http://etcd-3:2379 is healthy: successfully committed proposal: took = 2.876ms
```

#### 3. Initialize Patroni Primary

```bash
# Start first Patroni node (will bootstrap cluster)
docker compose up -d postgresql-patroni-1

# Wait for initialization (60-90 seconds)
sleep 90

# Check if Patroni is running
curl -s http://localhost:8008/patroni | jq .

# Check if primary is elected
curl -s http://localhost:8008/primary
# Should return HTTP 200
```

**Logs to Monitor**:
```bash
docker logs -f docker-postgresql-patroni-1
# Look for:
# - "Starting Patroni..."
# - "Lock owner: postgresql-patroni-1"
# - "initialized a new cluster"
# - "PostgreSQL is running"
```

#### 4. Start Patroni Replica

```bash
# Start second Patroni node (will replicate from primary)
docker compose up -d postgresql-patroni-2

# Wait for replication to start (60-90 seconds)
sleep 90

# Check replica status
curl -s http://localhost:8009/replica
# Should return HTTP 200

# Verify replication lag
docker exec -it docker-postgresql-patroni-1 psql -U postgres -c \
  "SELECT client_addr, state, sync_state, replay_lag FROM pg_stat_replication;"
```

**Expected Replication Status**:
```
     client_addr      | state     | sync_state | replay_lag
----------------------+-----------+------------+------------
 postgresql-patroni-2 | streaming | async      | 00:00:00
```

#### 5. Start PgBouncer

```bash
# Start PgBouncer
docker compose up -d pgbouncer

# Wait for startup (10-20 seconds)
sleep 20

# Test connection through PgBouncer
PGPASSWORD=<postgres_password> psql -h localhost -p 6432 -U postgres -d postgres -c "SELECT version();"
```

#### 6. Update Client Connections

All applications should now connect via **PgBouncer** on port **6432** instead of directly to PostgreSQL.

**Example Connection Strings**:
```bash
# OLD (direct to PostgreSQL)
DATABASE_URL=postgresql://datalyptica:password@localhost:5432/datalyptica

# NEW (via PgBouncer)
DATABASE_URL=postgresql://datalyptica:password@localhost:6432/datalyptica
```

**Update Services**:
```bash
# Update Nessie, Keycloak, and other services in docker-compose.yml
# Change: postgresql:5432 → pgbouncer:6432
# Then restart services
docker compose restart nessie keycloak
```

#### 7. Verify Deployment

```bash
# Run full health check
bash tests/health/test-all-health.sh

# Check all HA components
docker ps --filter "name=etcd" --filter "name=patroni" --filter "name=pgbouncer"

# Check Patroni cluster status
docker exec -it docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml list

# Expected output:
# + Cluster: lakehouse (7XXX) ------+----+-----------+
# | Member                | Host    | Role    | State   | TL | Lag in MB |
# +-----------------------+---------+---------+---------+----+-----------+
# | postgresql-patroni-1  | x.x.x.x | Leader  | running |  1 |           |
# | postgresql-patroni-2  | x.x.x.x | Replica | running |  1 |         0 |
# +-----------------------+---------+---------+---------+----+-----------+
```

---

## Operations

### Checking Cluster Status

```bash
# Patroni cluster status (via CLI)
docker exec -it docker-postgresql-patroni-1 \
  patronictl -c /etc/patroni/patroni.yml list

# Patroni cluster status (via REST API)
curl -s http://localhost:8008/patroni | jq .
curl -s http://localhost:8009/patroni | jq .

# Check replication lag
docker exec -it docker-postgresql-patroni-1 psql -U postgres -c \
  "SELECT application_name, client_addr, state, sync_state, 
          pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
   FROM pg_stat_replication;"

# Check etcd cluster health
docker exec -it docker-etcd-1 etcdctl member list -w table
```

### Viewing Logs

```bash
# Patroni logs
docker logs -f docker-postgresql-patroni-1
docker logs -f docker-postgresql-patroni-2

# etcd logs
docker logs -f docker-etcd-1
docker logs -f docker-etcd-2
docker logs -f docker-etcd-3

# PgBouncer logs
docker logs -f docker-pgbouncer

# PostgreSQL logs (inside Patroni container)
docker exec -it docker-postgresql-patroni-1 tail -f /var/lib/postgresql/data/pgdata/log/postgresql-*.log
```

### Scaling: Adding More Replicas

```bash
# Add postgresql-patroni-3 to docker-compose.yml
# Copy postgresql-patroni-2 configuration and adjust:
# - container_name: docker-postgresql-patroni-3
# - hostname: postgresql-patroni-3
# - ports: "5434:5432", "8010:8008"
# - environment: PATRONI_NAME=postgresql-patroni-3

# Start new replica
docker compose up -d postgresql-patroni-3

# Verify it joins the cluster
docker exec -it docker-postgresql-patroni-1 \
  patronictl -c /etc/patroni/patroni.yml list
```

---

## Failover & Switchover

### Automatic Failover

**Trigger**: Primary node failure detected by Patroni

**Process**:
1. Patroni detects primary failure (via etcd heartbeat)
2. Patroni triggers leader election
3. Most up-to-date replica wins election
4. Winning replica promoted to primary
5. Other replicas update to follow new primary
6. PgBouncer connections rerouted automatically

**Time to Failover**: ~10-30 seconds

**Simulate Failure**:
```bash
# Stop primary (simulate crash)
docker stop docker-postgresql-patroni-1

# Watch failover happen
watch -n 1 'curl -s http://localhost:8009/patroni | jq .role'
# Should change from "replica" to "master"

# Check cluster status
docker exec -it docker-postgresql-patroni-2 \
  patronictl -c /etc/patroni/patroni.yml list

# Restart failed node (becomes replica)
docker start docker-postgresql-patroni-1
```

### Manual Switchover (Planned Maintenance)

**Use Case**: Upgrade, maintenance, or moving primary to different node

**Process**:
```bash
# Perform switchover (promotes postgresql-patroni-2 to primary)
docker exec -it docker-postgresql-patroni-1 \
  patronictl -c /etc/patroni/patroni.yml switchover --leader postgresql-patroni-1 --candidate postgresql-patroni-2 --force

# Verify new leader
docker exec -it docker-postgresql-patroni-2 \
  patronictl -c /etc/patroni/patroni.yml list

# Expected output:
# postgresql-patroni-2  | Leader  | running
# postgresql-patroni-1  | Replica | running
```

**Advantages of Switchover vs Failover**:
- Controlled process (no data loss)
- No downtime (connections seamlessly rerouted)
- Can choose specific replica to promote
- Safe for maintenance windows

### Failback (Returning to Original Primary)

After fixing a failed node, you may want to return it as primary:

```bash
# Switchover back to original primary
docker exec -it docker-postgresql-patroni-2 \
  patronictl -c /etc/patroni/patroni.yml switchover --leader postgresql-patroni-2 --candidate postgresql-patroni-1 --force

# Verify
docker exec -it docker-postgresql-patroni-1 \
  patronictl -c /etc/patroni/patroni.yml list
```

---

## Monitoring

### Key Metrics to Monitor

#### PostgreSQL Metrics

| Metric                        | Command                                                                                     | Healthy Value              |
|-------------------------------|---------------------------------------------------------------------------------------------|----------------------------|
| **Replication Lag (Bytes)**   | `SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;`      | < 1 MB (< 1,048,576 bytes) |
| **Replication Lag (Time)**    | `SELECT extract(epoch from (now() - pg_last_xact_replay_timestamp()));` (on replica)       | < 5 seconds                |
| **Connection Count**          | `SELECT count(*) FROM pg_stat_activity;`                                                   | < 80 (of max 100)          |
| **Active Queries**            | `SELECT count(*) FROM pg_stat_activity WHERE state = 'active';`                            | Varies by workload         |
| **Replication State**         | `SELECT state, sync_state FROM pg_stat_replication;`                                       | `streaming`, `async`       |
| **Database Size**             | `SELECT pg_size_pretty(pg_database_size('datalyptica'));`                                        | Monitor growth             |
| **WAL Files**                 | `SELECT count(*) FROM pg_ls_waldir();`                                                     | < 100 (cleanup working)    |

#### Patroni Metrics

```bash
# Patroni health (via API)
curl -s http://localhost:8008/health
curl -s http://localhost:8009/health

# Patroni leader
curl -s http://localhost:8008/leader  # Returns leader name

# Patroni role
curl -s http://localhost:8008/patroni | jq .role  # "master" or "replica"

# Patroni timeline
curl -s http://localhost:8008/patroni | jq .timeline  # Should match across cluster
```

#### etcd Metrics

```bash
# etcd health
docker exec -it docker-etcd-1 etcdctl endpoint health

# etcd leader
docker exec -it docker-etcd-1 etcdctl endpoint status -w table

# etcd member list
docker exec -it docker-etcd-1 etcdctl member list -w table
```

#### PgBouncer Metrics

```bash
# Connect to PgBouncer admin database
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -d pgbouncer

# View pool statistics
SHOW POOLS;

# View client connections
SHOW CLIENTS;

# View server connections
SHOW SERVERS;

# View statistics
SHOW STATS;
```

### Prometheus Integration

The Datalyptica platform includes **Prometheus** for metrics collection. PostgreSQL metrics are exported via:

- **postgres_exporter** (included in Patroni image)
- Exposed on port `9187` (if enabled)

Add to `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'postgresql-patroni-1'
    static_configs:
      - targets: ['postgresql-patroni-1:9187']
  
  - job_name: 'postgresql-patroni-2'
    static_configs:
      - targets: ['postgresql-patroni-2:9187']
  
  - job_name: 'patroni-1-api'
    static_configs:
      - targets: ['postgresql-patroni-1:8008']
  
  - job_name: 'patroni-2-api'
    static_configs:
      - targets: ['postgresql-patroni-2:8009']
```

### Grafana Dashboards

Recommended dashboards:
- **PostgreSQL Overview** (ID: 9628)
- **Patroni Cluster** (ID: 13054)
- **PgBouncer** (ID: 6879)

---

## Troubleshooting

### Issue 1: Patroni Cannot Connect to etcd

**Symptoms**:
```
Waiting for etcd to be available...
Error: context deadline exceeded
```

**Diagnosis**:
```bash
# Check if etcd containers are running
docker ps --filter "name=etcd"

# Check etcd logs
docker logs docker-etcd-1

# Test etcd connectivity from Patroni container
docker exec -it docker-postgresql-patroni-1 curl http://etcd-1:2379/health
```

**Solutions**:
1. **etcd not started**: `docker compose up -d etcd-1 etcd-2 etcd-3`
2. **Network issue**: Check if containers are on same network (`docker network inspect docker_storage_network`)
3. **etcd cluster unhealthy**: Restart etcd cluster (see below)

### Issue 2: Replication Lag Increasing

**Symptoms**:
```
Replication lag: 100 MB and growing
```

**Diagnosis**:
```bash
# Check replication lag
docker exec -it docker-postgresql-patroni-1 psql -U postgres -c \
  "SELECT application_name, state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes 
   FROM pg_stat_replication;"

# Check replica load
docker stats docker-postgresql-patroni-2
```

**Solutions**:
1. **Replica overloaded**: Scale up resources or add more replicas
2. **Network latency**: Check inter-container network performance
3. **WAL segment size**: Increase `wal_keep_size` in Patroni config
4. **Checkpoint too frequent**: Tune `checkpoint_completion_target`

### Issue 3: Split-Brain (Two Primaries)

**Symptoms**:
```
Multiple nodes claim to be primary
```

**Diagnosis**:
```bash
# Check all nodes' roles
curl -s http://localhost:8008/patroni | jq .role
curl -s http://localhost:8009/patroni | jq .role

# Check etcd cluster health
docker exec -it docker-etcd-1 etcdctl member list
```

**Solutions**:
1. **etcd quorum lost**: Restore etcd cluster (see Issue 5)
2. **Network partition**: Check Docker network connectivity
3. **Manual intervention**: Force one node to reinitialize:
   ```bash
   docker exec -it docker-postgresql-patroni-2 \
     patronictl -c /etc/patroni/patroni.yml reinit lakehouse postgresql-patroni-2
   ```

### Issue 4: Failover Not Happening

**Symptoms**:
```
Primary crashed but replica not promoted
```

**Diagnosis**:
```bash
# Check Patroni logs
docker logs docker-postgresql-patroni-2

# Check etcd connectivity
docker exec -it docker-postgresql-patroni-2 curl http://etcd-1:2379/health

# Check Patroni leader lock in etcd
docker exec -it docker-etcd-1 etcdctl get /db/lakehouse/leader
```

**Solutions**:
1. **Replica lagging too much**: Check `maximum_lag_on_failover` in Patroni config
2. **etcd quorum lost**: Restore etcd cluster
3. **Patroni API not responding**: Restart Patroni services
4. **Manual failover**:
   ```bash
   docker exec -it docker-postgresql-patroni-2 \
     patronictl -c /etc/patroni/patroni.yml failover --candidate postgresql-patroni-2
   ```

### Issue 5: etcd Cluster Corrupted

**Symptoms**:
```
etcd: mvcc: database space exceeded
etcd: failed to check the health of member
```

**Diagnosis**:
```bash
# Check etcd disk usage
docker exec -it docker-etcd-1 etcdctl endpoint status -w table

# Check etcd alarms
docker exec -it docker-etcd-1 etcdctl alarm list
```

**Solutions**:

**Option 1: Compact and Defragment**:
```bash
# Get current revision
REV=$(docker exec -it docker-etcd-1 etcdctl endpoint status -w json | jq -r '.[].Status.header.revision')

# Compact old revisions
docker exec -it docker-etcd-1 etcdctl compact $REV

# Defragment all members
docker exec -it docker-etcd-1 etcdctl defrag
docker exec -it docker-etcd-2 etcdctl defrag
docker exec -it docker-etcd-3 etcdctl defrag

# Disarm alarms
docker exec -it docker-etcd-1 etcdctl alarm disarm
```

**Option 2: Rebuild etcd Cluster (LAST RESORT)**:
```bash
# Stop all services
docker compose down

# Remove etcd data (WARNING: This will reset Patroni state!)
docker volume rm docker_etcd1_data docker_etcd2_data docker_etcd3_data

# Restart etcd cluster
docker compose up -d etcd-1 etcd-2 etcd-3

# Reinitialize Patroni cluster
docker compose up -d postgresql-patroni-1 postgresql-patroni-2
```

### Issue 6: PgBouncer Rejecting Connections

**Symptoms**:
```
FATAL: no more connections allowed (max_client_conn)
```

**Diagnosis**:
```bash
# Check PgBouncer stats
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"

# Check active connections
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW CLIENTS;" | wc -l
```

**Solutions**:
1. **Increase max_client_conn**: Update `MAX_CLIENT_CONN` in docker-compose.yml
2. **Connection leak**: Investigate applications not closing connections
3. **Restart PgBouncer**: `docker restart docker-pgbouncer`

---

## Performance Tuning

### PostgreSQL Configuration

Key parameters to tune (in `patroni.yml`):

```yaml
postgresql:
  parameters:
    # Memory
    shared_buffers: 256MB              # 25% of RAM (for 1GB total)
    effective_cache_size: 512MB        # 50% of RAM
    work_mem: 4MB                      # Per-operation memory
    maintenance_work_mem: 64MB         # Vacuum, index operations
    
    # Connections
    max_connections: 100               # Increase if needed
    
    # WAL & Replication
    wal_level: replica                 # Required for replication
    max_wal_senders: 10                # Max replicas
    max_replication_slots: 10
    wal_keep_segments: 8               # Retain 8 segments (128MB)
    
    # Checkpoints
    checkpoint_completion_target: 0.9  # Spread checkpoints over 90% of interval
    wal_buffers: 16MB                  # WAL write buffer
    min_wal_size: 1GB
    max_wal_size: 4GB
    
    # Performance
    random_page_cost: 1.1              # For SSDs
    effective_io_concurrency: 200      # For SSDs
    
    # Autovacuum
    autovacuum: on
    autovacuum_max_workers: 3
    autovacuum_naptime: 1min
```

### PgBouncer Tuning

```yaml
environment:
  # Adjust based on workload
  - POOL_MODE=transaction            # Options: transaction, session, statement
  - MAX_CLIENT_CONN=1000             # Max client connections
  - DEFAULT_POOL_SIZE=25             # Connections per database
  - RESERVE_POOL_SIZE=5              # Emergency pool
  - MAX_DB_CONNECTIONS=100           # Backend connections
  - SERVER_IDLE_TIMEOUT=600          # Close idle backends (seconds)
  - QUERY_TIMEOUT=0                  # Disable query timeout (or set limit)
  - CLIENT_IDLE_TIMEOUT=0            # Disable client timeout (or set limit)
```

**Pool Mode Selection**:
- **`transaction`** (default): Best for most OLTP workloads, connection released after each transaction
- **`session`**: Connection tied to client session (like direct PostgreSQL)
- **`statement`**: Connection released after each statement (rare use)

### Monitoring Performance

```sql
-- Top 10 slowest queries
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Table bloat
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC
LIMIT 10;  -- Unused indexes
```

---

## Backup & Recovery

### Continuous WAL Archiving

Patroni automatically archives WAL files to `/var/lib/postgresql/archive` inside containers.

**Extract WAL archives**:
```bash
# Copy WAL archives from primary to backup location
docker cp docker-postgresql-patroni-1:/var/lib/postgresql/archive /backup/wal_$(date +%Y%m%d)
```

### Full Backup (pg_basebackup)

```bash
# Create full backup from primary
docker exec -it docker-postgresql-patroni-1 pg_basebackup \
  -U replicator \
  -D /tmp/backup_$(date +%Y%m%d_%H%M%S) \
  -F tar \
  -z \
  -P

# Copy backup out of container
docker cp docker-postgresql-patroni-1:/tmp/backup_YYYYMMDD_HHMMSS.tar.gz /backup/
```

### Logical Backup (pg_dump)

```bash
# Dump specific database
docker exec -it docker-postgresql-patroni-1 pg_dump -U postgres -d datalyptica -F c -f /tmp/datalyptica_backup.dump

# Copy backup out
docker cp docker-postgresql-patroni-1:/tmp/datalyptica_backup.dump /backup/

# Dump all databases
docker exec -it docker-postgresql-patroni-1 pg_dumpall -U postgres -f /tmp/all_databases.sql
docker cp docker-postgresql-patroni-1:/tmp/all_databases.sql /backup/
```

### Point-in-Time Recovery (PITR)

1. **Stop Patroni cluster**:
   ```bash
   docker compose down postgresql-patroni-1 postgresql-patroni-2
   ```

2. **Restore base backup**:
   ```bash
   # Clear old data
   docker volume rm docker_patroni1_data docker_patroni2_data
   
   # Extract backup to volume
   docker run --rm -v docker_patroni1_data:/restore -v /backup:/backup alpine \
     tar xzf /backup/base_backup.tar.gz -C /restore
   ```

3. **Configure recovery**:
   Create `recovery.conf` in data directory:
   ```conf
   restore_command = 'cp /var/lib/postgresql/archive/%f %p'
   recovery_target_time = '2025-12-01 10:00:00'
   recovery_target_action = 'promote'
   ```

4. **Start PostgreSQL**:
   ```bash
   docker compose up -d postgresql-patroni-1
   # Monitor logs for recovery progress
   docker logs -f docker-postgresql-patroni-1
   ```

---

## Summary

### Deployment Checklist

- [ ] SSL certificates generated (`scripts/generate-certificates.sh`)
- [ ] Docker secrets created (`secrets/passwords/`)
- [ ] Environment variables configured (`docker/.env`)
- [ ] etcd cluster started (3 nodes)
- [ ] Patroni primary initialized
- [ ] Patroni replica started and replicating
- [ ] PgBouncer started and tested
- [ ] Client applications updated to use PgBouncer (port 6432)
- [ ] Monitoring configured (Prometheus, Grafana)
- [ ] Backup strategy implemented

### Key Commands Reference

| Task                          | Command                                                                                     |
|-------------------------------|---------------------------------------------------------------------------------------------|
| **Cluster Status**            | `docker exec -it docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml list` |
| **Manual Switchover**         | `patronictl switchover --leader NODE1 --candidate NODE2 --force`                          |
| **Check Replication Lag**     | `SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) FROM pg_stat_replication;`     |
| **etcd Health**               | `docker exec -it docker-etcd-1 etcdctl endpoint health`                                    |
| **PgBouncer Stats**           | `PGPASSWORD=<pw> psql -h localhost -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"`     |
| **Restart Patroni**           | `docker restart docker-postgresql-patroni-1`                                               |
| **View Patroni Logs**         | `docker logs -f docker-postgresql-patroni-1`                                               |

---

## Additional Resources

- **Patroni Documentation**: https://patroni.readthedocs.io/
- **etcd Documentation**: https://etcd.io/docs/
- **PgBouncer Documentation**: https://www.pgbouncer.org/
- **PostgreSQL Replication**: https://www.postgresql.org/docs/current/high-availability.html

---

**Document Version**: 1.0  
**Last Updated**: November 30, 2025  
**Maintained By**: Datalyptica DevOps Team

