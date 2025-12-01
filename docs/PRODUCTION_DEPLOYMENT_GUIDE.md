# Datalyptica Platform - Production Deployment Guide

**Document Version:** 1.0.0  
**Date:** November 30, 2025  
**Classification:** Operations Manual

---

## 1. Executive Summary

This guide provides comprehensive, step-by-step procedures for deploying the Datalyptica platform to production environments. It covers pre-deployment preparation, deployment execution, validation, rollback procedures, and post-deployment operations.

### Deployment Approach

**Philosophy:**

- Automate everything
- Test in lower environments first
- Deploy incrementally
- Monitor continuously
- Be ready to rollback

**Risk Mitigation:**

- Blue-green deployments for zero downtime
- Canary deployments for gradual rollouts
- Automated rollback on failures
- Comprehensive health checks
- Real-time monitoring

---

## 2. Prerequisites

### 2.1 Infrastructure Requirements

#### **Kubernetes Cluster** (Production)

**Minimum Specifications:**

- **Control Plane:** 3 nodes × 4 CPU, 8GB RAM
- **Worker Nodes:** 5 nodes × 16 CPU, 64GB RAM, 500GB SSD
- **Kubernetes Version:** 1.28-1.30
- **CNI:** Calico or Cilium (with NetworkPolicies)
- **CSI:** Dynamic storage provisioner (Rook/Ceph, Longhorn, or cloud provider)
- **Ingress:** Nginx Ingress Controller or Istio

**Network Requirements:**

- 10 Gbps inter-node connectivity
- Load balancer (MetalLB for on-prem, cloud LB for managed K8s)
- DNS records configured
- SSL certificates (Let's Encrypt or internal CA)
- Firewall rules configured

**Storage Requirements:**

- **Block Storage (CSI):** 2TB for stateful workloads (PostgreSQL, Kafka, etc.)
- **Object Storage (S3):** 10TB+ for data lake (MinIO distributed or cloud S3)
- **Backup Storage:** 2× production data size

#### **Tools Installed**

| Tool        | Version     | Purpose                      |
| ----------- | ----------- | ---------------------------- |
| **kubectl** | Matches K8s | Cluster interaction          |
| **helm**    | 3.12+       | Package management           |
| **argocd**  | 2.9+        | GitOps deployment (optional) |
| **docker**  | 24.0+       | Image building               |
| **trivy**   | latest      | Security scanning            |
| **jq**      | 1.6+        | JSON processing              |
| **yq**      | 4.30+       | YAML processing              |

### 2.2 Access & Permissions

**Required Accounts:**

- [ ] Kubernetes cluster admin access
- [ ] Container registry push access (ghcr.io or private registry)
- [ ] DNS management access (for ingress)
- [ ] Certificate management access (for TLS)
- [ ] Secrets management access (for passwords/keys)
- [ ] Monitoring access (Grafana, Alertmanager)
- [ ] Incident management (PagerDuty, Slack, etc.)

**Required Approvals:**

- [ ] Change Advisory Board (CAB) approval
- [ ] Security team sign-off
- [ ] Business stakeholder approval
- [ ] Maintenance window scheduled
- [ ] Communications sent (downtime notifications)

### 2.3 Pre-Deployment Checklist

#### **Code & Configuration**

- [ ] All code merged to `main` branch
- [ ] Version tag created (e.g., `v1.0.0`)
- [ ] CI/CD pipelines passed (100% success)
- [ ] Container images built and scanned (Trivy: 0 critical vulnerabilities)
- [ ] Helm charts updated with new versions
- [ ] Configuration reviewed and approved
- [ ] Secrets generated and stored securely

#### **Testing Completed**

- [ ] Unit tests: 100% pass
- [ ] Integration tests: 100% pass
- [ ] End-to-end tests: 100% pass
- [ ] Performance tests: Within SLA (load testing completed)
- [ ] Security tests: Penetration testing completed
- [ ] Disaster recovery tested: Backup/restore validated
- [ ] Failover tested: HA scenarios validated

#### **Documentation**

- [ ] Deployment runbook reviewed
- [ ] Rollback procedures documented
- [ ] Architecture diagrams updated
- [ ] Configuration changes documented
- [ ] Release notes prepared
- [ ] User communications drafted

#### **Operational Readiness**

- [ ] On-call team identified and briefed
- [ ] Monitoring alerts configured
- [ ] Runbooks updated
- [ ] Backup scheduled (pre-deployment)
- [ ] Rollback plan prepared and tested
- [ ] Communication plan activated

---

## 3. Deployment Architecture

### 3.1 Kubernetes Deployment Model

```
┌─────────────────────────────────────────────────────────────┐
│                     INGRESS LAYER                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Nginx Ingress Controller (or Istio Gateway)           │ │
│  │  - SSL Termination                                     │ │
│  │  - Load Balancing                                      │ │
│  │  - Rate Limiting                                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  APPLICATION LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Grafana    │  │   Keycloak   │  │   Kafka UI   │     │
│  │ (Deployment) │  │ (StatefulSet)│  │ (Deployment) │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │    Trino     │  │    Spark     │  │    Flink     │     │
│  │ (Deployment) │  │ (Deployment) │  │ (Deployment) │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     DATA LAYER                              │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │   Nessie (Catalog)   │  │  Kafka (StatefulSet) │        │
│  │    (Deployment)      │  │  3+ brokers, KRaft   │        │
│  └──────────────────────┘  └──────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   STORAGE LAYER                             │
│  ┌────────────────────────┐  ┌────────────────────────┐    │
│  │  PostgreSQL (Operator) │  │  MinIO (Operator)      │    │
│  │  CloudNativePG         │  │  Distributed Mode      │    │
│  │  3 instances (HA)      │  │  4+ nodes, EC:4+2      │    │
│  └────────────────────────┘  └────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 OBSERVABILITY LAYER                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Prometheus  │  │     Loki    │  │Alertmanager │        │
│  │ (Operator)  │  │ (StatefulSet)│  │(StatefulSet)│        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Namespace Strategy

| Namespace            | Purpose                                            | Resource Quota     |
| -------------------- | -------------------------------------------------- | ------------------ |
| **datalyptica-system**     | Platform operators (CloudNativePG, MinIO, Strimzi) | No limit (system)  |
| **datalyptica-storage**    | Storage layer (PostgreSQL, MinIO, Kafka)           | 128GB RAM, 64 CPU  |
| **datalyptica-data**       | Data layer (Nessie, Trino, Spark, Flink)           | 256GB RAM, 128 CPU |
| **datalyptica-control**    | Control plane (Kafka, Schema Registry, Connect)    | 64GB RAM, 32 CPU   |
| **datalyptica-management** | Management (Keycloak, Grafana, monitoring)         | 32GB RAM, 16 CPU   |
| **datalyptica-ingress**    | Ingress controllers                                | 8GB RAM, 4 CPU     |

---

## 4. Step-by-Step Deployment

### 4.1 Phase 1: Pre-Deployment (Day -7 to Day 0)

#### **Day -7: Code Freeze & Testing**

```bash
# 1. Create release branch
git checkout main
git pull origin main
git checkout -b release/v1.0.0

# 2. Update version in all files
find . -name "Chart.yaml" -exec sed -i 's/version: .*/version: 1.0.0/' {} \;
find . -name "Chart.yaml" -exec sed -i 's/appVersion: .*/appVersion: v1.0.0/' {} \;

# 3. Run full test suite
./tests/run-all-tests.sh

# 4. Build and scan images
./scripts/build-all-images.sh v1.0.0
./scripts/scan-images.sh v1.0.0
```

#### **Day -5: Staging Deployment**

```bash
# 1. Deploy to staging
helm upgrade --install datalyptica ./helm/datalyptica \
  --namespace datalyptica-staging \
  --create-namespace \
  --values ./helm/datalyptica/values.staging.yaml \
  --set image.tag=v1.0.0 \
  --wait \
  --timeout 30m

# 2. Run smoke tests
./tests/smoke-tests.sh staging

# 3. Run performance tests
./tests/performance-tests.sh staging

# 4. Validate for 48 hours
```

#### **Day -3: Production Preparation**

```bash
# 1. Backup production database
kubectl exec -n datalyptica-storage postgresql-0 -- \
  pg_dumpall -U postgres > backup-pre-v1.0.0-$(date +%Y%m%d).sql

# 2. Backup Nessie catalog
kubectl exec -n datalyptica-data nessie-0 -- \
  curl http://localhost:19120/api/v2/trees > nessie-backup-$(date +%Y%m%d).json

# 3. Snapshot persistent volumes
./scripts/snapshot-volumes.sh production

# 4. Verify backups
./scripts/verify-backups.sh
```

#### **Day -1: Final Checks**

```bash
# 1. Verify cluster health
kubectl get nodes
kubectl top nodes
kubectl get pods --all-namespaces | grep -v Running

# 2. Check resource availability
kubectl describe nodes | grep -A 5 "Allocated resources"

# 3. Verify monitoring
curl -s http://prometheus.company.com/api/v1/query?query=up | jq .

# 4. Test alerting
./scripts/test-alerts.sh

# 5. Confirm on-call team
echo "On-call: oncall@company.com, PagerDuty: incident-12345"
```

### 4.2 Phase 2: Deployment (Day 0 - Maintenance Window)

#### **Step 1: Pre-Deployment Snapshot (T-30 min)**

```bash
#!/bin/bash
set -euo pipefail

# Full pre-deployment backup
echo "=== Pre-Deployment Backup ==="

# 1. Backup all persistent volumes
for ns in datalyptica-storage datalyptica-data datalyptica-control; do
  echo "Snapshotting namespace: $ns"
  kubectl get pvc -n $ns -o name | while read pvc; do
    # Trigger CSI snapshot
    cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: pre-deploy-$(date +%Y%m%d-%H%M%S)-${pvc##*/}
  namespace: $ns
spec:
  volumeSnapshotClassName: csi-snapshot-class
  source:
    persistentVolumeClaimName: ${pvc##*/}
EOF
  done
done

# 2. Export all ConfigMaps and Secrets (encrypted)
kubectl get secret --all-namespaces -o yaml > secrets-backup-$(date +%Y%m%d).yaml
kubectl get configmap --all-namespaces -o yaml > configmaps-backup-$(date +%Y%m%d).yaml

echo "✅ Backup complete"
```

#### **Step 2: Maintenance Mode (T-15 min)**

```bash
#!/bin/bash
set -euo pipefail

echo "=== Enabling Maintenance Mode ==="

# 1. Scale down non-critical services
kubectl scale deployment -n datalyptica-management grafana --replicas=0
kubectl scale deployment -n datalyptica-data trino-coordinator --replicas=0

# 2. Display maintenance page (via Ingress)
kubectl annotate ingress -n datalyptica-management datalyptica-ingress \
  "nginx.ingress.kubernetes.io/custom-http-errors"="503" \
  "nginx.ingress.kubernetes.io/default-backend"="maintenance-page"

# 3. Notify users
curl -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -d "channel=#datalyptica-users" \
  -d "text=🚧 Datalyptica platform is entering maintenance mode for v1.0.0 deployment"

echo "✅ Maintenance mode enabled"
```

#### **Step 3: Operator Upgrades (T-10 min)**

```bash
#!/bin/bash
set -euo pipefail

echo "=== Upgrading Operators ==="

# 1. CloudNativePG Operator
helm upgrade --install cnpg-operator cloudnative-pg/cloudnative-pg \
  --namespace datalyptica-system \
  --version 1.21.0 \
  --wait

# 2. MinIO Operator
helm upgrade --install minio-operator minio/operator \
  --namespace datalyptica-system \
  --version 5.0.11 \
  --wait

# 3. Strimzi Kafka Operator
helm upgrade --install strimzi-kafka strimzi/strimzi-kafka-operator \
  --namespace datalyptica-system \
  --version 0.39.0 \
  --wait

# 4. Prometheus Operator
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace datalyptica-management \
  --version 55.0.0 \
  --wait

echo "✅ Operators upgraded"
```

#### **Step 4: Storage Layer Upgrade (T-5 min)**

```bash
#!/bin/bash
set -euo pipefail

echo "=== Upgrading Storage Layer ==="

# 1. PostgreSQL (via CloudNativePG)
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: datalyptica-postgresql
  namespace: datalyptica-storage
spec:
  instances: 3
  imageName: ghcr.io/datalyptica/datalyptica/postgresql:v1.0.0
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "4GB"
      wal_level: "logical"
  bootstrap:
    initdb:
      database: datalyptica
      owner: datalyptica
  storage:
    size: 500Gi
    storageClass: fast-ssd
  monitoring:
    enablePodMonitor: true
EOF

# Wait for rollout
kubectl rollout status cluster/datalyptica-postgresql -n datalyptica-storage --timeout=10m

# 2. MinIO (via Operator - rolling update)
kubectl apply -f - <<EOF
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: datalyptica-minio
  namespace: datalyptica-storage
spec:
  image: ghcr.io/datalyptica/datalyptica/minio:v1.0.0
  pools:
    - servers: 4
      volumesPerServer: 4
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Ti
          storageClassName: fast-ssd
  erasureCodingParity: 2
EOF

# Wait for rollout
kubectl wait --for=condition=Ready tenant/datalyptica-minio -n datalyptica-storage --timeout=15m

# 3. Kafka (via Strimzi - rolling update)
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: datalyptica-kafka
  namespace: datalyptica-control
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    image: ghcr.io/datalyptica/datalyptica/kafka:v1.0.0
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
    storage:
      type: persistent-claim
      size: 1Ti
      class: fast-ssd
  zookeeper: null  # KRaft mode
EOF

# Wait for rollout
kubectl wait --for=condition=Ready kafka/datalyptica-kafka -n datalyptica-control --timeout=15m

echo "✅ Storage layer upgraded"
```

#### **Step 5: Application Layer Upgrade (T+0 min)**

```bash
#!/bin/bash
set -euo pipefail

echo "=== Upgrading Application Layer ==="

# Deploy via Helm (all components)
helm upgrade --install datalyptica ./helm/datalyptica \
  --namespace datalyptica-data \
  --values ./helm/datalyptica/values.production.yaml \
  --set image.tag=v1.0.0 \
  --set image.pullPolicy=IfNotPresent \
  --set resources.trino.coordinator.memory=16Gi \
  --set resources.spark.master.memory=8Gi \
  --set resources.flink.jobmanager.memory=4Gi \
  --set replicaCount.trino.workers=5 \
  --set replicaCount.spark.workers=5 \
  --set replicaCount.flink.taskmanagers=3 \
  --wait \
  --timeout 30m

# Check rollout status
kubectl rollout status deployment/nessie -n datalyptica-data
kubectl rollout status deployment/trino-coordinator -n datalyptica-data
kubectl rollout status deployment/spark-master -n datalyptica-data
kubectl rollout status deployment/flink-jobmanager -n datalyptica-data

echo "✅ Application layer upgraded"
```

#### **Step 6: Validation (T+15 min)**

```bash
#!/bin/bash
set -euo pipefail

echo "=== Running Post-Deployment Validation ==="

# 1. Check all pods are running
echo "Checking pod status..."
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed || echo "✅ All pods running"

# 2. Run health checks
echo "Running health checks..."
./tests/health-checks.sh production

# 3. Smoke tests
echo "Running smoke tests..."
./tests/smoke-tests.sh production

# 4. Verify data integrity
echo "Verifying data integrity..."
kubectl exec -n datalyptica-storage postgresql-0 -- \
  psql -U datalyptica -d datalyptica -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';"

# 5. Test query engines
echo "Testing Trino..."
kubectl exec -n datalyptica-data trino-coordinator-0 -- \
  trino --execute "SELECT 1"

# 6. Verify monitoring
echo "Checking Prometheus targets..."
curl -s http://prometheus.company.com/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

echo "✅ Validation complete"
```

#### **Step 7: Exit Maintenance Mode (T+30 min)**

```bash
#!/bin/bash
set -euo pipefail

echo "=== Exiting Maintenance Mode ==="

# 1. Scale up services
kubectl scale deployment -n datalyptica-management grafana --replicas=2
kubectl scale deployment -n datalyptica-data trino-coordinator --replicas=1

# 2. Remove maintenance page
kubectl annotate ingress -n datalyptica-management datalyptica-ingress \
  "nginx.ingress.kubernetes.io/custom-http-errors-" \
  "nginx.ingress.kubernetes.io/default-backend-"

# 3. Notify users
curl -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -d "channel=#datalyptica-users" \
  -d "text=✅ Datalyptica platform v1.0.0 is now live! Please report any issues to #datalyptica-support"

# 4. Update status page
curl -X POST https://status.company.com/api/incidents \
  -H "Authorization: Bearer $STATUS_TOKEN" \
  -d "status=resolved" \
  -d "incident_id=12345"

echo "✅ Maintenance mode ended"
```

### 4.3 Phase 3: Post-Deployment Monitoring (T+30 min to T+24 hours)

#### **Immediate Monitoring (T+30 min - T+2 hours)**

```bash
#!/bin/bash

# Monitor in real-time
watch -n 10 '
  echo "=== Pod Status ==="
  kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

  echo "\n=== Resource Usage ==="
  kubectl top nodes

  echo "\n=== Active Alerts ==="
  curl -s http://alertmanager.company.com/api/v2/alerts | jq ".[] | select(.status.state == \"active\") | {alert: .labels.alertname, severity: .labels.severity}"

  echo "\n=== Error Rate (last 5 min) ==="
  curl -s "http://prometheus.company.com/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" | jq .
'
```

#### **Extended Monitoring (T+2 hours - T+24 hours)**

**Metrics to Watch:**

- CPU/Memory usage (should stabilize within 2 hours)
- Query latency (should be < baseline + 10%)
- Error rates (should be < 0.1%)
- Failed jobs/tasks (should be 0)
- Kafka lag (should be < 1000 messages)
- PostgreSQL replication lag (should be < 100MB)

**Automated Alerts:**

```yaml
# alertmanager-rules.yaml
groups:
  - name: post-deployment
    interval: 1m
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected post-deployment"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.pod }} using >90% memory"

      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is crash-looping"
```

---

## 5. Rollback Procedures

### 5.1 Decision Criteria

**Trigger rollback if:**

- Critical functionality broken (unable to query data)
- Data corruption detected
- > 5% error rate sustained for >15 minutes
- Multiple critical alerts firing
- Security breach detected
- Performance degradation >50%

### 5.2 Automated Rollback

```bash
#!/bin/bash
set -euo pipefail

echo "=== INITIATING ROLLBACK TO v0.9.9 ==="

# 1. Enable maintenance mode
./scripts/maintenance-mode.sh enable

# 2. Rollback Helm release
helm rollback datalyptica 0 \
  --namespace datalyptica-data \
  --wait \
  --timeout 15m

# 3. Rollback operators (if necessary)
helm rollback cnpg-operator 0 --namespace datalyptica-system --wait
helm rollback minio-operator 0 --namespace datalyptica-system --wait
helm rollback strimzi-kafka 0 --namespace datalyptica-system --wait

# 4. Verify rollback
./tests/smoke-tests.sh production

# 5. Restore from snapshot (if data corruption)
if [[ "$DATA_CORRUPTION" == "true" ]]; then
  echo "Restoring from pre-deployment snapshot..."
  ./scripts/restore-from-snapshot.sh pre-deploy-20251130
fi

# 6. Disable maintenance mode
./scripts/maintenance-mode.sh disable

# 7. Notify team
curl -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -d "channel=#datalyptica-alerts" \
  -d "text=⚠️ ROLLBACK COMPLETE: Datalyptica rolled back to v0.9.9. Incident investigation in progress."

echo "✅ Rollback complete"
```

### 5.3 Manual Rollback (if automation fails)

```bash
# 1. Identify previous working image
kubectl get pods -n datalyptica-data -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].image}{"\n"}{end}'

# 2. Manually update deployment images
kubectl set image deployment/nessie nessie=ghcr.io/datalyptica/datalyptica/nessie:v0.9.9 -n datalyptica-data
kubectl set image deployment/trino-coordinator trino=ghcr.io/datalyptica/datalyptica/trino:v0.9.9 -n datalyptica-data

# 3. Restore database from backup
kubectl exec -n datalyptica-storage postgresql-0 -- \
  psql -U postgres < backup-pre-v1.0.0-20251130.sql

# 4. Verify
./tests/health-checks.sh production
```

---

## 6. Security Hardening

### 6.1 Pre-Production Security Checklist

- [ ] **Image Scanning:** All images scanned with Trivy (0 critical vulnerabilities)
- [ ] **Network Policies:** Ingress/egress rules configured per namespace
- [ ] **Pod Security Standards:** Enforced (restricted profile)
- [ ] **RBAC:** Least privilege service accounts configured
- [ ] **Secrets:** All secrets encrypted at rest (K8s etcd encryption)
- [ ] **TLS:** All inter-service communication encrypted
- [ ] **Audit Logging:** Kubernetes audit logs enabled
- [ ] **Admission Controllers:** Pod Security Admission enabled
- [ ] **Resource Limits:** Memory/CPU limits set on all pods
- [ ] **Security Context:** Non-root users, read-only root filesystem

### 6.2 Network Policies

```yaml
# Example: Restrict Nessie to only accept connections from Trino/Spark/Flink
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nessie-ingress
  namespace: datalyptica-data
spec:
  podSelector:
    matchLabels:
      app: nessie
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: trino
        - podSelector:
            matchLabels:
              app: spark
        - podSelector:
            matchLabels:
              app: flink
      ports:
        - protocol: TCP
          port: 19120
```

### 6.3 Pod Security Policy

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: datalyptica-data
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## 7. Performance Optimization

### 7.1 Resource Tuning

**PostgreSQL:**

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2"
  limits:
    memory: "16Gi"
    cpu: "8"
```

**Trino Coordinator:**

```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4"
  limits:
    memory: "32Gi"
    cpu: "16"
```

**Trino Workers:** (5 nodes)

```yaml
resources:
  requests:
    memory: "16Gi"
    cpu: "8"
  limits:
    memory: "64Gi"
    cpu: "32"
```

### 7.2 Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: trino-worker-hpa
  namespace: datalyptica-data
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: trino-worker
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### 7.3 Node Affinity & Taints

```yaml
# Dedicate high-memory nodes for Trino
nodeSelector:
  workload: memory-intensive

tolerations:
  - key: "workload"
    operator: "Equal"
    value: "memory-intensive"
    effect: "NoSchedule"
```

---

## 8. Disaster Recovery

### 8.1 Backup Strategy

**Daily Backups:**

- PostgreSQL: Full dump (pg_dump)
- Nessie catalog: JSON export
- Kafka topics: Mirror to DR cluster
- Configurations: Git repository (GitOps)

**Weekly Backups:**

- MinIO data: Snapshot to cold storage (S3 Glacier)
- Prometheus metrics: Export to long-term storage (Thanos)

**Monthly Backups:**

- Full platform snapshot (volumes + configs)

### 8.2 Restore Procedure

```bash
#!/bin/bash
# Disaster Recovery Restore

echo "=== DISASTER RECOVERY RESTORE ==="

# 1. Provision new K8s cluster (if needed)
./scripts/provision-cluster.sh production-dr

# 2. Install operators
./scripts/install-operators.sh

# 3. Restore storage layer
kubectl create namespace datalyptica-storage
kubectl apply -f backups/postgresql-snapshot.yaml
kubectl apply -f backups/minio-snapshot.yaml

# 4. Restore data
kubectl exec -n datalyptica-storage postgresql-0 -- \
  psql -U postgres < backups/postgresql-full-20251130.sql

# 5. Deploy application layer
helm install datalyptica ./helm/datalyptica \
  --namespace datalyptica-data \
  --values ./helm/datalyptica/values.production.yaml

# 6. Verify
./tests/health-checks.sh production-dr

echo "✅ DR restore complete"
```

### 8.3 RTO & RPO Targets

| Tier                     | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
| ------------------------ | ----------------------------- | ------------------------------ |
| **Critical (Metadata)**  | <30 minutes                   | <15 minutes                    |
| **High (Control Plane)** | <1 hour                       | <1 hour                        |
| **Medium (Data)**        | <4 hours                      | <24 hours                      |
| **Low (Logs/Metrics)**   | <24 hours                     | <7 days                        |

---

## 9. Monitoring & Alerting

### 9.1 Key Metrics

**SLIs (Service Level Indicators):**

- **Availability:** % of successful health checks
- **Latency:** p50, p95, p99 query response times
- **Throughput:** Queries per second, messages per second
- **Error Rate:** % of failed requests

**SLOs (Service Level Objectives):**

- Availability: 99.9% (< 43 minutes downtime/month)
- Query Latency (p95): <2 seconds
- Kafka Throughput: >100k msg/sec
- Error Rate: <0.1%

### 9.2 Critical Alerts

```yaml
groups:
  - name: critical
    rules:
      - alert: ServiceDown
        expr: up{job="datalyptica"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"

      - alert: HighQueryLatency
        expr: histogram_quantile(0.95, rate(query_duration_seconds_bucket[5m])) > 2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "p95 query latency > 2 seconds"

      - alert: PostgreSQLDown
        expr: pg_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down"

      - alert: KafkaLagHigh
        expr: kafka_consumergroup_lag > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Kafka consumer lag > 10k messages"
```

### 9.3 On-Call Runbooks

**Service Down:**

1. Check pod status: `kubectl get pods -n datalyptica-data`
2. Check logs: `kubectl logs -n datalyptica-data <pod-name> --tail=100`
3. Check events: `kubectl describe pod -n datalyptica-data <pod-name>`
4. Restart if necessary: `kubectl rollout restart deployment/<name> -n datalyptica-data`
5. Escalate if not resolved in 15 minutes

**High Memory Usage:**

1. Check current usage: `kubectl top pods -n datalyptica-data`
2. Identify heavy queries (Trino): Check Trino UI
3. Kill long-running queries if needed
4. Scale horizontally if sustained
5. Review and optimize queries

---

## 10. Compliance & Audit

### 10.1 Compliance Checklist

- [ ] **Change Management:** CAB approval obtained
- [ ] **Security Review:** Security team sign-off
- [ ] **Privacy Impact:** GDPR compliance verified
- [ ] **Audit Trail:** All changes logged
- [ ] **Documentation:** Runbooks updated
- [ ] **Testing:** All tests passed
- [ ] **Backup:** Pre-deployment backup completed
- [ ] **Communication:** Stakeholders notified

### 10.2 Audit Log Queries

```bash
# Who deployed?
kubectl logs -n datalyptica-system deployment/argocd-server | grep "sync datalyptica"

# What changed?
git log --since="2025-11-30" --until="2025-12-01" --pretty=format:"%h - %an, %ar : %s"

# When was it deployed?
kubectl get events -n datalyptica-data --sort-by='.lastTimestamp' | grep deployment

# Approval chain?
cat deployment-approval-12345.pdf
```

---

## 11. Post-Deployment Tasks

### 11.1 Immediate (Day 0-1)

- [ ] Monitor for 24 hours continuously
- [ ] Review all alerts and logs
- [ ] Document any issues encountered
- [ ] Update runbooks with lessons learned
- [ ] Send deployment summary to stakeholders

### 11.2 Short-term (Week 1)

- [ ] Performance baseline comparison
- [ ] User feedback collection
- [ ] Cost analysis (vs previous version)
- [ ] Optimization opportunities identified
- [ ] Post-mortem if issues occurred

### 11.3 Long-term (Month 1)

- [ ] Quarterly review scheduled
- [ ] Capacity planning updated
- [ ] Roadmap adjusted based on learnings
- [ ] Training materials updated
- [ ] Next version planning started

---

## Appendices

### A. Quick Reference

**Emergency Contacts:**

- On-Call: +1-555-ONCALL
- Security: security@company.com
- Platform Team: platform@company.com

**Key Commands:**

```bash
# Health check
kubectl get pods --all-namespaces | grep -v Running

# View logs
kubectl logs -n datalyptica-data <pod-name> --tail=100 --follow

# Restart service
kubectl rollout restart deployment/<name> -n datalyptica-data

# Rollback
helm rollback datalyptica 0 -n datalyptica-data

# Emergency maintenance mode
./scripts/maintenance-mode.sh enable
```

### B. Common Issues

| Issue            | Symptoms                    | Resolution                                      |
| ---------------- | --------------------------- | ----------------------------------------------- |
| Pod pending      | Pod stuck in Pending state  | Check resource availability, PVC binding        |
| ImagePullBackOff | Cannot pull container image | Verify image exists, check registry credentials |
| CrashLoopBackOff | Pod continuously restarting | Check logs, verify configuration                |
| Out of Memory    | Pod killed by OOM           | Increase memory limits, optimize queries        |
| High CPU         | Throttling detected         | Increase CPU limits or scale horizontally       |

### C. Version History

| Version | Date       | Changes                    | Deployed By |
| ------- | ---------- | -------------------------- | ----------- |
| v1.0.0  | 2025-11-30 | Initial production release | deploy-bot  |
| v0.9.9  | 2025-11-15 | Pre-release candidate      | deploy-bot  |
| v0.9.0  | 2025-11-01 | Beta release               | deploy-bot  |

---

**Document Control:**

- **Version:** 1.0.0
- **Last Updated:** November 30, 2025
- **Next Review:** December 15, 2025
- **Owner:** Platform Operations Team
- **Approvals:** DevOps Lead, Security Lead, Platform Architect
