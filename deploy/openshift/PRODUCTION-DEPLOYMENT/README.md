# DATALYPTICA PRODUCTION DEPLOYMENT GUIDE

## Complete OpenShift UI Deployment - Single Source of Truth

**Last Updated:** December 3, 2025  
**OpenShift Version:** 4.10+  
**Deployment Method:** OpenShift Web Console (UI)  
**High Availability:** Yes (Operator-based)

---

## 🎯 WHAT YOU'LL BUILD

By following this guide, you will deploy a production-ready data platform with:

### Core Infrastructure (Phase 1)

- ✅ **PostgreSQL 15** - 3-node HA cluster with Patroni (automatic failover)
- ✅ **Redis 7** - 3-node Sentinel cluster (HA cache layer)
- ✅ **MinIO** - 4-node distributed object storage (S3-compatible)
- ✅ **etcd** - 3-node cluster (distributed configuration)

### Data Layer (Phase 2)

- ✅ **Nessie** - Data catalog with version control

### Expected Resources

- **Pods:** 18 running pods
- **CPU:** 40+ cores
- **Memory:** 128Gi+
- **Storage:** 500Gi+

---

## 📁 DIRECTORY STRUCTURE

```
PRODUCTION-DEPLOYMENT/
│
├── README.md                          ← YOU ARE HERE (Start here!)
│
├── 00-PREREQUISITES/
│   ├── STEP-1-namespace-setup.yaml
│   ├── STEP-2-operator-install.md
│   └── STEP-3-storage-validation.md
│
├── 01-CORE-INFRASTRUCTURE/
│   ├── README.md                      ← Phase 1 guide
│   ├── postgresql-ha.yaml
│   ├── redis-sentinel.yaml
│   ├── etcd-cluster.yaml
│   └── minio-distributed.yaml
│
├── 02-DATA-LAYER/
│   ├── README.md                      ← Phase 2 guide
│   └── nessie-deployment.yaml
│
└── VALIDATION-CHECKLIST.md            ← Track your progress
```

---

## ⏱️ TIME ESTIMATE

| Phase             | Time            | Tasks                                 |
| ----------------- | --------------- | ------------------------------------- |
| **Prerequisites** | 30 min          | Install operators, create namespaces  |
| **Phase 1**       | 90 min          | Deploy PostgreSQL, Redis, etcd, MinIO |
| **Phase 2**       | 15 min          | Deploy Nessie                         |
| **Validation**    | 30 min          | Test all services                     |
| **TOTAL**         | **2.5-3 hours** | Complete core platform                |

---

## 🚦 DEPLOYMENT FLOW

```
START
  ↓
00-PREREQUISITES
  ├── Create namespaces (5 min)
  ├── Install operators (15 min)
  └── Validate storage (5 min)
  ↓
01-CORE-INFRASTRUCTURE
  ├── PostgreSQL HA (20 min)
  ├── Redis Sentinel (15 min)
  ├── etcd Cluster (10 min)
  └── MinIO Distributed (30 min)
  ↓
02-DATA-LAYER
  └── Nessie (15 min)
  ↓
VALIDATION
  ├── Test connections
  ├── Verify HA
  └── Document credentials
  ↓
COMPLETE ✅
```

---

## 📋 PREREQUISITES CHECKLIST

Before you begin, ensure you have:

- [ ] **OpenShift Access**
  - OpenShift 4.10 or higher
  - Cluster admin privileges
  - Access to OpenShift Web Console
- [ ] **Cluster Resources**
  - Minimum 10 worker nodes
  - 40+ CPU cores available
  - 128Gi+ memory available
  - 500Gi+ storage available
- [ ] **Storage Configuration**
  - RWO (ReadWriteOnce) storage class
  - Know your storage class name
- [ ] **Network Access**
  - Access to OperatorHub
  - Access to container registries (registry.redhat.io, quay.io)
- [ ] **Tools Ready**
  - OpenShift Web Console URL
  - Text editor for editing YAML
  - Credentials storage (password manager)

---

## 🚀 GETTING STARTED

### Quick Validation

```bash
# Test cluster access
oc login <your-openshift-url>

# Check OpenShift version
oc version

# Check available storage classes
oc get storageclass

# Check worker nodes
oc get nodes -l node-role.kubernetes.io/worker=

# Check available resources
oc adm top nodes
```

### Step 1: Navigate to Prerequisites

```bash
cd 00-PREREQUISITES
```

Read `STEP-1-namespace-setup.yaml` and follow instructions.

---

## 📖 HOW TO USE THIS GUIDE

### For Each Phase:

1. **Read the README.md** in the phase directory
2. **Open the YAML file** in a text editor
3. **Update storage class** (search for `CHANGE THIS`)
4. **Copy YAML content**
5. **Paste in OpenShift Console** (`Operators` → `Installed Operators` → Select Operator → `Create Instance`)
6. **Wait for deployment** (watch pod status)
7. **Validate** using commands provided
8. **Check off** in `VALIDATION-CHECKLIST.md`
9. **Move to next service**

### Using OpenShift Web Console:

**To Create Resource from YAML:**

1. Log into OpenShift Web Console
2. Switch to Administrator perspective
3. Click **Operators** → **Installed Operators**
4. Select the operator (e.g., "Crunchy Postgres Operator")
5. Click **Create Instance** or **Create <ResourceType>**
6. Switch to **YAML view**
7. Paste your YAML content
8. Click **Create**
9. Watch the resource creation in **Workloads** → **Pods**

**To View Resources:**

- **Pods:** Workloads → Pods → Select namespace
- **Services:** Networking → Services → Select namespace
- **PVCs:** Storage → PersistentVolumeClaims → Select namespace
- **Operators:** Operators → Installed Operators

---

## 🎓 UNDERSTANDING THE ARCHITECTURE

### Namespace Organization

| Namespace                | Purpose                      | Components                          |
| ------------------------ | ---------------------------- | ----------------------------------- |
| `datalyptica-infra`      | Core infrastructure services | PostgreSQL, Redis, etcd, MinIO      |
| `datalyptica-data`       | Data catalog and metadata    | Nessie                              |
| `datalyptica-apps`       | Application services         | (Future: Kafka, Trino, Flink, etc.) |
| `datalyptica-monitoring` | Observability stack          | (Future: Prometheus, Grafana)       |

### High Availability Strategy

**PostgreSQL:**

- 3-node cluster (1 primary + 2 replicas)
- Automatic failover via Patroni
- Synchronous replication (zero data loss)
- RPO: < 10 seconds, RTO: < 30 seconds

**Redis:**

- 3 Redis nodes (1 master + 2 replicas)
- 3 Sentinel monitors
- Automatic master election
- RPO: < 5 seconds, RTO: < 20 seconds

**MinIO:**

- 4-node distributed cluster
- Erasure coding (N/2)
- No single point of failure
- RPO: 0, RTO: 0 (always available)

**etcd:**

- 3-node Raft consensus
- Quorum-based writes
- Automatic leader election
- RPO: 0, RTO: < 10 seconds

---

## 🔒 SECURITY CONSIDERATIONS

### Secrets Management

All passwords and credentials are stored in OpenShift Secrets:

- PostgreSQL: `datalyptica-pg-pguser-postgres`
- Redis: `redis-auth`
- MinIO: `minio-root-credentials`
- Nessie: Uses PostgreSQL credentials

**Retrieve secrets:**

```bash
# PostgreSQL password
oc get secret -n datalyptica-infra datalyptica-pg-pguser-postgres \
  -o jsonpath='{.data.password}' | base64 -d

# Redis password
oc get secret -n datalyptica-infra redis-auth \
  -o jsonpath='{.data.password}' | base64 -d

# MinIO credentials
oc get secret -n datalyptica-infra minio-root-credentials \
  -o jsonpath='{.data.rootUser}' | base64 -d
oc get secret -n datalyptica-infra minio-root-credentials \
  -o jsonpath='{.data.rootPassword}' | base64 -d
```

### Network Policies

All services use ClusterIP and are only accessible within the cluster. External access via Routes (created after deployment).

### Pod Security

All pods run with:

- Non-root user IDs
- Read-only root filesystem (where possible)
- Restricted Security Context Constraints (SCC)

---

## 📊 MONITORING YOUR DEPLOYMENT

### Pod Status Commands

```bash
# All infrastructure pods
oc get pods -n datalyptica-infra

# All data layer pods
oc get pods -n datalyptica-data

# Watch pod creation in real-time
watch oc get pods -n datalyptica-infra

# Check pod logs
oc logs -n datalyptica-infra <pod-name>

# Check pod events
oc get events -n datalyptica-infra --sort-by='.lastTimestamp'
```

### Service Endpoints

```bash
# List all services
oc get svc -n datalyptica-infra
oc get svc -n datalyptica-data

# Get service details
oc describe svc -n datalyptica-infra <service-name>
```

### Storage Usage

```bash
# List all PVCs
oc get pvc -n datalyptica-infra
oc get pvc -n datalyptica-data

# Check PVC usage
oc describe pvc -n datalyptica-infra <pvc-name>
```

---

## 🆘 TROUBLESHOOTING

### Common Issues

**Issue: Pods stuck in Pending state**

```bash
# Check PVC binding
oc get pvc -n datalyptica-infra

# Check events
oc get events -n datalyptica-infra --sort-by='.lastTimestamp' | tail -20

# Solution: Verify storage class exists and has available capacity
oc get storageclass
```

**Issue: Operator not installing**

```bash
# Check operator status
oc get csv -n openshift-operators

# Check operator logs
oc logs -n openshift-operators -l name=<operator-name>

# Solution: Wait 10-15 minutes for operator installation
```

**Issue: Pods CrashLoopBackOff**

```bash
# Check pod logs
oc logs -n datalyptica-infra <pod-name>

# Check previous logs
oc logs -n datalyptica-infra <pod-name> --previous

# Solution: Review logs for specific errors
```

**Issue: Can't find operator in OperatorHub**

```bash
# Check if OperatorHub is available
oc get operatorhubs

# Check catalog sources
oc get catalogsource -n openshift-marketplace

# Solution: Ensure OperatorHub is enabled and catalogs are synced
```

---

## 🔄 ROLLBACK PROCEDURES

If you need to start over:

**Delete Phase 2 (Data Layer):**

```bash
oc delete -n datalyptica-data deployment nessie
oc delete -n datalyptica-data svc nessie
```

**Delete Phase 1 (Core Infrastructure):**

```bash
# PostgreSQL
oc delete postgrescluster -n datalyptica-infra datalyptica-pg
oc delete pvc -n datalyptica-infra -l postgres-operator.crunchydata.com/cluster=datalyptica-pg

# Redis
oc delete -n datalyptica-infra statefulset redis redis-sentinel
oc delete pvc -n datalyptica-infra -l app=redis

# MinIO
oc delete tenant -n datalyptica-infra datalyptica-minio
oc delete pvc -n datalyptica-infra -l v1.min.io/tenant=datalyptica-minio

# etcd
oc delete -n datalyptica-infra statefulset etcd
oc delete pvc -n datalyptica-infra -l app=etcd
```

**Delete Namespaces:**

```bash
oc delete project datalyptica-infra datalyptica-data datalyptica-apps
```

---

## 📞 SUPPORT AND DOCUMENTATION

### Internal Documentation

- **Architecture:** `/docs/ARCHITECTURE_REVIEW.md`
- **Technology Stack:** `/docs/TECHNOLOGY_STACK.md`
- **Troubleshooting:** `/docs/TROUBLESHOOTING.md`
- **Security:** `/docs/SECURITY_HARDENING.md`

### Operator Documentation

- **Crunchy Postgres:** https://access.crunchydata.com/documentation/postgres-operator/
- **MinIO Operator:** https://min.io/docs/minio/kubernetes/upstream/
- **Strimzi Kafka:** https://strimzi.io/documentation/

### OpenShift Documentation

- **OperatorHub:** https://docs.openshift.com/container-platform/4.10/operators/understanding/olm-understanding-operatorhub.html
- **Storage:** https://docs.openshift.com/container-platform/4.10/storage/understanding-persistent-storage.html

---

## ✅ SUCCESS CRITERIA

You've successfully deployed the core platform when:

- [ ] All 4 namespaces created and active
- [ ] All operators installed and showing "Succeeded"
- [ ] PostgreSQL: 3 pods running (1 primary + 2 replicas)
- [ ] Redis: 6 pods running (3 Redis + 3 Sentinel)
- [ ] etcd: 3 pods running
- [ ] MinIO: 4 pods running
- [ ] Nessie: 2 pods running
- [ ] All PVCs bound
- [ ] All services have ClusterIP
- [ ] Can connect to PostgreSQL and query
- [ ] Can access MinIO console
- [ ] Nessie API responds to requests
- [ ] Credentials documented and stored securely

---

## 🎯 NEXT STEPS

After completing the core deployment:

1. **Verify HA functionality** - Simulate failures and test automatic recovery
2. **Configure backups** - Set up backup schedules for PostgreSQL and MinIO
3. **Deploy monitoring** - Add Prometheus and Grafana
4. **Add application services** - Deploy Kafka, Trino, Flink, Spark, ClickHouse, Airflow, Superset
5. **Set up CI/CD** - Automate deployments with GitOps

---

## 📝 DEPLOYMENT LOG

Keep track of your deployment:

**Deployment Started:** ********\_\_\_********  
**Deployed By:** ********\_\_\_********  
**OpenShift Cluster:** ********\_\_\_********  
**Storage Class Used:** ********\_\_\_********

**Phase Completion:**

- Prerequisites: ☐ Completed on ******\_\_\_******
- Phase 1 (Core Infrastructure): ☐ Completed on ******\_\_\_******
- Phase 2 (Data Layer): ☐ Completed on ******\_\_\_******
- Validation: ☐ Completed on ******\_\_\_******

**Issues Encountered:**

-
-
-

**Credentials Stored In:** ********\_\_\_********

---

## 🏁 BEGIN DEPLOYMENT

Ready to start? Proceed to:

```bash
cd 00-PREREQUISITES
cat STEP-1-namespace-setup.yaml
```

Good luck! 🚀
