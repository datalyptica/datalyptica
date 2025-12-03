# OpenShift Deployment - Quick Reference Guide

**Datalyptica Version**: 4.0.0  
**OpenShift Version**: 4.17+  
**Last Updated**: December 2025

---

## 📚 Documentation Index

### Main Deployment Guides

1. **[CLI Deployment Guide](./OPENSHIFT_DEPLOYMENT_CLI.md)** - Complete command-line deployment
   - Best for: Automation, CI/CD, experienced users
   - Tool: `oc` CLI
   - Time: ~2-3 hours
   - Difficulty: Intermediate to Advanced

2. **[UI Deployment Guide](./OPENSHIFT_DEPLOYMENT_UI.md)** - Web Console deployment
   - Best for: Visual learners, first-time deployments, administrators
   - Tool: OpenShift Web Console (browser-based)
   - Time: ~3-4 hours
   - Difficulty: Beginner to Intermediate

### Supporting Documentation

3. **[Component Versions](../deploy/openshift/docs/COMPONENT-VERSIONS.md)** - Verified versions & migration guides
4. **[Version Update Summary](./VERSION_UPDATE_SUMMARY.md)** - Recent update details
5. **[Architecture Overview](../deploy/openshift/README.md)** - Platform architecture & design
6. **[Next Steps](./NEXT_STEPS.md)** - Post-deployment tasks

---

## 🚀 Quick Start Decision Tree

### Which Deployment Method Should I Use?

```
Are you comfortable with command-line tools?
├─ YES → Do you need automation/scripting?
│   ├─ YES → Use CLI Guide (OPENSHIFT_DEPLOYMENT_CLI.md)
│   └─ NO → Either guide works, CLI is faster
└─ NO → Do you prefer visual interfaces?
    ├─ YES → Use UI Guide (OPENSHIFT_DEPLOYMENT_UI.md)
    └─ NO → Start with UI Guide, learn CLI later
```

### Comparison Table

| Feature | CLI Method | UI Method |
|---------|-----------|-----------|
| **Speed** | ⚡⚡⚡ Fast | ⚡⚡ Moderate |
| **Automation** | ✅ Yes | ❌ Manual |
| **Learning Curve** | Steep | Gentle |
| **Visibility** | Terminal output | Visual dashboards |
| **Best For** | Automation, experts | Learning, one-time setup |
| **Prerequisites** | oc CLI installed | Just a browser |
| **Copy-Paste** | YAML files ready | YAML embedded in guide |
| **Troubleshooting** | CLI commands | Visual inspection |

---

## 📋 Deployment Phases Overview

Both methods follow the same deployment phases:

### Phase 1: Pre-Deployment ⚙️
- [ ] Access OpenShift cluster
- [ ] Create namespaces/projects
- [ ] Configure security (SCC)
- [ ] Set up storage classes
- [ ] Generate secrets

**Time**: 15-20 minutes

### Phase 2: Operator Installation 🔧
- [ ] Strimzi Kafka Operator (v0.49.0)
- [ ] Crunchy PostgreSQL Operator (v5.8.5)
- [ ] Flink Kubernetes Operator (v1.13.0)

**Time**: 10-15 minutes  
**Critical**: Required for managed services

### Phase 3: Storage Layer 💾
- [ ] MinIO (Object Storage)
- [ ] PostgreSQL (Relational DB)
- [ ] Redis (Cache & Metadata)

**Time**: 20-30 minutes  
**Critical**: Foundation for all services

### Phase 4: Catalog Layer 📚
- [ ] Nessie (Catalog Service)
- [ ] Redis Sentinel (HA)

**Time**: 10-15 minutes

### Phase 5: Streaming Layer 🌊
- [ ] Apache Kafka (v4.1.1) ⚠️
- [ ] Schema Registry

**Time**: 15-20 minutes  
**Note**: v4.1.1 requires v1 API (breaking change)

### Phase 6: Processing Layer ⚙️
- [ ] Apache Spark (v4.0.1) ⚠️
- [ ] Apache Flink (v2.1.1) ⚠️
- [ ] Apache Iceberg (v1.10.0)

**Time**: 20-30 minutes  
**Note**: Multiple major version updates

### Phase 7: Query Layer 🔍
- [ ] Trino (v478)
- [ ] ClickHouse (v25.11.2.24) ⚠️

**Time**: 15-20 minutes

### Phase 8: Analytics & ML Layer 🤖
- [ ] Apache Airflow (v3.1.3) ⚠️
- [ ] JupyterHub (v5.4.2)
- [ ] MLflow (v3.6.0) ⚠️
- [ ] Apache Superset (v5.0.0)

**Time**: 30-40 minutes

### Phase 9: Monitoring Layer 📊
- [ ] Prometheus (v3.8.0)
- [ ] Grafana (v12.3.0) ⚠️
- [ ] Loki (v3.6.2) 🔒
- [ ] Alertmanager (v0.29.0)

**Time**: 20-30 minutes

### Phase 10: IAM Layer 🔐
- [ ] Keycloak (v26.4.7) 🔒

**Time**: 10-15 minutes

### Total Deployment Time
- **CLI Method**: ~2-3 hours
- **UI Method**: ~3-4 hours
- **With breaks**: Plan for 4-6 hours

**⚠️** = Major version update (breaking changes)  
**🔒** = Security update (CVE fixes)

---

## 🎯 Resource Requirements

### Minimum Cluster Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **Worker Nodes** | 3 | 5+ |
| **CPU per Node** | 16 cores | 32 cores |
| **Memory per Node** | 64 GB | 128 GB |
| **Storage** | 2 TB | 5+ TB |
| **Network** | 10 Gbps | 25 Gbps |

### Per-Service Resource Allocation

**High Resource** (4+ CPU, 8+ GB RAM):
- Kafka brokers
- Spark workers
- PostgreSQL
- Trino coordinators
- ClickHouse

**Medium Resource** (2-4 CPU, 4-8 GB RAM):
- Airflow webserver/scheduler
- MLflow
- Grafana
- Keycloak
- Flink

**Low Resource** (<2 CPU, <4 GB RAM):
- Redis
- Nessie
- MinIO (single instance)
- Prometheus
- Loki
- Alertmanager

---

## 🔧 Prerequisites Checklist

### For CLI Method

- [ ] OpenShift cluster access with admin privileges
- [ ] `oc` CLI tool installed and configured
- [ ] `kubectl` CLI tool installed (comes with oc)
- [ ] `helm` CLI tool (for Flink operator)
- [ ] Git repository cloned locally
- [ ] Terminal/shell with bash or zsh
- [ ] Network access to OpenShift cluster
- [ ] Password generator or password manager

**Installation Commands**:
```bash
# Install oc CLI (Linux)
curl -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/

# Install oc CLI (macOS)
brew install openshift-cli

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
oc version
kubectl version --client
helm version
```

### For UI Method

- [ ] OpenShift cluster access with admin privileges
- [ ] Modern web browser (Chrome, Firefox, Safari, Edge)
- [ ] Network access to OpenShift Web Console
- [ ] Text editor (for copying YAML)
- [ ] Password generator or password manager
- [ ] Access to deployment guide (bookmarked/saved)

**Recommended Browser Extensions**:
- YAML/JSON formatter
- Dark mode (for late-night deployments)

---

## 📖 Component Versions Reference

### Verified Versions (December 2025)

**Operators**:
- Strimzi Kafka: **0.49.0** (Dec 2025) ⚠️ v1 API required
- Crunchy PostgreSQL: **5.8.5** (Dec 2025)
- Flink Kubernetes: **1.13.0** (Sep 2025)

**Storage & Catalog**:
- MinIO: **RELEASE.2025-10-15T17-29-55Z** 🔒 CVE fix
- PostgreSQL: **16.6**
- Redis: **8.4.0** ⚠️ 30%+ performance boost
- Nessie: **0.105.7**

**Streaming**:
- Kafka: **4.1.1** ⚠️ KRaft production-ready
- Strimzi: **0.49.0** ⚠️ v1 API mandatory

**Processing**:
- Spark: **4.0.1** ⚠️ Scala 2.13 only (recommended)
- Spark Alt: **3.5.7** (Scala 2.12 compatible)
- Flink: **2.1.1** ⚠️ Major API changes
- Iceberg: **1.10.0** (Spark 4.0 + Flink 2.0 support!)

**Query**:
- Trino: **478**
- ClickHouse: **25.11.2.24** ⚠️ Major series update

**Analytics & ML**:
- Airflow: **3.1.3** ⚠️ Python 3.9-3.13
- JupyterHub: **5.4.2**
- MLflow: **3.6.0** ⚠️ OpenTelemetry
- Superset: **5.0.0** (Stable GA)

**Monitoring**:
- Prometheus: **3.8.0**
- Grafana: **12.3.0** ⚠️ SQLite backend
- Loki: **3.6.2** 🔒 CVE fixes
- Alertmanager: **0.29.0**

**IAM**:
- Keycloak: **26.4.7** 🔒 Security updates

**Legend**:
- ⚠️ = Major version update with breaking changes
- 🔒 = Security update (CVE fixes included)

---

## 🚨 Known Issues & Breaking Changes

### Critical Breaking Changes

1. **Kafka 4.1.1** (3.x → 4.x)
   - KRaft mode now production-ready
   - ZooKeeper migration required for upgrades
   - API v1 mandatory (v1beta2 deprecated)

2. **Spark 4.0.1** (3.x → 4.x)
   - Scala 2.13 only (2.12 dropped)
   - Alternative: Use Spark 3.5.7 for Scala 2.12
   - Iceberg 1.10.0 fully supports Spark 4.0

3. **Strimzi 0.49.0** (0.43 → 0.49)
   - v1 API mandatory
   - All Kafka CRDs must use `kafka.strimzi.io/v1`
   - Update all custom resources before deployment

4. **Grafana 12.3.0** (11.x → 12.x)
   - New SQLite backend
   - CVE-2025-41115 fix
   - Dashboard migration may be required

5. **Redis 8.4.0** (7.x → 8.x)
   - 30%+ throughput improvement
   - 92% memory reduction (new encoding)
   - Command syntax changes

6. **Airflow 3.1.3** (2.x → 3.x)
   - Python 3.9-3.13 support
   - SQLAlchemy 2.0 required
   - DAG compatibility check needed

7. **MLflow 3.6.0** (2.x → 3.x)
   - Full OpenTelemetry integration
   - TypeScript SDK added
   - API endpoint changes

8. **Flink 2.1.1** (1.x → 2.x)
   - API changes
   - Job resubmission required
   - Improved checkpointing

9. **ClickHouse 25.11.2.24** (24.x → 25.x)
   - Major series update
   - Query optimizer improvements
   - Schema compatibility check needed

**See**: `/deploy/openshift/docs/COMPONENT-VERSIONS.md` for detailed migration guides

---

## ✅ Deployment Verification

### Quick Health Checks

**After each phase, verify**:

```bash
# Check all pods are running
oc get pods --all-namespaces | grep datalyptica

# Check all services
oc get svc --all-namespaces | grep datalyptica

# Check all routes
oc get routes --all-namespaces | grep datalyptica

# Check persistent volumes
oc get pvc --all-namespaces | grep datalyptica
```

**Or in UI**:
1. Navigate to **Workloads** → **Pods**
2. Select **All Projects**
3. Filter: `datalyptica-`
4. Verify all pods show **Running** status

### Access Web UIs

After deployment, access these URLs (via Routes):

- **MinIO Console**: Object storage management
- **Grafana**: Monitoring dashboards
- **Prometheus**: Metrics & alerts
- **Airflow**: Workflow orchestration
- **MLflow**: ML experiment tracking
- **Superset**: Data visualization
- **JupyterHub**: Interactive notebooks
- **Keycloak**: Identity & access management
- **Kafka UI**: Topic & consumer management (if deployed)
- **Spark Master**: Cluster monitoring

**Find URLs**:
```bash
# CLI
oc get routes --all-namespaces | grep datalyptica

# Or in UI: Networking → Routes → Select All Projects
```

---

## 🆘 Troubleshooting Quick Reference

### Common Issues

| Issue | Symptom | Quick Fix |
|-------|---------|-----------|
| **Pod Pending** | Pod stuck in Pending | Check PVC status, node resources |
| **ImagePullBackOff** | Can't pull image | Verify image name/tag, check registry access |
| **CrashLoopBackOff** | Pod keeps restarting | Check logs, verify config, increase resources |
| **PVC Pending** | Storage not bound | Check StorageClass, verify provisioner |
| **Service No Endpoints** | Service has no backends | Verify pod labels match service selector |
| **Route 503 Error** | Route returns error | Check pod readiness, verify service |
| **OOM Killed** | Out of memory | Increase memory limits |
| **CPU Throttling** | Slow performance | Increase CPU limits |

### Debug Commands (CLI)

```bash
# View pod logs
oc logs -f <pod-name> -n <namespace>

# Describe pod (see events)
oc describe pod <pod-name> -n <namespace>

# Execute commands in pod
oc exec -it <pod-name> -n <namespace> -- /bin/bash

# Get pod YAML
oc get pod <pod-name> -n <namespace> -o yaml

# Check recent events
oc get events -n <namespace> --sort-by='.lastTimestamp'

# View resource usage
oc adm top pods -n <namespace>
oc adm top nodes
```

### Debug in UI

1. **Go to problematic pod**: Workloads → Pods → Click pod name
2. **Check tabs**:
   - **Details**: Status, conditions, node placement
   - **Metrics**: CPU, Memory, Network usage
   - **Logs**: Application output, errors
   - **Terminal**: Execute commands inside container
   - **Events**: Kubernetes events for pod
   - **YAML**: Full pod specification

---

## 📞 Support & Resources

### Documentation

- **Main Architecture**: `/deploy/openshift/README.md`
- **Component Versions**: `/deploy/openshift/docs/COMPONENT-VERSIONS.md`
- **CLI Guide**: `/docs/OPENSHIFT_DEPLOYMENT_CLI.md`
- **UI Guide**: `/docs/OPENSHIFT_DEPLOYMENT_UI.md`
- **Version Updates**: `/docs/VERSION_UPDATE_SUMMARY.md`
- **Next Steps**: `/docs/NEXT_STEPS.md`
- **Troubleshooting**: `/archive/TROUBLESHOOTING.md`

### Official Documentation

- **OpenShift Docs**: https://docs.openshift.com/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Strimzi**: https://strimzi.io/docs/
- **Crunchy Postgres**: https://access.crunchydata.com/documentation/
- **Apache Kafka**: https://kafka.apache.org/documentation/
- **Apache Spark**: https://spark.apache.org/docs/latest/
- **Apache Airflow**: https://airflow.apache.org/docs/
- **Grafana**: https://grafana.com/docs/

### Community

- **GitHub Issues**: Report bugs, request features
- **Slack/Discord**: Real-time community support
- **Stack Overflow**: Tag questions with `datalyptica`

---

## 🎓 Training & Learning Path

### Recommended Learning Order

1. **Start Here**: Read architecture overview (`/deploy/openshift/README.md`)
2. **Understand Components**: Review component versions and purposes
3. **Choose Method**: CLI for automation, UI for learning
4. **Deploy Test Environment**: Start with UI method on dev cluster
5. **Learn CLI**: Graduate to CLI for production deployments
6. **Automate**: Create scripts/pipelines for repeatable deployments

### Skills Development

**Beginner** (Start with UI):
- OpenShift basics
- Container concepts
- Service networking
- Storage management

**Intermediate** (Move to CLI):
- YAML authoring
- kubectl/oc commands
- Debugging techniques
- Resource management

**Advanced** (Automation):
- Helm charts
- GitOps (ArgoCD/Flux)
- CI/CD pipelines
- Infrastructure as Code

---

## 📝 Deployment Checklist

Print this checklist or keep it open during deployment:

### Pre-Deployment
- [ ] Review architecture documentation
- [ ] Choose deployment method (CLI/UI)
- [ ] Verify cluster meets requirements
- [ ] Prepare password/secrets
- [ ] Clone Git repository (CLI) or bookmark docs (UI)
- [ ] Allocate 4-6 hours for deployment

### Deployment Phases
- [ ] Phase 1: Pre-deployment setup (20 min)
- [ ] Phase 2: Install operators (15 min)
- [ ] Phase 3: Deploy storage layer (30 min)
- [ ] Phase 4: Deploy catalog layer (15 min)
- [ ] Phase 5: Deploy streaming layer (20 min)
- [ ] Phase 6: Deploy processing layer (30 min)
- [ ] Phase 7: Deploy query layer (20 min)
- [ ] Phase 8: Deploy analytics layer (40 min)
- [ ] Phase 9: Deploy monitoring layer (30 min)
- [ ] Phase 10: Deploy IAM layer (15 min)

### Post-Deployment
- [ ] Verify all pods are running
- [ ] Access all web UIs via routes
- [ ] Configure Grafana dashboards
- [ ] Set up Keycloak realms
- [ ] Create test data pipelines
- [ ] Document custom configurations
- [ ] Set up backup procedures
- [ ] Configure alerting rules
- [ ] Performance tuning
- [ ] Security hardening

---

**Ready to Deploy?**

Choose your path:
- **[→ CLI Deployment Guide](./OPENSHIFT_DEPLOYMENT_CLI.md)**
- **[→ UI Deployment Guide](./OPENSHIFT_DEPLOYMENT_UI.md)**

Good luck! 🚀
