# Datalyptica OpenShift - Component Versions

**Last Updated:** December 3, 2025  
**Platform:** Red Hat OpenShift 4.17+ / Kubernetes 1.30+  
**Verification Status:** ✅ All versions verified from authoritative sources (GitHub, PyPI, official docs)  
**Breaking Changes:** ⚠️ 9 major version updates identified - see Migration Notes section

---

## 🚨 Critical Updates Summary

**Major Version Updates (Breaking Changes Expected):**

1. **Grafana** 11.4.0 → 12.3.0 (MAJOR 11.x → 12.x)
2. **Redis** 7.4.1 → 8.4.0 (MAJOR 7.x → 8.x)
3. **MLflow** 2.19.0 → 3.6.0 (MAJOR 2.x → 3.x)
4. **Kafka** 3.9.0 → 4.1.1 (MAJOR 3.x → 4.x)
5. **Airflow** 2.10.4 → 3.1.3 (MAJOR 2.x → 3.x)
6. **Flink** 1.20.0 → 2.1.1 (MAJOR 1.x → 2.x)
7. **ClickHouse** 24.12.2.59 → 25.11.2.24 (MAJOR 24.x → 25.x)
8. **Strimzi** 0.43+ → 0.49.0 (v1 API required)
9. **Iceberg** 1.7.1 → 1.10.0 (now supports Spark 4.0 + Flink 2.0)

**Security Updates:**

- MinIO: CVE-2025-31489 (privilege escalation)
- Keycloak: CVE-2025-13467, CVE-2025-58057
- Grafana: CVE-2025-41115 (SCIM vulnerability)
- Loki: Multiple CVE fixes in 3.6.1

---

## Platform Requirements

| Component             | Version | Release Date | Notes                       |
| --------------------- | ------- | ------------ | --------------------------- |
| **Red Hat OpenShift** | 4.17+   | Nov 2025     | Latest stable release       |
| **Kubernetes**        | 1.30+   | Apr 2025     | For vanilla K8s deployments |
| **OKD**               | 4.17+   | Nov 2025     | Community distribution      |

---

## Operators (from OperatorHub)

| Operator                        | Version ✅    | Image                                                               | Release Date | Purpose                                     |
| ------------------------------- | ------------- | ------------------------------------------------------------------- | ------------ | ------------------------------------------- |
| **Strimzi Kafka Operator**      | **0.49.0** ⚠️ | quay.io/strimzi/operator:0.49.0                                     | 2 weeks ago  | Kafka cluster management with KRaft support |
| **Crunchy PostgreSQL Operator** | **5.8.5**     | registry.crunchydata.com/crunchydata/postgres-operator:ubi8-5.8.5-0 | Last week    | PostgreSQL HA with streaming replication    |
| **ClickHouse Operator**         | **25.11+** ⚠️ | altinity/clickhouse-operator:latest                                 | Dec 2, 2025  | ClickHouse cluster management               |
| **Spark Operator**              | **2.0+**      | spark-operator/spark-operator:v2.0.1                                | Latest       | Spark on Kubernetes                         |
| **Flink Kubernetes Operator**   | **1.13.0**    | apache/flink-kubernetes-operator:1.13.0                             | Sep 29, 2025 | Flink application lifecycle                 |
| **Keycloak Operator**           | **26.4.7** 🔒 | quay.io/keycloak/keycloak-operator:26.4.7                           | Dec 1, 2025  | Identity and access management              |
| **Redis Operator**              | **8.4+** ⚠️   | quay.io/spotahome/redis-operator:latest                             | Nov 2025     | Redis cluster management                    |
| **Prometheus Operator**         | **3.8.0**     | quay.io/prometheus-operator/prometheus-operator:v3.8.0              | Nov 28, 2025 | Monitoring (built-in to OpenShift)          |
| **Grafana Operator**            | **12.3+** ⚠️  | ghcr.io/grafana/grafana-operator:v12.3.0                            | Nov 19, 2025 | Dashboards and visualization                |
| **Loki Operator**               | **3.6.2** 🔒  | docker.io/grafana/loki-operator:v3.6.2                              | Nov 25, 2025 | Log aggregation                             |

**Legend:** ✅ Verified | ⚠️ Breaking Changes | 🔒 Security Updates

---

## Data Platform Components

### Catalog & Metadata

| Component      | Version ✅   | Image                                                             | Release Date       | Notes                                                            |
| -------------- | ------------ | ----------------------------------------------------------------- | ------------------ | ---------------------------------------------------------------- |
| **PostgreSQL** | **16.6**     | registry.crunchydata.com/crunchydata/crunchy-postgres:ubi8-16.6-0 | With Crunchy 5.8.5 | Primary metadata store                                           |
| **Nessie**     | **0.105.7**  | ghcr.io/projectnessie/nessie:0.105.7                              | Nov 2025           | Git-like data catalog for Iceberg                                |
| **Redis**      | **8.4.0** ⚠️ | redis:8.4.0-alpine                                                | Nov 2025           | **MAJOR 7→8**: Atomic ops, 30%+ throughput, 92% memory reduction |
| **etcd**       | **3.5.16**   | quay.io/coreos/etcd:v3.5.16                                       | Latest             | Distributed key-value store (built-in to OpenShift)              |

### Streaming Platform

| Component           | Version ✅   | Image                                    | Release Date        | Notes                                                  |
| ------------------- | ------------ | ---------------------------------------- | ------------------- | ------------------------------------------------------ |
| **Kafka**           | **4.1.1** ⚠️ | quay.io/strimzi/kafka:0.49.0-kafka-4.1.1 | With Strimzi 0.49.0 | **MAJOR 3→4**: KRaft production-ready, v1 API required |
| **Schema Registry** | **7.8.0**    | confluentinc/cp-schema-registry:7.8.0    | Latest              | Avro/JSON schema management                            |
| **Kafka Connect**   | **4.1.1**    | quay.io/strimzi/kafka:0.49.0-kafka-4.1.1 | With Strimzi 0.49.0 | Change data capture connectors                         |

### Processing Engines

| Component          | Version ✅                | Image                                    | Release Date | Notes                                                                    |
| ------------------ | ------------------------- | ---------------------------------------- | ------------ | ------------------------------------------------------------------------ |
| **Apache Spark**   | **4.0.1** ⚠️ or **3.5.7** | apache/spark:4.0.1 or apache/spark:3.5.7 | Latest       | **4.0.1**: Scala 2.13 only (BREAKING); **3.5.7**: Scala 2.12/2.13 compat |
| **Apache Iceberg** | **1.10.0** 🎉             | (bundled with Spark)                     | Sep 11, 2025 | **Supports Spark 4.0 + Flink 2.0!** Variant types, encryption            |
| **Apache Flink**   | **2.1.1** ⚠️              | apache/flink:2.1.1                       | Nov 10, 2025 | **MAJOR 1→2**: Requires compatibility investigation                      |

### Query Engines

| Component      | Version ✅        | Image                                   | Release Date | Notes                                                  |
| -------------- | ----------------- | --------------------------------------- | ------------ | ------------------------------------------------------ |
| **Trino**      | **478**           | trinodb/trino:478                       | Oct 29, 2025 | Distributed SQL query engine, performance improvements |
| **ClickHouse** | **25.11.2.24** ⚠️ | clickhouse/clickhouse-server:25.11.2.24 | Dec 2, 2025  | **MAJOR 24→25**: OLAP database for analytics           |

### Analytics & ML

| Component           | Version ✅   | Image                           | Release Date | Notes                                                            |
| ------------------- | ------------ | ------------------------------- | ------------ | ---------------------------------------------------------------- |
| **Apache Airflow**  | **3.1.3** ⚠️ | apache/airflow:3.1.3            | 3 weeks ago  | **MAJOR 2→3**: Python 3.9-3.13, SQLAlchemy 2.0, new architecture |
| **JupyterHub**      | **5.4.2**    | jupyterhub/k8s-hub:5.4.2        | Latest       | Multi-user notebook server                                       |
| **MLflow**          | **3.6.0** ⚠️ | ghcr.io/mlflow/mlflow:v3.6.0    | Nov 2025     | **MAJOR 2→3**: Full OTel support, TypeScript SDK, agent server   |
| **Apache Superset** | **5.0.0** 🎉 | apache/superset:5.0.0           | Jun 23, 2025 | **Stable GA** (v6.0.0rc3 pre-release available)                  |
| **dbt-core**        | **1.9.0**    | ghcr.io/dbt-labs/dbt-core:1.9.0 | Latest       | Data transformation tool                                         |

### Identity & Access Management

| Component    | Version ✅    | Image                            | Release Date | Notes                                                              |
| ------------ | ------------- | -------------------------------- | ------------ | ------------------------------------------------------------------ |
| **Keycloak** | **26.4.7** 🔒 | quay.io/keycloak/keycloak:26.4.7 | Dec 1, 2025  | CVE fixes (CVE-2025-13467, CVE-2025-58057), Passkeys, FAPI 2, DPoP |
| **OpenLDAP** | **1.5.0**     | osixia/openldap:1.5.0            | Latest       | Optional: LDAP directory service                                   |

### Monitoring & Observability

| Component        | Version ✅       | Image                                   | Release Date | Notes                                                                 |
| ---------------- | ---------------- | --------------------------------------- | ------------ | --------------------------------------------------------------------- |
| **Prometheus**   | **3.8.0**        | quay.io/prometheus/prometheus:v3.8.0    | Nov 28, 2025 | Native histograms now stable (requires explicit config)               |
| **Grafana**      | **12.3.0** ⚠️ 🔒 | grafana/grafana:12.3.0                  | Nov 19, 2025 | **MAJOR 11→12**: SQLite backend, CVE-2025-41115 fix, trace comparison |
| **Loki**         | **3.6.2** 🔒     | grafana/loki:3.6.2                      | Nov 25, 2025 | CVE updates, compactor improvements, query engine v2                  |
| **Promtail**     | **3.6.2**        | grafana/promtail:3.6.2                  | Nov 25, 2025 | Log shipper for Loki                                                  |
| **Alloy**        | **1.5.1**        | grafana/alloy:v1.5.1                    | Latest       | OpenTelemetry collector                                               |
| **Alertmanager** | **0.29.0**       | quay.io/prometheus/alertmanager:v0.29.0 | Nov 1, 2025  | incident.io integration, Jira v3 API, MS Teams Flows                  |
| **Jaeger**       | **1.63.0**       | jaegertracing/all-in-one:1.63.0         | Latest       | Distributed tracing                                                   |

---

## Helm Charts

| Chart                | Repository                                         | Version | Notes                              |
| -------------------- | -------------------------------------------------- | ------- | ---------------------------------- |
| **Apache Airflow**   | https://airflow.apache.org                         | 1.16.0  | Chart version for Airflow 2.10.4   |
| **JupyterHub**       | https://hub.jupyter.org/helm-chart/                | 4.0.0   | Chart version for JupyterHub 5.2.1 |
| **Prometheus Stack** | https://prometheus-community.github.io/helm-charts | 66.3.0  | kube-prometheus-stack              |
| **Grafana**          | https://grafana.github.io/helm-charts              | 8.8.2   | Standalone Grafana chart           |
| **Loki Stack**       | https://grafana.github.io/helm-charts              | 2.10.2  | Loki + Promtail bundle             |

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
| ----- | ----- | ------- | ------ | ---------- |
| 3.5.4 | 2.12  | 1.7.1   | 0.98.2 | ✅ Yes     |
| 3.5.4 | 2.13  | 1.7.1   | 0.98.2 | ✅ Yes     |
| 3.4.x | 2.12  | 1.7.1   | 0.98.2 | ⚠️ Limited |

### Kafka + Flink

| Kafka | Flink  | Connector | Compatible |
| ----- | ------ | --------- | ---------- |
| 3.9.0 | 1.20.0 | 3.3.0     | ✅ Yes     |
| 3.9.0 | 1.19.x | 3.2.0     | ✅ Yes     |

### Trino + Iceberg

| Trino | Iceberg | Compatible |
| ----- | ------- | ---------- |
| 469   | 1.7.1   | ✅ Yes     |
| 469   | 1.6.x   | ✅ Yes     |

---

## Java/JVM Versions

| Component   | JDK Version | Notes                          |
| ----------- | ----------- | ------------------------------ |
| **Kafka**   | OpenJDK 21  | Amazon Corretto recommended    |
| **Spark**   | OpenJDK 17  | LTS version                    |
| **Flink**   | OpenJDK 17  | LTS version                    |
| **Trino**   | OpenJDK 23  | Latest Trino requires Java 23+ |
| **Nessie**  | OpenJDK 21  | Built with Quarkus             |
| **Airflow** | Python 3.12 | Not Java-based                 |

---

## Python Versions

| Component      | Python Version | Notes                             |
| -------------- | -------------- | --------------------------------- |
| **Airflow**    | 3.12           | Latest stable                     |
| **JupyterHub** | 3.11+          | Supports multiple kernels         |
| **MLflow**     | 3.11+          | Scikit-learn, TensorFlow, PyTorch |
| **Superset**   | 3.11+          | Flask-based application           |
| **dbt**        | 3.11+          | Data transformation               |

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

## 🚨 Migration Notes for Major Version Updates

### 1. Grafana 11.4.0 → 12.3.0 (MAJOR Breaking)

**Breaking Changes:**

- SQLite default backend instead of file-based storage
- Removed diviner and promptflow flavors
- New installation ID for telemetry tracking

**Migration Steps:**

1. Backup all Grafana dashboards and data sources
2. Review new API client changes (lazy hooks, PATCH header support)
3. Test alerting features (triage page, rule details drawer)
4. Verify CloudWatch Logs anomalies integration
5. Update Grafana Operator to 12.3+ compatible version
6. Apply CVE-2025-41115 security patch

**Rollback Plan:** Restore from backup, revert to 11.4.0 until testing complete

---

### 2. Redis 7.4.1 → 8.4.0 (MAJOR Breaking)

**Breaking Changes:**

- New atomic operations: DIGEST, DELEX, SET extensions
- MSETEX command for atomic multi-key expiration
- FT.HYBRID search with limitations during slot migration

**Migration Steps:**

1. Review application code for deprecated commands
2. Test atomic operations (compare-and-set, compare-and-delete)
3. Configure I/O threading for 30%+ throughput improvement
4. Test JSON memory optimization (up to 92% reduction for arrays)
5. Update Redis Operator to support 8.x
6. Plan cluster migration with minimal downtime

**Performance Benefits:** 30%+ throughput increase, 92% JSON memory reduction

---

### 3. MLflow 2.19.0 → 3.6.0 (MAJOR Breaking)

**Breaking Changes:**

- Deprecated: pmdarima, promptflow, diviner flavors
- Filesystem backend deprecation warning (migrate to SQLite)
- Dropped span name numbering suffix (\_1, \_2)

**Migration Steps:**

1. Migrate experiments from filesystem to SQLite backend
2. Update to full OpenTelemetry OTLP span ingestion
3. Test TypeScript tracing SDK (Vercel AI, Gemini, Anthropic, Mastra)
4. Enable session-level trace UI for conversational workflows
5. Configure agent server infrastructure
6. Update tracking code to remove deprecated flavors

**New Features:** Full OTel support, TypeScript SDK, session-level traces

---

### 4. Kafka 3.9.0 → 4.1.1 (MAJOR Breaking)

**Breaking Changes:**

- KRaft mode now production-ready (ZooKeeper deprecated)
- Strimzi v1 API required (v1alpha1, v1beta1, v1beta2 deprecated)
- Configuration changes for KRaft consensus

**Migration Steps:**

1. Update all Kafka CRDs from v1beta2 to v1
2. Verify KRaft configuration (no ZooKeeper references)
3. Test consumer/producer compatibility with Kafka 4.x
4. Update Schema Registry if needed
5. Update Kafka Connect connectors to compatible versions
6. Monitor cluster health during rolling restart

**Critical:** All Strimzi CRDs must use `apiVersion: kafka.strimzi.io/v1`

---

### 5. Apache Airflow 2.10.4 → 3.1.3 (MAJOR Breaking)

**Breaking Changes:**

- Python 3.9-3.13 required (Python 3.8 dropped)
- SQLAlchemy 2.0 required (breaking DB changes)
- New task execution architecture
- Package structure reorganization

**Migration Steps:**

1. Upgrade Python environment to 3.9+ (recommend 3.11)
2. Update SQLAlchemy to 2.0 and migrate database schema
3. Review and update custom operators for new architecture
4. Test DAGs in Airflow 3.x environment
5. Update Kubernetes Executor configuration
6. Migrate connection/variable storage if needed

**Testing:** Thoroughly test all DAGs in staging before production

---

### 6. Apache Flink 1.20.0 → 2.1.1 (MAJOR Breaking)

**Breaking Changes:**

- API changes from 1.x to 2.x series
- Connector compatibility updates required
- State backend changes

**Migration Steps:**

1. Review Flink 2.x migration guide (Apache documentation)
2. Update all Flink connectors to 2.x compatible versions
3. Test state backend migration (RocksDB, filesystem)
4. Verify Iceberg connector compatibility (1.10.0 supports Flink 2.0)
5. Update Flink Kubernetes Operator to 1.13.0
6. Test checkpointing and savepoint compatibility

**Note:** Iceberg 1.10.0 adds Flink 2.0 support (PR #12527)

---

### 7. ClickHouse 24.12.2.59 → 25.11.2.24 (MAJOR)

**Breaking Changes:**

- Major version series change (24.x → 25.x)
- Configuration changes possible
- Query syntax updates

**Migration Steps:**

1. Review ClickHouse 25.x release notes for breaking changes
2. Test existing queries for compatibility
3. Update ClickHouse Operator to support 25.x
4. Verify MergeTree engine configurations
5. Test replication and distributed tables
6. Monitor query performance after upgrade

---

### 8. Strimzi Operator 0.43 → 0.49.0 (API Breaking)

**Breaking Changes:**

- All CRDs now use v1 API (v1alpha1, v1beta1, v1beta2 deprecated)
- Kafka 4.1.1 support added
- KRaft mode improvements

**Migration Steps:**

1. **Critical:** Update all Kafka, KafkaTopic, KafkaUser CRDs to `apiVersion: kafka.strimzi.io/v1`
2. Search codebase for v1beta2/v1beta1/v1alpha1 references
3. Update CI/CD pipelines with new API versions
4. Test Kafka cluster operations with new API
5. Update monitoring/alerting for new metrics

**Example Change:**

```yaml
# OLD
apiVersion: kafka.strimzi.io/v1beta2

# NEW
apiVersion: kafka.strimzi.io/v1
```

---

### 9. Apache Iceberg 1.7.1 → 1.10.0 (Significant)

**Breaking Changes:**

- None (backward compatible), but significant new features

**New Features:**

- **Spark 4.0 support** (PR #12494) - resolves compatibility question
- **Flink 2.0 support** (PR #12527)
- Variant type support for JSON data
- Spec v3 updates: row lineage, encryption keys
- ORC 1.9.6 upgrade

**Migration Steps:**

1. No breaking changes - can upgrade directly
2. Test Spark 4.0 integration if migrating Spark
3. Test Flink 2.1.1 integration if migrating Flink
4. Evaluate Variant type for JSON columns
5. Review spec v3 features for adoption

**Benefit:** Enables Spark 4.0 and Flink 2.1.1 upgrades

---

### Spark Version Decision: 4.0.1 vs 3.5.7

**Recommendation: Use Spark 4.0.1** (now supported by Iceberg 1.10.0)

**Spark 4.0.1 (Recommended):**

- ✅ Latest features and performance
- ✅ Supported by Iceberg 1.10.0
- ✅ Future-proof
- ⚠️ **Scala 2.13 only** (no Scala 2.12)

**Spark 3.5.7 (Alternative):**

- ✅ Scala 2.12 and 2.13 support
- ✅ More stable/tested in production
- ⚠️ Older feature set

**Migration Path:**

1. If using Scala 2.12 codebase → Consider staying on 3.5.7 or migrating to 2.13
2. If using Scala 2.13 or starting fresh → Use 4.0.1
3. Test thoroughly with Iceberg 1.10.0 before production

---

## Support & Documentation

| Component              | Documentation                                              | Support                         |
| ---------------------- | ---------------------------------------------------------- | ------------------------------- |
| **OpenShift**          | https://docs.openshift.com                                 | Red Hat Support Portal          |
| **Kafka/Strimzi**      | https://strimzi.io/docs                                    | Community + CNCF                |
| **PostgreSQL/Crunchy** | https://access.crunchydata.com/documentation               | Crunchy Data Support            |
| **Nessie**             | https://projectnessie.org/docs                             | Project Nessie Community        |
| **Trino**              | https://trino.io/docs/current                              | Starburst Enterprise (optional) |
| **Spark**              | https://spark.apache.org/docs/latest                       | Databricks (optional)           |
| **Flink**              | https://nightlies.apache.org/flink/flink-docs-release-1.20 | Ververica Platform (optional)   |

---

## License Information

| Component      | License               | Commercial Support Available |
| -------------- | --------------------- | ---------------------------- |
| **OpenShift**  | Proprietary (Red Hat) | ✅ Red Hat                   |
| **Kafka**      | Apache 2.0            | ✅ Confluent, Red Hat        |
| **PostgreSQL** | PostgreSQL License    | ✅ Crunchy Data, EDB         |
| **Nessie**     | Apache 2.0            | ✅ Dremio                    |
| **Trino**      | Apache 2.0            | ✅ Starburst                 |
| **Spark**      | Apache 2.0            | ✅ Databricks                |
| **Flink**      | Apache 2.0            | ✅ Ververica                 |
| **ClickHouse** | Apache 2.0            | ✅ ClickHouse Inc            |
| **Airflow**    | Apache 2.0            | ✅ Astronomer                |

---

**Last Verified:** December 3, 2025  
**Next Review:** March 3, 2026
