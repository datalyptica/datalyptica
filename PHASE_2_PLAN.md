# Phase 2: Security & High Availability - Implementation Plan

**Start Date:** November 30, 2025  
**Target Duration:** 4-6 weeks  
**Goal:** Production-ready security and high availability

---

## 🎯 Phase 2 Objectives

Transform the ShuDL platform from development-ready (52%) to production-ready (75%) by implementing:

1. ✅ SSL/TLS encryption for all services
2. ✅ Docker Secrets for sensitive data
3. ✅ High Availability configurations
4. ✅ Authentication & Authorization
5. ✅ Security hardening

---

## 📋 Implementation Roadmap

### **Week 1: SSL/TLS & Secrets** (Tasks 1-2)

**Task 1: SSL/TLS Certificate Infrastructure**
- Generate CA (Certificate Authority)
- Create service certificates
- Configure certificate rotation
- Update service configurations

**Task 2: Docker Secrets Migration**
- Migrate environment variables to secrets
- Update docker-compose.yml
- Test secret rotation
- Update documentation

### **Week 2-3: High Availability** (Tasks 3-5)

**Task 3: PostgreSQL HA with Patroni**
- Deploy 3-node Patroni cluster
- Configure automatic failover
- Setup replication
- Test failover scenarios

**Task 4: Kafka Multi-Broker Cluster**
- Deploy 3-broker Kafka cluster
- Configure replication factor
- Setup ISR (In-Sync Replicas)
- Test broker failure

**Task 5: Critical Service Replication**
- MinIO multi-node deployment
- Nessie HA configuration
- Load balancer setup
- Health check validation

### **Week 4: Authentication & Authorization** (Tasks 6-7)

**Task 6: Keycloak Configuration**
- Create ShuDL realm
- Define roles and permissions
- Configure identity providers
- Setup SSO

**Task 7: Service Authentication**
- Enable auth for all services
- Configure OAuth2/OIDC
- Setup API tokens
- Test access controls

### **Week 5-6: Hardening & Validation** (Tasks 8-10)

**Task 8: Security Hardening**
- Network policies
- Firewall rules
- Resource limits
- Security scanning

**Task 9: Monitoring & Alerts**
- Security metrics
- HA health checks
- Failover alerts
- Performance monitoring

**Task 10: Comprehensive Testing**
- Security testing
- HA failover testing
- Load testing
- Documentation

---

## 📊 Phase 2 Tasks Overview

| # | Task | Priority | Duration | Dependencies | Status |
|---|------|----------|----------|--------------|--------|
| 1 | SSL/TLS Certificates | P0 | 3 days | None | ⏳ Ready |
| 2 | Docker Secrets | P0 | 2 days | Task 1 | ⏳ Pending |
| 3 | PostgreSQL HA | P1 | 5 days | Task 2 | ⏳ Pending |
| 4 | Kafka HA | P1 | 4 days | Task 2 | ⏳ Pending |
| 5 | Service Replication | P1 | 4 days | Task 3,4 | ⏳ Pending |
| 6 | Keycloak Setup | P1 | 3 days | Task 1 | ⏳ Pending |
| 7 | Service Auth | P1 | 5 days | Task 6 | ⏳ Pending |
| 8 | Security Hardening | P2 | 3 days | Task 7 | ⏳ Pending |
| 9 | Monitoring | P2 | 3 days | Task 8 | ⏳ Pending |
| 10 | Testing | P2 | 5 days | All | ⏳ Pending |

**Total Estimated Duration:** 37 days (~5-6 weeks)

---

## 🔧 Task 1: SSL/TLS Certificate Infrastructure

### **Objectives**
- Generate CA and service certificates
- Configure all services for HTTPS
- Enable mTLS where appropriate
- Setup certificate rotation

### **Services to Secure**

**High Priority (Internet-facing):**
1. Grafana (port 3000 → 3443)
2. MinIO (port 9001 → 9443)
3. Kafka UI (port 8090 → 8443)
4. Trino (port 8080 → 8443)
5. Keycloak (port 8180 → 8443)

**Medium Priority (Internal):**
6. Nessie (port 19120 → 19443)
7. Prometheus (port 9090 → 9443)
8. Schema Registry (port 8085 → 8443)
9. Kafka Connect (port 8083 → 8443)
10. ClickHouse (port 8123 → 8443)

**Low Priority (Background services):**
11. Kafka (TLS listener on 9093)
12. PostgreSQL (SSL mode)
13. Flink JobManager
14. Spark Master

### **Implementation Steps**

1. **Generate CA Certificate**
```bash
# Create CA private key
openssl genrsa -out ca-key.pem 4096

# Create CA certificate
openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem
```

2. **Generate Service Certificates**
```bash
# For each service
openssl genrsa -out service-key.pem 2048
openssl req -new -key service-key.pem -out service-csr.pem
openssl x509 -req -in service-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -out service-cert.pem
```

3. **Update Docker Compose**
- Add volume mounts for certificates
- Update service configurations
- Enable HTTPS ports
- Configure TLS settings

4. **Update Client Connections**
- Update connection strings
- Add CA certificate to trust store
- Test all connections

### **Deliverables**
- [ ] CA certificate generated
- [ ] Service certificates for all 20 services
- [ ] Updated docker-compose.yml with TLS configs
- [ ] Certificate rotation script
- [ ] SSL_TLS_SETUP.md documentation
- [ ] All services accessible via HTTPS

---

## 🔐 Task 2: Docker Secrets Migration

### **Objectives**
- Move all passwords from .env to Docker secrets
- Enable secure secret management
- Setup secret rotation procedures
- Update all service configurations

### **Secrets to Migrate**

**Database Passwords (8):**
1. POSTGRES_PASSWORD
2. NESSIE_PASSWORD
3. CLICKHOUSE_PASSWORD
4. KEYCLOAK_DB_PASSWORD
5. GRAFANA_ADMIN_PASSWORD

**Storage Access Keys (4):**
6. MINIO_ROOT_PASSWORD
7. AWS_SECRET_ACCESS_KEY

**Kafka Security (4):**
8. KAFKA_SASL_PASSWORD
9. SCHEMA_REGISTRY_PASSWORD
10. KAFKA_CONNECT_PASSWORD

**Monitoring & Auth (4):**
11. PROMETHEUS_PASSWORD
12. GRAFANA_PASSWORD
13. KEYCLOAK_ADMIN_PASSWORD
14. JWT_SECRET

### **Implementation Steps**

1. **Create Secrets Files**
```bash
echo "secure_password_here" | docker secret create postgres_password -
echo "secure_password_here" | docker secret create minio_root_password -
# ... for all secrets
```

2. **Update Docker Compose**
```yaml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
  minio_root_password:
    file: ./secrets/minio_root_password.txt

services:
  postgresql:
    secrets:
      - postgres_password
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
```

3. **Update Service Configurations**
- Modify entrypoint scripts to read from secrets
- Update application configs
- Test all connections

4. **Secret Rotation Script**
```bash
#!/bin/bash
# rotate-secrets.sh
# Automate secret rotation
```

### **Deliverables**
- [ ] All passwords migrated to secrets
- [ ] Updated docker-compose.yml with secrets
- [ ] Secret rotation script
- [ ] SECRETS_MANAGEMENT.md documentation
- [ ] All services working with secrets

---

## 🏗️ Task 3: PostgreSQL HA with Patroni

### **Objectives**
- Deploy 3-node PostgreSQL cluster
- Configure automatic failover
- Setup streaming replication
- Implement connection pooling

### **Architecture**

```
                  ┌─────────────┐
                  │   HAProxy   │
                  │  (Postgres) │
                  └──────┬──────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │Patroni 1│     │Patroni 2│     │Patroni 3│
    │(Primary)│────▶│(Replica)│     │(Replica)│
    └─────────┘     └─────────┘     └─────────┘
         │               │               │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │ etcd 1  │     │ etcd 2  │     │ etcd 3  │
    └─────────┘     └─────────┘     └─────────┘
```

### **Implementation Steps**

1. **Deploy etcd Cluster**
```yaml
etcd1:
  image: quay.io/coreos/etcd:v3.5
  environment:
    - ETCD_NAME=etcd1
    - ETCD_INITIAL_CLUSTER=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
```

2. **Deploy Patroni Cluster**
```yaml
patroni1:
  image: patroni:latest
  environment:
    - PATRONI_NAME=patroni1
    - PATRONI_POSTGRESQL_DATA_DIR=/data/patroni
    - PATRONI_ETCD_HOSTS=etcd1:2379,etcd2:2379,etcd3:2379
```

3. **Configure HAProxy**
```yaml
haproxy:
  image: haproxy:2.8
  volumes:
    - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg
  ports:
    - "5432:5432"  # PostgreSQL
    - "7000:7000"  # HAProxy stats
```

4. **Test Failover**
- Stop primary node
- Verify automatic failover
- Check data consistency
- Restore stopped node

### **Deliverables**
- [ ] 3-node Patroni cluster deployed
- [ ] HAProxy load balancer configured
- [ ] Automatic failover working
- [ ] Replication lag < 1 second
- [ ] POSTGRESQL_HA.md documentation
- [ ] Failover test results

---

## ☁️ Task 4: Kafka Multi-Broker Cluster

### **Objectives**
- Deploy 3-broker Kafka cluster
- Configure replication factor 3
- Setup ISR (In-Sync Replicas)
- Implement partition rebalancing

### **Architecture**

```
┌────────────────────────────────────────┐
│         Kafka Cluster (KRaft)          │
├────────────┬────────────┬──────────────┤
│  Broker 1  │  Broker 2  │   Broker 3   │
│   (9092)   │   (9092)   │    (9092)    │
│Controller 1│Controller 2│ Controller 3 │
└────────────┴────────────┴──────────────┘
```

### **Implementation Steps**

1. **Update Docker Compose**
```yaml
kafka1:
  image: apache/kafka:3.6
  environment:
    - KAFKA_NODE_ID=1
    - KAFKA_PROCESS_ROLES=broker,controller
    - KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka1:9094,2@kafka2:9094,3@kafka3:9094
  
kafka2:
  image: apache/kafka:3.6
  environment:
    - KAFKA_NODE_ID=2
    # ... similar config

kafka3:
  image: apache/kafka:3.6
  environment:
    - KAFKA_NODE_ID=3
    # ... similar config
```

2. **Configure Replication**
```bash
# Set default replication factor
kafka-configs --alter --entity-type topics \
  --add-config min.insync.replicas=2,default.replication.factor=3
```

3. **Update Clients**
- Update bootstrap servers to all 3 brokers
- Configure producer acks=all
- Set consumer group rebalancing

4. **Test Broker Failure**
- Stop one broker
- Verify continued operation
- Check partition reassignment
- Restore broker

### **Deliverables**
- [ ] 3-broker Kafka cluster deployed
- [ ] Replication factor 3 configured
- [ ] All CDC topics replicated
- [ ] Broker failure tested
- [ ] KAFKA_HA.md documentation

---

## 🔐 Task 6: Keycloak Configuration

### **Objectives**
- Create ShuDL realm
- Define roles and permissions
- Configure OAuth2/OIDC
- Setup SSO

### **Roles & Permissions**

**User Roles:**
1. **Admin** - Full platform access
2. **Data Engineer** - Pipeline management, SQL access
3. **Data Analyst** - Read-only SQL access
4. **Developer** - API access, limited admin
5. **Viewer** - Dashboard and report access only

**Service Accounts:**
1. Trino service account
2. Spark service account
3. Kafka Connect service account
4. Grafana service account

### **Implementation Steps**

1. **Create ShuDL Realm**
2. **Define Roles and Groups**
3. **Configure Clients** (Grafana, Trino, etc.)
4. **Setup Identity Providers** (LDAP, SAML, etc.)
5. **Test SSO Flow**

### **Deliverables**
- [ ] ShuDL realm configured
- [ ] All roles and permissions defined
- [ ] OAuth2 clients for each service
- [ ] SSO working
- [ ] AUTHENTICATION.md documentation

---

## 📈 Success Criteria

### **Security**
- [ ] All services accessible via HTTPS
- [ ] All passwords stored as Docker secrets
- [ ] mTLS enabled for service-to-service communication
- [ ] Authentication required for all services
- [ ] Role-based access control working

### **High Availability**
- [ ] PostgreSQL survives node failure
- [ ] Kafka survives broker failure
- [ ] Zero data loss during failover
- [ ] Automatic recovery working
- [ ] Load balancing operational

### **Testing**
- [ ] Security scan passed (no critical vulnerabilities)
- [ ] Failover tests passed (all HA services)
- [ ] Load test passed (1000+ concurrent users)
- [ ] Backup/restore tested
- [ ] All documentation updated

### **Production Readiness**
- [ ] Production readiness: 52% → 75%
- [ ] Security score: 6.0 → 8.5
- [ ] Operations score: 6.5 → 8.5
- [ ] All Phase 2 tasks complete

---

## 📊 Progress Tracking

**Overall Progress:** 0% (0/10 tasks complete)

**Week 1:** 0% (Tasks 1-2)  
**Week 2-3:** 0% (Tasks 3-5)  
**Week 4:** 0% (Tasks 6-7)  
**Week 5-6:** 0% (Tasks 8-10)

---

## 🚀 Getting Started

**First Task:** SSL/TLS Certificate Infrastructure

**Command to begin:**
```bash
cd /Users/karimhassan/development/projects/shudl
./scripts/generate-certificates.sh --all
```

**Next steps:**
1. Generate CA and service certificates
2. Update docker-compose.yml
3. Test HTTPS access
4. Update documentation

---

**Phase 2 Start Date:** November 30, 2025  
**Target Completion:** January 10, 2026  
**Current Status:** ⏳ READY TO START

