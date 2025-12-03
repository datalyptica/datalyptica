# Next Steps - Kubernetes Manifest Creation

## ✅ Completed (December 2025)

- [x] 100% online version verification (18/18 components)
- [x] Updated OpenShift README.md (version 4.0.0)
- [x] Updated COMPONENT-VERSIONS.md with migration guides
- [x] Updated all 17 YAML configuration files
- [x] Updated all 3 Dockerfiles
- [x] Updated docker-compose.yml with comprehensive version headers
- [x] Created VERSION_UPDATE_SUMMARY.md

## 🎯 Next Priority: Kubernetes Manifest Creation

### Phase 1: Operator Manifests (Critical)

**Required Operators** (must be deployed first):

1. **Strimzi Kafka Operator 0.49.0**

   - Location: `/deploy/openshift/operators/strimzi/`
   - Files needed:
     - `operator-subscription.yaml` (v1 API)
     - `operator-group.yaml`
     - `cluster-role-binding.yaml`

2. **Crunchy PostgreSQL Operator 5.8.5**

   - Location: `/deploy/openshift/operators/postgres/`
   - Files needed:
     - `operator-subscription.yaml`
     - `operator-group.yaml`
     - `cluster-role-binding.yaml`

3. **Flink Kubernetes Operator 1.13.0**
   - Location: `/deploy/openshift/operators/flink/`
   - Files needed:
     - `operator-subscription.yaml`
     - `operator-group.yaml`
     - `cluster-role-binding.yaml`

### Phase 2: Storage & Namespace Setup

**Namespaces** (order matters):

1. `datalyptica-operators` - For all operators
2. `datalyptica-storage` - MinIO, PostgreSQL
3. `datalyptica-catalog` - Nessie, Redis
4. `datalyptica-streaming` - Kafka, Schema Registry
5. `datalyptica-processing` - Spark, Flink, Iceberg
6. `datalyptica-query` - Trino, ClickHouse
7. `datalyptica-analytics` - Airflow, MLflow, Superset, JupyterHub
8. `datalyptica-monitoring` - Prometheus, Grafana, Loki, Alertmanager
9. `datalyptica-iam` - Keycloak

**Storage Classes** (required first):

- Location: `/deploy/openshift/storage/`
- Files needed:
  - `storage-class-fast.yaml` (SSD)
  - `storage-class-standard.yaml` (HDD)
  - `storage-class-object.yaml` (Object storage)

**Persistent Volume Claims**:

- Location: `/deploy/openshift/storage/pvcs/`
- One PVC per stateful service

### Phase 3: Core Services (Critical Path)

**1. Storage Layer** (deploy first):

- MinIO: `RELEASE.2025-10-15T17-29-55Z`
- PostgreSQL: `16.6` (via Crunchy Operator)
- Redis: `8.4.0` ⚠️ MAJOR

**2. Catalog Layer**:

- Nessie: `0.105.7`
- Redis Sentinel: HA setup

**3. Streaming Layer** (after Strimzi deployed):

- Kafka: `4.1.1` ⚠️ MAJOR (use v1 API)
- Schema Registry: Latest

### Phase 4: Processing & Query Engines

**Processing**:

- Spark: `4.0.1` ⚠️ MAJOR (recommended)
- Flink: `2.1.1` ⚠️ MAJOR (after operator)
- Iceberg: `1.10.0`

**Query**:

- Trino: `478`
- ClickHouse: `25.11.2.24` ⚠️ MAJOR

### Phase 5: Analytics & ML

- Airflow: `3.1.3` ⚠️ MAJOR
- JupyterHub: `5.4.2`
- MLflow: `3.6.0` ⚠️ MAJOR
- Superset: `5.0.0`

### Phase 6: Monitoring Stack

- Prometheus: `3.8.0`
- Grafana: `12.3.0` ⚠️ MAJOR
- Loki: `3.6.2` 🔒
- Alertmanager: `0.29.0`

### Phase 7: IAM

- Keycloak: `26.4.7` 🔒

## 📝 Manifest Creation Checklist

For each component, create:

### Standard Kubernetes Resources

- [ ] `namespace.yaml` - Namespace definition
- [ ] `configmap.yaml` - Configuration data
- [ ] `secret.yaml` - Sensitive data (template)
- [ ] `deployment.yaml` OR `statefulset.yaml` - Workload
- [ ] `service.yaml` - Internal service
- [ ] `route.yaml` OR `ingress.yaml` - External access
- [ ] `pvc.yaml` - Storage (if stateful)
- [ ] `serviceaccount.yaml` - RBAC
- [ ] `role.yaml` + `rolebinding.yaml` - Permissions

### Optional Resources (as needed)

- [ ] `hpa.yaml` - Horizontal Pod Autoscaler
- [ ] `networkpolicy.yaml` - Network isolation
- [ ] `poddisruptionbudget.yaml` - HA resilience
- [ ] `servicemonitor.yaml` - Prometheus monitoring
- [ ] `dashboard-configmap.yaml` - Grafana dashboards

### Custom Resources (Operator-managed)

- [ ] `kafka-cr.yaml` - Strimzi Kafka cluster
- [ ] `postgres-cluster-cr.yaml` - Crunchy PostgreSQL
- [ ] `flink-deployment-cr.yaml` - Flink jobs

## 🎯 Critical Considerations

### Version Compatibility

- ✅ All versions verified from authoritative sources
- ⚠️ 9 major breaking changes documented
- 🔒 4 security updates included
- 📚 Migration guides available in COMPONENT-VERSIONS.md

### Resource Requirements (from README.md)

- **CPU Total**: 106 cores (production)
- **Memory Total**: 396 GB (production)
- **Storage Total**: ~10 TB (data + logs)

### Network Requirements

- **Internal Networks**: 7 isolated networks
- **External Access**: Routes/Ingress for UI services
- **Service Mesh**: Optional (consider Istio)

### Security Requirements

- **TLS**: All inter-service communication
- **Secrets**: External secrets operator or Sealed Secrets
- **RBAC**: Fine-grained permissions per namespace
- **Network Policies**: Zero-trust networking

### High Availability

- **Replicas**: 3+ for stateful services
- **Anti-affinity**: Spread across nodes/zones
- **PodDisruptionBudgets**: Maintain availability during updates
- **Health Checks**: Liveness + Readiness probes

## 📂 Suggested Directory Structure

```
/deploy/openshift/
├── operators/
│   ├── strimzi/
│   │   ├── subscription.yaml
│   │   ├── operator-group.yaml
│   │   └── cluster-role-binding.yaml
│   ├── crunchy-postgres/
│   └── flink-operator/
├── namespaces/
│   └── all-namespaces.yaml
├── storage/
│   ├── storage-classes.yaml
│   └── pvcs/
│       ├── minio-pvc.yaml
│       ├── postgres-pvc.yaml
│       └── ...
├── platform/
│   ├── minio/
│   ├── postgres/
│   ├── nessie/
│   ├── kafka/
│   ├── spark/
│   ├── flink/
│   ├── trino/
│   └── clickhouse/
├── analytics/
│   ├── airflow/
│   ├── jupyterhub/
│   ├── mlflow/
│   └── superset/
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   └── alertmanager/
├── iam/
│   └── keycloak/
├── networking/
│   ├── network-policies/
│   └── routes/
└── security/
    ├── service-accounts/
    ├── roles/
    └── sealed-secrets/ (templates)
```

## 🚀 Deployment Order

1. **Operators** → Must be installed first
2. **Namespaces** → Create all namespaces
3. **Storage** → Storage classes + PVCs
4. **Security** → ServiceAccounts, Roles
5. **Storage Services** → MinIO, PostgreSQL
6. **Catalog Services** → Nessie, Redis
7. **Streaming** → Kafka (v1 API)
8. **Processing** → Spark, Flink
9. **Query** → Trino, ClickHouse
10. **Analytics** → Airflow, MLflow, Superset, JupyterHub
11. **Monitoring** → Prometheus, Grafana, Loki
12. **IAM** → Keycloak

## ⚠️ Migration Warnings

**Before deployment, review**:

1. Kafka v1 API migration (v1beta2 deprecated)
2. Spark 4.0.1 Scala 2.13 requirement
3. Grafana 12.x SQLite backend changes
4. Redis 8.x command changes
5. Airflow 3.x Python compatibility
6. Flink 2.x API changes
7. MLflow 3.x OpenTelemetry integration
8. ClickHouse 25.x schema compatibility
9. Strimzi 0.49 API requirements

See `/deploy/openshift/docs/COMPONENT-VERSIONS.md` for detailed migration guides.

## 📞 Support Resources

- **Documentation**: `/deploy/openshift/README.md`
- **Version Details**: `/deploy/openshift/docs/COMPONENT-VERSIONS.md`
- **Update Summary**: `/docs/VERSION_UPDATE_SUMMARY.md`
- **Configuration**: `/configs/` (all updated with version headers)

---

**Status**: ✅ Ready to proceed with Kubernetes manifest creation  
**Next Action**: Create operator manifests for Strimzi, Crunchy, and Flink  
**Estimated Time**: 4-6 hours for complete manifest set
