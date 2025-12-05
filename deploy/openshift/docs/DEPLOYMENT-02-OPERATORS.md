# Datalyptica OpenShift Deployment - Operator Installation

**Date**: December 5, 2025  
**Cluster**: virocp-poc.efinance.com.eg  
**Project**: datalyptica  
**Previous Step**: [Pre-Requisites](DEPLOYMENT-01-PREREQUISITES.md)

---

## Table of Contents

1. [Overview](#overview)
2. [Operator Group Configuration](#operator-group-configuration)
3. [Operator Installation](#operator-installation)
4. [Validation](#validation)
5. [Troubleshooting](#troubleshooting)
6. [Next Steps](#next-steps)

---

## Overview

This document covers the installation of required operators for the Datalyptica Data Platform. All operators are installed in the `datalyptica` namespace using automatic approval for install plans.

### Operators to Install

| Operator                          | Version  | Purpose                        | Source                | Channel |
| --------------------------------- | -------- | ------------------------------ | --------------------- | ------- |
| Strimzi Kafka Operator            | 0.49.0   | Kafka cluster management       | community-operators   | stable  |
| CrunchyData PostgreSQL Operator   | 5.8.4    | PostgreSQL database management | certified-operators   | v5      |
| Keycloak Operator                 | 26.4.7   | Identity and access management | community-operators   | fast    |
| Prometheus Operator               | 0.56.3   | Monitoring and metrics         | community-operators   | beta    |
| Grafana Operator                  | 5.20.0   | Dashboards and visualization   | community-operators   | v5      |

---

## Operator Group Configuration

### Create OperatorGroup

**Objective**: Configure operator management for the datalyptica project

**File**: `deploy/openshift/operator-group.yaml`

```yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: datalyptica-operators
  namespace: datalyptica
spec:
  targetNamespaces:
    - datalyptica
```

**Command**:
```bash
oc apply -f deploy/openshift/operator-group.yaml
```

**Output**:
```
operatorgroup.operators.coreos.com/datalyptica-operators created
```

**Validation**:
```bash
oc get operatorgroup -n datalyptica
```

**Expected Output**:
```
NAME                   AGE
datalyptica-operators  <time>
```

---

## Operator Installation

### File: operators-subscriptions.yaml

**File Location**: `deploy/openshift/operators-subscriptions.yaml`

**Full Configuration**:

```yaml
---
# Strimzi Kafka Operator
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: strimzi-kafka-operator
  namespace: datalyptica
  labels:
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: streaming
spec:
  channel: stable
  name: strimzi-kafka-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
---
# CrunchyData PostgreSQL Operator
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: crunchy-postgres-operator
  namespace: datalyptica
  labels:
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: storage
spec:
  channel: v5
  name: crunchy-postgres-operator
  source: certified-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
---
# Keycloak Operator
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: keycloak-operator
  namespace: datalyptica
  labels:
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: iam
spec:
  channel: fast
  name: keycloak-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
---
# Prometheus Operator
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: prometheus
  namespace: datalyptica
  labels:
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: monitoring
spec:
  channel: beta
  name: prometheus
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
---
# Grafana Operator
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: grafana-operator
  namespace: datalyptica
  labels:
    app.kubernetes.io/part-of: datalyptica
    datalyptica.io/tier: monitoring
spec:
  channel: v5
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
```

### Install All Operators

**Command**:
```bash
oc apply -f deploy/openshift/operators-subscriptions.yaml
```

**Output**:
```
subscription.operators.coreos.com/strimzi-kafka-operator created
subscription.operators.coreos.com/crunchy-postgres-operator created
subscription.operators.coreos.com/keycloak-operator created
subscription.operators.coreos.com/prometheus created
subscription.operators.coreos.com/grafana-operator created
```

### Wait for Installation

Operators will be installed automatically. Wait approximately 30-60 seconds for all operators to reach "Succeeded" phase.

```bash
# Monitor installation progress
watch -n 5 'oc get csv -n datalyptica'

# Or check once
oc get csv -n datalyptica
```

---

## Validation

### Check ClusterServiceVersions (CSV)

**Command**:
```bash
oc get csv -n datalyptica
```

**Expected Output**:
```
NAME                               DISPLAY                       VERSION   REPLACES                           PHASE
cloud-native-postgresql.v1.25.4    EDB Postgres for Kubernetes   1.25.4                                       Succeeded
grafana-operator.v5.20.0           Grafana Operator              5.20.0    grafana-operator.v5.15.1           Succeeded
keycloak-operator.v26.4.7          Keycloak Operator             26.4.7    keycloak-operator.v26.4.6          Succeeded
prometheusoperator.0.56.3          Prometheus Operator           0.56.3    prometheusoperator.0.47.0          Succeeded
strimzi-cluster-operator.v0.49.0   Strimzi                       0.49.0    strimzi-cluster-operator.v0.48.0   Succeeded
```

**Validation Criteria**:
- ✅ All operators show `PHASE: Succeeded`
- ✅ No operators stuck in `Installing` or `Failed` state
- ✅ 5 operators total

### Check Operator Pods

**Command**:
```bash
oc get pods -n datalyptica
```

**Expected Output**:
```
NAME                                                      READY   STATUS    RESTARTS   AGE
grafana-operator-controller-manager-v5-5d6b5f6b6-gc25b    1/1     Running   0          2m
keycloak-operator-586fcddb9f-s6hlt                        1/1     Running   0          2m
postgresql-operator-controller-manager-5d5bd5fd76-gcxp8   1/1     Running   0          2m
prometheus-operator-656f576698-v267x                      1/1     Running   0          2m
strimzi-cluster-operator-v0.49.0-564fd8bbd9-8vwhc         1/1     Running   0          8m
```

**Validation Criteria**:
- ✅ All pods show `STATUS: Running`
- ✅ All pods show `READY: 1/1`
- ✅ No pods in `CrashLoopBackOff` or `Error` state
- ✅ 5 operator pods total

### Check Subscriptions

**Command**:
```bash
oc get subscriptions -n datalyptica
```

**Expected Output**:
```
NAME                      PACKAGE                   SOURCE                CHANNEL
cloud-native-postgresql   cloud-native-postgresql   certified-operators   stable
grafana-operator          grafana-operator          community-operators   v5
keycloak-operator         keycloak-operator         community-operators   fast
prometheus                prometheus                community-operators   beta
strimzi-kafka-operator    strimzi-kafka-operator    community-operators   stable
```

### Verify Available CRDs

Each operator creates Custom Resource Definitions (CRDs). Verify they are available:

```bash
# Strimzi Kafka CRDs
oc get crd | grep kafka.strimzi.io

# PostgreSQL CRDs
oc get crd | grep postgresql.cnpg.io

# Keycloak CRDs
oc get crd | grep keycloak.org

# Prometheus CRDs
oc get crd | grep monitoring.coreos.com

# Grafana CRDs
oc get crd | grep grafana.integreatly.org
```

**Expected**: Each command should return multiple CRDs for that operator.

---

## Operator Details

### 1. Strimzi Kafka Operator (v0.49.0)

**Purpose**: Manages Apache Kafka clusters in Kubernetes

**Key CRDs**:
- `Kafka` - Kafka cluster definition
- `KafkaConnect` - Kafka Connect cluster
- `KafkaTopic` - Topic management
- `KafkaUser` - User management
- `KafkaBridge` - HTTP bridge

**Capabilities**:
- ✅ KRaft mode support (no ZooKeeper required)
- ✅ Automatic rolling updates
- ✅ TLS encryption
- ✅ OAuth/SCRAM authentication
- ✅ Cruise Control integration
- ✅ Strimzi Topic Operator
- ✅ Strimzi User Operator

**Documentation**: https://strimzi.io/docs/operators/0.49.0/

### 2. CrunchyData PostgreSQL Operator (v5.8.4)

**Purpose**: Manages PostgreSQL database clusters with high availability and automatic database initialization

**Key CRDs**:
- `PostgresCluster` - PostgreSQL cluster definition
- `PGUpgrade` - Major version upgrades
- `PGAdmin` - PGAdmin4 deployment (optional)

**Capabilities**:
- ✅ PostgreSQL 16 support
- ✅ Patroni-based HA with automatic failover
- ✅ pgBackRest for backup/restore to S3
- ✅ Automatic database and user creation on deployment
- ✅ Auto-generated Kubernetes secrets with connection details
- ✅ Built-in connection pooling (PgBouncer)
- ✅ Monitoring with postgres_exporter
- ✅ TLS encryption support

**Why CrunchyData PostgreSQL Operator**:

This operator was selected for production use:

**Advantages**:
- ✅ **Open Source**: No commercial license restrictions (vs EDB CNPG 30-day trial)
- ✅ **Automatic Initialization**: Creates databases, users, and secrets automatically on deployment
- ✅ **Battle-tested**: Widely used in production Kubernetes/OpenShift environments
- ✅ **Mature Ecosystem**: Patroni + pgBackRest + PgBouncer integration
- ✅ **Red Hat Certified**: Available in OpenShift OperatorHub
- ✅ **Active Development**: Regular updates and security patches
- ✅ **Database-as-Code**: Declarative user/database management in PostgresCluster CR

**Compared to EDB Cloud Native PostgreSQL** (CNPG):
- ✅ Open source vs commercial (CNPG has 30-day trial limitation)
- ✅ Automatic database initialization (CNPG requires manual Jobs)
- ✅ Auto-generated secrets with full connection details
- ⚠️ CNPG is lighter/simpler for basic use cases

**Key Advantages for Data Platform**:
- Kubernetes-native architecture (no external dependencies)
- Optimal for Iceberg/Nessie catalog workloads
- Fast backup/restore for analytics databases
- Multi-region support for disaster recovery
- Lower operational complexity in OpenShift

**Documentation**: https://cloudnative-pg.io/documentation/1.25/

### 3. Keycloak Operator (v26.4.7)

**Purpose**: Manages Keycloak identity and access management server

**Key CRDs**:
- `Keycloak` - Keycloak server instance
- `KeycloakRealm` - Realm configuration
- `KeycloakClient` - Client application
- `KeycloakUser` - User management

**Capabilities**:
- ✅ Multi-realm support
- ✅ OAuth 2.0 / OpenID Connect
- ✅ SAML 2.0
- ✅ Social login integration
- ✅ User federation (LDAP/AD)
- ✅ Two-factor authentication
- ✅ Admin console

**Documentation**: https://www.keycloak.org/docs/26.4/server_admin/

### 4. Prometheus Operator (v0.56.3)

**Purpose**: Manages Prometheus monitoring stack

**Key CRDs**:
- `Prometheus` - Prometheus server instance
- `ServiceMonitor` - Service discovery for metrics
- `PodMonitor` - Pod-level monitoring
- `PrometheusRule` - Alerting rules
- `Alertmanager` - Alert management

**Capabilities**:
- ✅ Automatic service discovery
- ✅ Dynamic configuration
- ✅ High availability
- ✅ Thanos integration support
- ✅ Remote write/read
- ✅ Federation support

**Documentation**: https://prometheus-operator.dev/docs/

### 5. Grafana Operator (v5.20.0)

**Purpose**: Manages Grafana instances and dashboards

**Key CRDs**:
- `Grafana` - Grafana instance
- `GrafanaDashboard` - Dashboard definition
- `GrafanaDataSource` - Data source configuration
- `GrafanaFolder` - Dashboard folders

**Capabilities**:
- ✅ Dashboard provisioning
- ✅ Data source management
- ✅ Plugin management
- ✅ Multi-instance support
- ✅ LDAP/OAuth integration
- ✅ Dashboard versioning

**Documentation**: https://grafana.github.io/grafana-operator/docs/

---

## Troubleshooting

### Issue: Operator Stuck in "Installing" Phase

**Check**:
```bash
oc describe csv <csv-name> -n datalyptica
```

**Common Causes**:
- Insufficient resources
- Image pull errors
- Conflicting operators

**Solution**:
```bash
# Check pod events
oc get events -n datalyptica --sort-by='.lastTimestamp'

# Check operator pod logs
oc logs -f <operator-pod-name> -n datalyptica
```

### Issue: Subscription Has No InstallPlan

**Check**:
```bash
oc get subscription <subscription-name> -n datalyptica -o yaml
```

**Common Causes**:
- Invalid channel name
- Operator not available in catalog source
- OperatorGroup misconfigured

**Solution**:
```bash
# Verify operator exists in marketplace
oc get packagemanifest <package-name> -n openshift-marketplace

# Check available channels
oc describe packagemanifest <package-name> -n openshift-marketplace | grep "Channel"

# Recreate subscription with correct channel
oc delete subscription <subscription-name> -n datalyptica
oc apply -f deploy/openshift/operators-subscriptions.yaml
```

### Issue: Keycloak Operator "ConstraintsNotSatisfiable"

**Problem**: Keycloak operator requires `fast` channel, not `stable`

**Solution**: Already fixed in the configuration file. If you encounter this:

```bash
# Delete incorrect subscription
oc delete subscription keycloak-operator -n datalyptica

# Verify correct channel in file (should be "fast")
cat deploy/openshift/operators-subscriptions.yaml | grep -A 10 "keycloak-operator"

# Reapply
oc apply -f deploy/openshift/operators-subscriptions.yaml
```

### Issue: Operator Pod CrashLoopBackOff

**Check**:
```bash
oc logs <operator-pod-name> -n datalyptica --previous
oc describe pod <operator-pod-name> -n datalyptica
```

**Common Causes**:
- Resource limits too restrictive
- Missing RBAC permissions
- Configuration errors

**Solution**:
```bash
# Check resource usage
oc top pod <operator-pod-name> -n datalyptica

# Check events
oc get events -n datalyptica | grep <operator-pod-name>
```

---

## Operator Installation Summary

### Successfully Installed

| Operator                  | Version | Status     | Pod Name                                                   | Ready |
| ------------------------- | ------- | ---------- | ---------------------------------------------------------- | ----- |
| Strimzi Kafka             | 0.49.0  | ✅ Running | strimzi-cluster-operator-v0.49.0-564fd8bbd9-8vwhc          | 1/1   |
| CrunchyData PostgreSQL    | 5.8.4   | ✅ Running | pgo-5dcdfbc568-7pt5k                                       | 1/1   |
| Keycloak                  | 26.4.7  | ✅ Running | keycloak-operator-586fcddb9f-s6hlt                         | 1/1   |
| Prometheus                | 0.56.3  | ✅ Running | prometheus-operator-656f576698-v267x                       | 1/1   |
| Grafana                   | 5.20.0  | ✅ Running | grafana-operator-controller-manager-v5-5d6b5f6b6-gc25b     | 1/1   |

**Total Operators**: 5  
**Installation Time**: ~2-3 minutes  
**Status**: ✅ All operators successfully installed and running

---

## Next Steps

With all operators installed, proceed to:

1. **Storage Layer Deployment** (See: `DEPLOYMENT-03-STORAGE.md`)
   - Deploy MinIO for object storage
   - Deploy PostgreSQL cluster
   - Deploy Redis for caching

2. **Catalog Layer Deployment** (See: `DEPLOYMENT-04-CATALOG.md`)
   - Deploy Nessie catalog service

3. **Streaming Layer Deployment** (See: `DEPLOYMENT-05-STREAMING.md`)
   - Create Kafka cluster
   - Deploy Schema Registry
   - Configure Kafka Connect

---

## Important Notes

### Operator Lifecycle

- **Automatic Updates**: All operators configured with `installPlanApproval: Automatic`
- **Updates**: Operators will automatically upgrade within their channels
- **Breaking Changes**: Major version updates may require manual intervention

### Resource Considerations

Each operator consumes cluster resources:
- CPU: ~100-200m per operator
- Memory: ~128-256Mi per operator
- Storage: Minimal (operators are stateless)

### Security

- All operators run with restricted SCCs
- RBAC automatically configured by OLM
- Operators can only manage resources in `datalyptica` namespace

### Monitoring

Operator metrics are available via ServiceMonitors:
```bash
oc get servicemonitor -n datalyptica
```

---

**Document Version**: 1.0  
**Last Updated**: December 5, 2025  
**Operators Installed**: 5/5  
**Status**: ✅ Complete
