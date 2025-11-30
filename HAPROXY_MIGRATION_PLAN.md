# HAProxy Migration Plan for PostgreSQL HA

**Date**: November 30, 2025  
**Issue**: Application-side failover not handled automatically  
**Solution**: Replace PgBouncer with HAProxy for intelligent primary detection  

---

## 🎯 Problem Statement

### Current Issues

1. **Hardcoded Connections**: Services connect to specific nodes (patroni-1, patroni-2)
   - Keycloak → `postgresql-patroni-2:5432`
   - Nessie → `postgresql:5432` (doesn't exist!)
   - Kafka Connect → `pgbouncer:6432`

2. **No Automatic Failover**: After Patroni failover, applications still connect to old primary
   - Manual intervention required
   - Downtime until DNS/configs updated

3. **PgBouncer Limitations**: Connection pooler, NOT a load balancer
   - No health checks
   - No primary detection
   - No automatic rerouting

### Services Using PostgreSQL

| Service | Current Connection | Status |
|---------|-------------------|--------|
| Nessie | `postgresql:5432` | ❌ BROKEN (service removed) |
| Keycloak | `postgresql-patroni-2:5432` | ⚠️ HARDCODED (no failover) |
| Kafka Connect | `pgbouncer:6432` | ⚠️ NO FAILOVER |

---

## 🏗️ Proposed Architecture: HAProxy + Patroni

### Why HAProxy?

✅ **Active Health Checks**: Queries Patroni REST API to find current primary  
✅ **Automatic Failover**: Routes to new primary within seconds  
✅ **Connection Pooling**: Can still provide pooling (with `maxconn`)  
✅ **Read/Write Splitting**: Separate ports for primary (write) and replicas (read)  
✅ **Industry Standard**: Used by major PostgreSQL HA setups  

### Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                  Applications                        │
│  (Nessie, Keycloak, Kafka Connect, etc.)           │
└──────────────┬──────────────────────────────────────┘
               │
               │ Single endpoint
               │
         ┌─────▼─────┐
         │  HAProxy  │  Port 5000 (write) / 5001 (read)
         │           │  - Health checks Patroni API
         │           │  - Routes to current primary
         │           │  - Distributes reads to replicas
         └─────┬─────┘
               │
       ┌───────┴───────┐
       │               │
  ┌────▼────┐    ┌────▼────┐
  │Patroni-1│    │Patroni-2│
  │ (Primary)│    │(Replica)│
  │:5432    │    │:5432    │
  │REST:8008│    │REST:8009│
  └────┬────┘    └────┬────┘
       │               │
       └───────┬───────┘
               │
       ┌───────▼───────┐
       │  etcd Cluster │
       │  (3 nodes)    │
       └───────────────┘
```

### Connection Endpoints

| Endpoint | Port | Purpose | Routing |
|----------|------|---------|---------|
| `haproxy:5000` | 5000 | **Write operations** | Always routes to PRIMARY |
| `haproxy:5001` | 5001 | **Read operations** | Round-robin across ALL nodes |
| `haproxy:8404` | 8404 | **Stats dashboard** | HAProxy monitoring |

---

## 📋 Migration Options

### Option A: Fresh Start (Recommended) ⭐

**Pros**:
- Clean slate
- No migration issues
- Faster (5 minutes)

**Cons**:
- Lose existing data (if any)
- Need to reconfigure services

**Steps**:
1. Stop all services
2. Drop all databases on Patroni-2 (current primary)
3. Replace PgBouncer with HAProxy
4. Update all service configs to use `haproxy:5000`
5. Start services (auto-create databases)

**Data Impact**: 
- Nessie: Empty catalog (no tables, no commits) → **OK for development**
- Keycloak: No users, no realms → **Need to recreate**
- Kafka Connect: No connectors → **Need to reconfigure CDC**

### Option B: Migrate Data

**Pros**:
- Keep existing data
- No reconfiguration

**Cons**:
- Complex (30-60 minutes)
- Potential issues
- We don't have much data anyway

**Steps**:
1. Backup databases from old `postgresql` container (if still exists)
2. Stop services
3. Replace PgBouncer with HAProxy
4. Restore databases to Patroni cluster
5. Update configs
6. Start services

---

## 🚀 Recommended: Option A (Fresh Start)

### Why Fresh Start?

1. **Development Phase**: No production data to lose
2. **Clean Architecture**: Avoid migration issues
3. **Speed**: 5 minutes vs 60 minutes
4. **Simplicity**: Less chance of errors

### What We Lose (and why it's OK)

| Service | Data Lost | Impact | Mitigation |
|---------|-----------|--------|------------|
| **Nessie** | Catalog metadata | Empty catalog | Script to recreate sample tables |
| **Keycloak** | Users, realms | No users | Run `configure-keycloak.sh` |
| **Kafka Connect** | Connectors | No CDC | Reconfigure CDC (already have script) |
| **Grafana** | Dashboards | Default dashboards | Import from configs |

---

## 📝 Implementation Plan

### Phase 1: Deploy HAProxy (15 minutes)

1. **Create HAProxy Configuration**
   ```haproxy
   global
       maxconn 1000
   
   defaults
       mode tcp
       timeout connect 10s
       timeout client 1h
       timeout server 1h
   
   frontend postgres_write
       bind *:5000
       default_backend postgres_primary
   
   frontend postgres_read
       bind *:5001
       default_backend postgres_replicas
   
   backend postgres_primary
       option httpchk
       http-check expect status 200
       default-server inter 3s fall 3 rise 2
       server patroni1 postgresql-patroni-1:5432 check port 8008 httpchk GET /leader
       server patroni2 postgresql-patroni-2:5432 check port 8009 httpchk GET /leader
   
   backend postgres_replicas
       option httpchk
       http-check expect status 200
       default-server inter 3s fall 3 rise 2
       server patroni1 postgresql-patroni-1:5432 check port 8008 httpchk GET /health
       server patroni2 postgresql-patroni-2:5432 check port 8009 httpchk GET /health
   
   listen stats
       bind *:8404
       stats enable
       stats uri /
       stats refresh 10s
   ```

2. **Add to docker-compose.yml**
   ```yaml
   haproxy:
     image: haproxy:2.9-alpine
     container_name: ${COMPOSE_PROJECT_NAME}-haproxy
     ports:
       - "5000:5000"  # Write endpoint
       - "5001:5001"  # Read endpoint
       - "8404:8404"  # Stats
     volumes:
       - ../configs/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
     networks:
       - storage_network
       - data_network
     depends_on:
       - postgresql-patroni-1
       - postgresql-patroni-2
     restart: unless-stopped
   ```

3. **Remove PgBouncer** from docker-compose.yml

### Phase 2: Update Service Connections (10 minutes)

**Update these services to use `haproxy:5000`**:

1. **Nessie**:
   ```yaml
   - QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://haproxy:5000/${POSTGRES_DB}
   ```

2. **Keycloak**:
   ```yaml
   - KC_DB_URL=jdbc:postgresql://haproxy:5000/${KEYCLOAK_DB:-keycloak}
   ```

3. **Kafka Connect** (if using PostgreSQL):
   ```yaml
   - DATABASE_URL=jdbc:postgresql://haproxy:5000/postgres
   ```

### Phase 3: Fresh Database Setup (5 minutes)

1. **Drop all databases on primary**:
   ```sql
   DROP DATABASE IF EXISTS nessie;
   DROP DATABASE IF EXISTS keycloak;
   DROP DATABASE IF EXISTS shudl;
   ```

2. **Create fresh databases**:
   ```sql
   CREATE DATABASE nessie OWNER shudl;
   CREATE DATABASE keycloak OWNER keycloak_user;
   CREATE DATABASE shudl OWNER shudl;
   ```

3. **Grant permissions**:
   ```sql
   GRANT ALL PRIVILEGES ON DATABASE nessie TO shudl;
   GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak_user;
   GRANT ALL PRIVILEGES ON DATABASE shudl TO shudl;
   ```

### Phase 4: Start Services (5 minutes)

1. Start HAProxy
2. Verify HAProxy stats at `http://localhost:8404`
3. Start dependent services (Nessie, Keycloak)
4. Verify connections

### Phase 5: Validation (5 minutes)

1. Test write to primary via HAProxy
2. Test read from replicas
3. Test failover (kill primary, verify HAProxy routes to new primary)
4. Run integration tests

---

## 📊 Comparison: PgBouncer vs HAProxy

| Feature | PgBouncer | HAProxy | Winner |
|---------|-----------|---------|--------|
| **Connection Pooling** | ✅ Excellent | ⚠️ Basic | PgBouncer |
| **Primary Detection** | ❌ None | ✅ REST API | HAProxy |
| **Automatic Failover** | ❌ No | ✅ Yes (3-5 sec) | HAProxy |
| **Read/Write Split** | ❌ No | ✅ Yes | HAProxy |
| **Health Checks** | ⚠️ Basic | ✅ Advanced | HAProxy |
| **Load Balancing** | ❌ No | ✅ Yes | HAProxy |
| **Observability** | ⚠️ Basic | ✅ Stats UI | HAProxy |

**Verdict**: HAProxy is the right choice for HA PostgreSQL with Patroni

---

## 🎯 Benefits After Migration

### Reliability
- ✅ Automatic failover (3-5 seconds vs manual intervention)
- ✅ Services never connect to wrong node
- ✅ Zero application changes needed after failover

### Performance
- ✅ Read scaling (distribute across replicas)
- ✅ Write optimization (always route to primary)
- ✅ Connection management (maxconn limits)

### Operations
- ✅ Real-time stats dashboard
- ✅ Health monitoring via HAProxy
- ✅ Easy to add/remove nodes
- ✅ Simplified service configuration

---

## 🔄 Rollback Plan

If migration fails:

1. **Keep old docker-compose.yml backup**:
   ```bash
   cp docker-compose.yml docker-compose.yml.backup
   ```

2. **Restore**:
   ```bash
   docker compose down
   cp docker-compose.yml.backup docker-compose.yml
   docker compose up -d
   ```

3. **Data Recovery** (if needed):
   ```bash
   # Patroni keeps WAL archives
   # Can restore to any point in time
   ```

---

## ✅ Success Criteria

1. ✅ HAProxy deployed and healthy
2. ✅ All services connect via HAProxy
3. ✅ Writes go to primary (verify in HAProxy stats)
4. ✅ Reads distributed across nodes
5. ✅ Failover test passes (<5 second switchover)
6. ✅ No hardcoded node connections remain

---

## 🚀 Next Steps

**Ready to proceed with Option A (Fresh Start)?**

1. **Back up current state** (just in case)
2. **Deploy HAProxy** (15 min)
3. **Update service configs** (10 min)
4. **Fresh database setup** (5 min)
5. **Start and validate** (10 min)

**Total time**: ~40 minutes

**Alternative**: Keep PgBouncer for now, defer to later (but this leaves failover issue unresolved)

---

**Recommendation**: Proceed with HAProxy migration NOW while momentum is strong. This completes the PostgreSQL HA implementation properly.

