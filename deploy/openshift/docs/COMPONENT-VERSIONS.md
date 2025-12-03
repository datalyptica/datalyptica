# Datalyptica OpenShift - Component Versions

**Last Updated:** December 3, 2025  
**Platform:** Red Hat OpenShift 4.17+ / Kubernetes 1.30+

---

## Platform Requirements

| Component | Version | Release Date | Notes |
|-----------|---------|--------------|-------|
| **Red Hat OpenShift** | 4.17+ | Nov 2025 | Latest stable release |
| **Kubernetes** | 1.30+ | Apr 2025 | For vanilla K8s deployments |
| **OKD** | 4.17+ | Nov 2025 | Community distribution |

---

## Operators (from OperatorHub)

| Operator | Version | Image | Purpose |
|----------|---------|-------|---------|
| **Strimzi Kafka Operator** | 0.43+ | quay.io/strimzi/operator:0.43.0 | Kafka cluster management with KRaft support |
| **Crunchy PostgreSQL Operator** | 5.7+ | registry.crunchydata.com/crunchydata/postgres-operator:ubi8-5.7.1-0 | PostgreSQL HA with streaming replication |
| **ClickHouse Operator** | 0.24+ | altinity/clickhouse-operator:0.24.0 | ClickHouse cluster management |
| **Spark Operator** | 2.0+ | spark-operator/spark-operator:v2.0.1 | Spark on Kubernetes |
| **Flink Kubernetes Operator** | 1.10+ | apache/flink-kubernetes-operator:1.10.0 | Flink application lifecycle |
| **Keycloak Operator** | 26+ | quay.io/keycloak/keycloak-operator:26.0.7 | Identity and access management |
| **Redis Operator** | 0.18+ | quay.io/spotahome/redis-operator:0.18.0 | Redis cluster management |
| **Prometheus Operator** | 0.78+ | quay.io/prometheus-operator/prometheus-operator:v0.78.1 | Monitoring (built-in to OpenShift) |
| **Grafana Operator** | 5.14+ | ghcr.io/grafana/grafana-operator:v5.14.1 | Dashboards and visualization |
| **Loki Operator** | 6.2+ | docker.io/grafana/loki-operator:v6.2.0 | Log aggregation |

---

## Data Platform Components

### Catalog & Metadata

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **PostgreSQL** | 16.6 | registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-16.6-0 | Primary metadata store |
| **Nessie** | 0.98.2 | ghcr.io/projectnessie/nessie:0.98.2 | Git-like data catalog for Iceberg |
| **Redis** | 7.4.1 | redis:7.4.1-alpine | Caching and session management |
| **etcd** | 3.5.16 | quay.io/coreos/etcd:v3.5.16 | Distributed key-value store (built-in to OpenShift) |

### Streaming Platform

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **Kafka** | 3.9.0 | quay.io/strimzi/kafka:0.43.0-kafka-3.9.0 | Event streaming (KRaft mode, no Zookeeper!) |
| **Schema Registry** | 7.8.0 | confluentinc/cp-schema-registry:7.8.0 | Avro/JSON schema management |
| **Kafka Connect** | 3.9.0 | quay.io/strimzi/kafka:0.43.0-kafka-3.9.0 | Change data capture connectors |

### Processing Engines

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **Apache Spark** | 3.5.4 | apache/spark:3.5.4 | Batch and streaming processing |
| **Apache Iceberg** | 1.7.1 | (bundled with Spark) | Table format for data lakehouse |
| **Apache Flink** | 1.20.0 | apache/flink:1.20.0 | Stream processing engine |

### Query Engines

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **Trino** | 469 | trinodb/trino:469 | Distributed SQL query engine |
| **ClickHouse** | 24.12.2.59 | clickhouse/clickhouse-server:24.12.2.59 | OLAP database for analytics |

### Analytics & ML

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **Apache Airflow** | 2.10.4 | apache/airflow:2.10.4 | Workflow orchestration |
| **JupyterHub** | 5.2.1 | jupyterhub/k8s-hub:5.2.1 | Multi-user notebook server |
| **MLflow** | 2.19.0 | ghcr.io/mlflow/mlflow:v2.19.0 | ML experiment tracking |
| **Apache Superset** | 4.1.1 | apache/superset:4.1.1 | Business intelligence platform |
| **dbt-core** | 1.9.0 | ghcr.io/dbt-labs/dbt-core:1.9.0 | Data transformation tool |

### Identity & Access Management

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **Keycloak** | 26.0.7 | quay.io/keycloak/keycloak:26.0.7 | SSO and identity provider |
| **OpenLDAP** | 1.5.0 | osixia/openldap:1.5.0 | Optional: LDAP directory service |

### Monitoring & Observability

| Component | Version | Image | Notes |
|-----------|---------|-------|-------|
| **Prometheus** | 3.0.1 | quay.io/prometheus/prometheus:v3.0.1 | Metrics collection and storage |
| **Grafana** | 11.4.0 | grafana/grafana:11.4.0 | Metrics visualization |
| **Loki** | 3.3.2 | grafana/loki:3.3.2 | Log aggregation system |
| **Promtail** | 3.3.2 | grafana/promtail:3.3.2 | Log shipper for Loki |
| **Alloy** | 1.5.1 | grafana/alloy:v1.5.1 | OpenTelemetry collector |
| **Alertmanager** | 0.27.0 | quay.io/prometheus/alertmanager:v0.27.0 | Alert routing and management |
| **Jaeger** | 1.63.0 | jaegertracing/all-in-one:1.63.0 | Distributed tracing |

---

## Helm Charts

| Chart | Repository | Version | Notes |
|-------|-----------|---------|-------|
| **Apache Airflow** | https://airflow.apache.org | 1.16.0 | Chart version for Airflow 2.10.4 |
| **JupyterHub** | https://hub.jupyter.org/helm-chart/ | 4.0.0 | Chart version for JupyterHub 5.2.1 |
| **Prometheus Stack** | https://prometheus-community.github.io/helm-charts | 66.3.0 | kube-prometheus-stack |
| **Grafana** | https://grafana.github.io/helm-charts | 8.8.2 | Standalone Grafana chart |
| **Loki Stack** | https://grafana.github.io/helm-charts | 2.10.2 | Loki + Promtail bundle |

---

## Container Registry Locations

### Official Registries

```yaml
Quay.io (Red Hat):
  - quay.io/strimzi/*
  - quay.io/prometheus/*
  - quay.io/coreos/*
  - quay.io/keycloak/*

GitHub Container Registry:
  - ghcr.io/projectnessie/*
  - ghcr.io/mlflow/*
  - ghcr.io/dbt-labs/*
  - ghcr.io/grafana/*

Docker Hub:
  - apache/*
  - trinodb/*
  - grafana/*
  - redis:*
  - confluentinc/*

Crunchy Data Registry:
  - registry.crunchydata.com/crunchydata/*
```

---

## Python Dependencies (for Custom Images)

### Spark with Iceberg

```dockerfile
FROM apache/spark:3.5.4

# Iceberg dependencies
ENV ICEBERG_VERSION=1.7.1
ENV NESSIE_VERSION=0.98.2

RUN curl -L https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar \
    -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar

RUN curl -L https://repo1.maven.org/maven2/org/projectnessie/nessie-integrations/nessie-spark-extensions-3.5_2.12/${NESSIE_VERSION}/nessie-spark-extensions-3.5_2.12-${NESSIE_VERSION}.jar \
    -o /opt/spark/jars/nessie-spark-extensions-3.5_2.12-${NESSIE_VERSION}.jar
```

### Airflow with Custom Providers

```dockerfile
FROM apache/airflow:2.10.4

RUN pip install --no-cache-dir \
    apache-airflow-providers-apache-spark==4.10.2 \
    apache-airflow-providers-apache-kafka==1.6.0 \
    apache-airflow-providers-postgres==5.13.2 \
    apache-airflow-providers-amazon==8.31.0 \
    apache-airflow-providers-trino==5.8.1 \
    apache-airflow-providers-jdbc==4.6.1 \
    great-expectations==1.2.3 \
    pyiceberg[s3fs,pyarrow]==0.8.1
```

---

## Version Compatibility Matrix

### Spark + Iceberg + Nessie

| Spark | Scala | Iceberg | Nessie | Compatible |
|-------|-------|---------|--------|------------|
| 3.5.4 | 2.12 | 1.7.1 | 0.98.2 | ✅ Yes |
| 3.5.4 | 2.13 | 1.7.1 | 0.98.2 | ✅ Yes |
| 3.4.x | 2.12 | 1.7.1 | 0.98.2 | ⚠️ Limited |

### Kafka + Flink

| Kafka | Flink | Connector | Compatible |
|-------|-------|-----------|------------|
| 3.9.0 | 1.20.0 | 3.3.0 | ✅ Yes |
| 3.9.0 | 1.19.x | 3.2.0 | ✅ Yes |

### Trino + Iceberg

| Trino | Iceberg | Compatible |
|-------|---------|------------|
| 469 | 1.7.1 | ✅ Yes |
| 469 | 1.6.x | ✅ Yes |

---

## Java/JVM Versions

| Component | JDK Version | Notes |
|-----------|-------------|-------|
| **Kafka** | OpenJDK 21 | Amazon Corretto recommended |
| **Spark** | OpenJDK 17 | LTS version |
| **Flink** | OpenJDK 17 | LTS version |
| **Trino** | OpenJDK 23 | Latest Trino requires Java 23+ |
| **Nessie** | OpenJDK 21 | Built with Quarkus |
| **Airflow** | Python 3.12 | Not Java-based |

---

## Python Versions

| Component | Python Version | Notes |
|-----------|---------------|-------|
| **Airflow** | 3.12 | Latest stable |
| **JupyterHub** | 3.11+ | Supports multiple kernels |
| **MLflow** | 3.11+ | Scikit-learn, TensorFlow, PyTorch |
| **Superset** | 3.11+ | Flask-based application |
| **dbt** | 3.11+ | Data transformation |

---

## Important Version Notes

### Breaking Changes

1. **Kafka 3.9.0**
   - KRaft mode is now production-ready
   - Zookeeper is deprecated (removal planned for 4.0)
   - New consumer group protocol improvements

2. **Spark 3.5.4**
   - Better Iceberg integration
   - Improved Kubernetes support
   - Requires Java 17+

3. **Trino 469**
   - **Requires Java 23+** (major change from Java 17)
   - Improved fault-tolerant execution
   - Better memory management

4. **PostgreSQL 16.6**
   - Logical replication improvements
   - Better query parallelism
   - JSON performance enhancements

5. **Keycloak 26**
   - New admin console (React-based)
   - Improved OAuth2/OIDC flows
   - Better performance for large user bases

### Upcoming Changes (Q1 2026)

- **Kafka 4.0** - Zookeeper removal complete
- **Spark 4.0** - Connect API for streaming
- **Flink 2.0** - Unified batch/streaming API
- **OpenShift 4.18** - Enhanced AI/ML capabilities

---

## Version Verification Commands

### Check Operator Versions

```bash
# Strimzi Kafka Operator
oc get csv -n openshift-operators | grep strimzi

# Crunchy PostgreSQL Operator
oc get csv -n openshift-operators | grep postgres-operator

# Check all installed operators
oc get operators
```

### Check Deployed Component Versions

```bash
# Kafka version
oc get kafka datalyptica-kafka -n datalyptica-streaming -o jsonpath='{.spec.kafka.version}'

# PostgreSQL version
oc get postgrescluster datalyptica-postgres -n datalyptica-catalog -o jsonpath='{.spec.postgresVersion}'

# Nessie version
oc get deployment nessie -n datalyptica-catalog -o jsonpath='{.spec.template.spec.containers[0].image}'

# Trino version
oc get deployment trino-coordinator -n datalyptica-query -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Update Strategy

### Minor Version Updates

For minor/patch updates (e.g., 3.5.3 → 3.5.4):

```bash
# Update via operator (Kafka example)
oc patch kafka datalyptica-kafka -n datalyptica-streaming \
  --type=merge -p '{"spec":{"kafka":{"version":"3.9.0"}}}'

# Operator handles rolling update automatically
```

### Major Version Updates

For major updates (e.g., Spark 3.5 → 4.0):

1. Review breaking changes in release notes
2. Test in dev/staging environment
3. Update custom Docker images
4. Plan maintenance window
5. Update via GitOps (ArgoCD/Flux)
6. Validate functionality

---

## Support & Documentation

| Component | Documentation | Support |
|-----------|--------------|---------|
| **OpenShift** | https://docs.openshift.com | Red Hat Support Portal |
| **Kafka/Strimzi** | https://strimzi.io/docs | Community + CNCF |
| **PostgreSQL/Crunchy** | https://access.crunchydata.com/documentation | Crunchy Data Support |
| **Nessie** | https://projectnessie.org/docs | Project Nessie Community |
| **Trino** | https://trino.io/docs/current | Starburst Enterprise (optional) |
| **Spark** | https://spark.apache.org/docs/latest | Databricks (optional) |
| **Flink** | https://nightlies.apache.org/flink/flink-docs-release-1.20 | Ververica Platform (optional) |

---

## License Information

| Component | License | Commercial Support Available |
|-----------|---------|------------------------------|
| **OpenShift** | Proprietary (Red Hat) | ✅ Red Hat |
| **Kafka** | Apache 2.0 | ✅ Confluent, Red Hat |
| **PostgreSQL** | PostgreSQL License | ✅ Crunchy Data, EDB |
| **Nessie** | Apache 2.0 | ✅ Dremio |
| **Trino** | Apache 2.0 | ✅ Starburst |
| **Spark** | Apache 2.0 | ✅ Databricks |
| **Flink** | Apache 2.0 | ✅ Ververica |
| **ClickHouse** | Apache 2.0 | ✅ ClickHouse Inc |
| **Airflow** | Apache 2.0 | ✅ Astronomer |

---

**Last Verified:** December 3, 2025  
**Next Review:** March 3, 2026
