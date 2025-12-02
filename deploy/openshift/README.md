# Datalyptica OpenShift Deployment Manifests

This directory contains all Kubernetes/OpenShift manifests for deploying the Datalyptica platform.

## Directory Structure

```
openshift/
├── namespaces/          # Namespace definitions and quotas
├── operators/           # Operator installations
├── storage/             # PostgreSQL, MinIO deployments
├── control/             # Kafka, Schema Registry, Connect
├── data/                # Trino, Spark, Flink, Nessie, ClickHouse
├── management/          # Keycloak, Grafana, Prometheus, Loki
├── security/            # NetworkPolicies, RBAC, SecurityContextConstraints
├── networking/          # Routes, Services, Ingress
└── scripts/             # Deployment automation scripts
```

## Prerequisites

1. OpenShift cluster 4.13+ with cluster-admin access
2. Storage classes configured (fast-ssd, standard)
3. Generated secrets (run `scripts/01-generate-secrets.sh`)

## Deployment Order

Follow this order for deployment:

### Phase 1: Foundation

```bash
# 1. Create namespaces and quotas
oc apply -k namespaces/

# 2. Generate and create secrets
./scripts/01-generate-secrets.sh
./scripts/02-create-secrets.sh

# 3. Install operators
oc apply -k operators/
```

### Phase 2: Storage Layer

```bash
# 4. Deploy PostgreSQL cluster
oc apply -k storage/postgresql/

# 5. Deploy MinIO tenant
oc apply -k storage/minio/

# Wait for storage to be ready
oc wait --for=condition=Ready cluster/postgresql-ha -n datalyptica-storage --timeout=600s
oc wait --for=condition=Ready tenant/datalyptica-minio -n datalyptica-storage --timeout=600s
```

### Phase 3: Control Layer

```bash
# 6. Deploy Kafka cluster
oc apply -k control/kafka/

# 7. Deploy Schema Registry
oc apply -k control/schema-registry/

# 8. Deploy Kafka Connect
oc apply -k control/kafka-connect/

# Wait for control plane
oc wait --for=condition=Ready kafka/datalyptica-kafka -n datalyptica-control --timeout=900s
```

### Phase 4: Data Layer

```bash
# 9. Deploy Nessie
oc apply -k data/nessie/

# 10. Deploy Trino
oc apply -k data/trino/

# 11. Deploy Spark
oc apply -k data/spark/

# 12. Deploy Flink
oc apply -k data/flink/

# 13. Deploy ClickHouse
oc apply -k data/clickhouse/

# 14. Deploy dbt
oc apply -k data/dbt/
```

### Phase 5: Management Layer

```bash
# 15. Deploy Prometheus
oc apply -k management/prometheus/

# 16. Deploy Loki
oc apply -k management/loki/

# 17. Deploy Grafana
oc apply -k management/grafana/

# 18. Deploy Alertmanager
oc apply -k management/alertmanager/

# 19. Deploy Keycloak
oc apply -k management/keycloak/
```

### Phase 6: Security & Networking

```bash
# 20. Apply NetworkPolicies
oc apply -k security/network-policies/

# 21. Configure RBAC
oc apply -k security/rbac/

# 22. Create Routes
oc apply -k networking/routes/
```

## Quick Deploy (All at Once)

For testing or development:

```bash
./scripts/deploy-all.sh
```

## Validation

After deployment:

```bash
./scripts/validate-deployment.sh
```

## Uninstall

To remove all resources:

```bash
./scripts/uninstall.sh
```

## Documentation

See detailed guides:

- [Complete Deployment Guide](../docs/OPENSHIFT_DEPLOYMENT_GUIDE.md)
- [Part 2 - Compute Layer](../docs/OPENSHIFT_DEPLOYMENT_GUIDE_PART2.md)
- [Part 3 - Observability & Security](../docs/OPENSHIFT_DEPLOYMENT_GUIDE_PART3.md)
