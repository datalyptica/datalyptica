# 📍 NAVIGATION INDEX

**This is your single source of truth for deploying Datalyptica on OpenShift.**

---

## 🎯 START HERE

### New to this deployment?

**Read:** [`README.md`](./README.md) - Complete overview and architecture

### Want to deploy quickly?

**Read:** [`QUICK-START.md`](./QUICK-START.md) - Express 3-hour deployment guide

### Want detailed step-by-step?

**Follow:** The phase-by-phase guides below

---

## 📂 DIRECTORY STRUCTURE

```
PRODUCTION-DEPLOYMENT/
├── INDEX.md                           ← YOU ARE HERE
├── README.md                          ← Start here for overview
├── QUICK-START.md                     ← Express deployment guide
├── VALIDATION-CHECKLIST.md            ← Track your progress
│
├── 00-PREREQUISITES/
│   ├── STEP-1-namespace-setup.yaml    ← Create 4 namespaces
│   ├── STEP-2-operator-install.md     ← Install 3 operators
│   └── STEP-3-storage-validation.md   ← Validate storage
│
├── 01-CORE-INFRASTRUCTURE/
│   ├── README.md                      ← Phase 1 deployment guide
│   ├── postgresql-ha.yaml             ← PostgreSQL 3-node HA cluster
│   ├── redis-sentinel.yaml            ← Redis 3+3 Sentinel cluster
│   ├── etcd-cluster.yaml              ← etcd 3-node cluster
│   └── minio-distributed.yaml         ← MinIO 4-node distributed
│
└── 02-DATA-LAYER/
    ├── README.md                      ← Phase 2 deployment guide
    └── nessie-deployment.yaml         ← Nessie data catalog
```

---

## 📖 READING ORDER

### For Comprehensive Understanding:

1. **README.md** - Understand what you're building
2. **00-PREREQUISITES/STEP-1** - Create namespaces
3. **00-PREREQUISITES/STEP-2** - Install operators
4. **00-PREREQUISITES/STEP-3** - Validate storage
5. **01-CORE-INFRASTRUCTURE/README.md** - Deploy core services
6. **02-DATA-LAYER/README.md** - Deploy data layer
7. **VALIDATION-CHECKLIST.md** - Validate everything

### For Quick Deployment:

1. **QUICK-START.md** - All steps in one file
2. **VALIDATION-CHECKLIST.md** - Verify completion

---

## 🎯 DEPLOYMENT PATHS

### Path 1: Guided Step-by-Step (Recommended for first-time users)

```
README.md (read)
    ↓
00-PREREQUISITES/
    ├─ STEP-1-namespace-setup.yaml (apply)
    ├─ STEP-2-operator-install.md (follow)
    └─ STEP-3-storage-validation.md (follow)
    ↓
01-CORE-INFRASTRUCTURE/
    ├─ README.md (read)
    ├─ postgresql-ha.yaml (deploy)
    ├─ redis-sentinel.yaml (deploy)
    ├─ etcd-cluster.yaml (deploy)
    └─ minio-distributed.yaml (deploy)
    ↓
02-DATA-LAYER/
    ├─ README.md (read)
    └─ nessie-deployment.yaml (deploy)
    ↓
VALIDATION-CHECKLIST.md (complete)
```

### Path 2: Express Deployment (For experienced users)

```
QUICK-START.md (follow all steps)
    ↓
VALIDATION-CHECKLIST.md (validate)
```

---

## 🔍 QUICK REFERENCE

### File Purpose Guide

| File                           | Purpose                                   | When to Use                                      |
| ------------------------------ | ----------------------------------------- | ------------------------------------------------ |
| `README.md`                    | Complete overview, architecture, concepts | First time reading, understanding platform       |
| `QUICK-START.md`               | Express deployment in one file            | Quick deployment, already familiar with concepts |
| `VALIDATION-CHECKLIST.md`      | Track deployment progress                 | During deployment, post-deployment validation    |
| `STEP-1-namespace-setup.yaml`  | Create OpenShift projects                 | First deployment step                            |
| `STEP-2-operator-install.md`   | Install required operators                | After namespaces, before services                |
| `STEP-3-storage-validation.md` | Validate storage availability             | After operators, before deployment               |
| `postgresql-ha.yaml`           | PostgreSQL HA cluster                     | First core service to deploy                     |
| `redis-sentinel.yaml`          | Redis HA cache                            | Second core service                              |
| `etcd-cluster.yaml`            | etcd distributed config                   | Third core service                               |
| `minio-distributed.yaml`       | MinIO object storage                      | Fourth core service                              |
| `nessie-deployment.yaml`       | Nessie data catalog                       | After core infrastructure complete               |

---

## 🎓 CONCEPTS & TERMINOLOGY

### What is "Core Infrastructure"?

The foundational services that all other applications depend on:

- **PostgreSQL**: Primary database
- **Redis**: Caching and session storage
- **etcd**: Distributed configuration
- **MinIO**: Object storage (S3-compatible)

### What is "Data Layer"?

Services that manage data catalog and metadata:

- **Nessie**: Data versioning and catalog

### What are "Operators"?

Kubernetes extensions that automate complex application management:

- **Crunchy Postgres Operator**: Manages PostgreSQL clusters
- **MinIO Operator**: Manages MinIO distributed storage
- **Strimzi Operator**: Manages Kafka clusters (for future use)

### What is "HA" (High Availability)?

Multiple replicas of services with automatic failover:

- **PostgreSQL**: 1 primary + 2 replicas
- **Redis**: 3 nodes + 3 sentinels
- **etcd**: 3-node quorum
- **MinIO**: 4-node erasure coding

---

## ⏱️ TIME ESTIMATES

| Phase                   | Duration    | What You're Doing                                      |
| ----------------------- | ----------- | ------------------------------------------------------ |
| **Reading & Planning**  | 30 min      | Understand architecture, prepare cluster               |
| **Prerequisites**       | 30 min      | Create namespaces, install operators, validate storage |
| **Core Infrastructure** | 90 min      | Deploy PostgreSQL, Redis, etcd, MinIO                  |
| **Data Layer**          | 15 min      | Deploy Nessie                                          |
| **Validation**          | 30 min      | Test all services, verify HA                           |
| **TOTAL**               | **3 hours** | Complete core platform                                 |

---

## ✅ SUCCESS CRITERIA

You're done when:

- [ ] 20 pods running (18 infrastructure + 2 data)
- [ ] All PVCs bound (~15 PVCs, 275Gi total)
- [ ] PostgreSQL: 1 leader + 2 replicas
- [ ] Redis: 1 master + 2 slaves + 3 sentinels
- [ ] etcd: 3 healthy nodes
- [ ] MinIO: 4 servers online, console accessible
- [ ] Nessie: 2 pods, API responding, "main" branch created
- [ ] All credentials documented
- [ ] All connection strings tested

---

## 🆘 NEED HELP?

### Common Issues

**"Where do I start?"**
→ Read `README.md`, then follow `QUICK-START.md`

**"Operator not installing"**
→ Check `00-PREREQUISITES/STEP-2-operator-install.md` troubleshooting section

**"Pods stuck in Pending"**
→ Check `00-PREREQUISITES/STEP-3-storage-validation.md` - likely storage issue

**"Can't connect to service"**
→ Check pod logs: `oc logs -n <namespace> <pod-name>`

**"PostgreSQL cluster not forming"**
→ Check `01-CORE-INFRASTRUCTURE/README.md` troubleshooting section

### Where to Find Answers

| Question                         | File                                                 |
| -------------------------------- | ---------------------------------------------------- |
| What am I building?              | `README.md`                                          |
| How do I deploy quickly?         | `QUICK-START.md`                                     |
| How do I validate my deployment? | `VALIDATION-CHECKLIST.md`                            |
| Why isn't the operator working?  | `00-PREREQUISITES/STEP-2-operator-install.md`        |
| Why are pods pending?            | `00-PREREQUISITES/STEP-3-storage-validation.md`      |
| PostgreSQL issues                | `01-CORE-INFRASTRUCTURE/README.md` → Troubleshooting |
| Redis issues                     | `01-CORE-INFRASTRUCTURE/README.md` → Troubleshooting |
| MinIO issues                     | `01-CORE-INFRASTRUCTURE/README.md` → Troubleshooting |
| Nessie issues                    | `02-DATA-LAYER/README.md` → Troubleshooting          |

---

## 📚 EXTERNAL REFERENCES

### Operator Documentation

- [Crunchy Postgres Operator](https://access.crunchydata.com/documentation/postgres-operator/)
- [MinIO Operator](https://min.io/docs/minio/kubernetes/upstream/)
- [Strimzi Kafka Operator](https://strimzi.io/documentation/)

### OpenShift Documentation

- [OperatorHub](https://docs.openshift.com/container-platform/4.10/operators/understanding/olm-understanding-operatorhub.html)
- [Storage](https://docs.openshift.com/container-platform/4.10/storage/understanding-persistent-storage.html)
- [Networking](https://docs.openshift.com/container-platform/4.10/networking/understanding-networking.html)

### Component Documentation

- [PostgreSQL 15](https://www.postgresql.org/docs/15/)
- [Redis 7](https://redis.io/docs/)
- [etcd](https://etcd.io/docs/)
- [MinIO](https://min.io/docs/minio/linux/index.html)
- [Nessie](https://projectnessie.org/docs/)

---

## 🎯 QUICK NAVIGATION

**Choose your path:**

- 🆕 **First time deploying?** → Start with [`README.md`](./README.md)
- ⚡ **Want quick deployment?** → Jump to [`QUICK-START.md`](./QUICK-START.md)
- 📋 **Track your progress?** → Use [`VALIDATION-CHECKLIST.md`](./VALIDATION-CHECKLIST.md)
- 🔧 **Prerequisites?** → Go to [`00-PREREQUISITES/`](./00-PREREQUISITES/)
- 🏗️ **Deploy infrastructure?** → Go to [`01-CORE-INFRASTRUCTURE/`](./01-CORE-INFRASTRUCTURE/)
- 📊 **Deploy data layer?** → Go to [`02-DATA-LAYER/`](./02-DATA-LAYER/)

---

**Good luck with your deployment! 🚀**
