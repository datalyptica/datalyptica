# Datalyptica OpenShift Deployment Architecture

**Version:** 3.0.0  
**Platform:** Red Hat OpenShift 4.14+ / Kubernetes 1.27+  
**Deployment Model:** Cloud-Native with Operators  
**Last Updated:** December 3, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Why OpenShift?](#why-openshift)
3. [Architecture Design](#architecture-design)
4. [Cluster Requirements](#cluster-requirements)
5. [Namespace Design](#namespace-design)
6. [Storage Strategy](#storage-strategy)
7. [Component Deployment](#component-deployment)
8. [High Availability](#high-availability)
9. [Security & RBAC](#security--rbac)
10. [Networking](#networking)
11. [Monitoring & Observability](#monitoring--observability)

---

## Overview

This architecture deploys the complete Datalyptica Data Platform on Red Hat OpenShift/Kubernetes using cloud-native patterns, operators, and Helm charts. It provides:

✅ **Native High Availability** - Built-in pod replication, auto-healing  
✅ **Enterprise Object Storage** - S3-compatible via CSI or external  
✅ **No Zookeeper** - Kafka in KRaft mode, Operator-managed  
✅ **Scalability** - Horizontal pod autoscaling  
✅ **GitOps Ready** - ArgoCD/Flux compatible  
✅ **Multi-tenancy** - Namespace isolation  
✅ **Observability** - Prometheus Operator, Grafana, Loki  

---

## Why OpenShift?

### Advantages Over VM Deployment

| Aspect | VM Deployment | OpenShift Deployment |
|--------|---------------|---------------------|
| **HA** | Manual setup (Patroni, Keepalived) | Built-in (ReplicaSets, StatefulSets) |
| **Scaling** | Manual VM provisioning | Automatic (HPA, VPA) |
| **Updates** | Manual rolling updates | Rolling updates via operators |
| **Resource Utilization** | Fixed allocation | Dynamic scheduling |
| **Recovery** | Manual intervention | Self-healing pods |
| **Deployment Time** | Days to weeks | Hours |
| **Complexity** | High (50 VMs to manage) | Lower (declarative configs) |
| **Cost** | Fixed (50 VMs always on) | Elastic (scale to zero capable) |
| **Monitoring** | Manual setup | Built-in (Prometheus Operator) |
| **Networking** | Manual VLANs, VIPs | Software-defined (CNI) |

### OpenShift-Specific Benefits

- **Integrated Registry** - Built-in container registry
- **Routes/Ingress** - Automatic load balancing and TLS
- **Operators** - Lifecycle management for complex apps
- **Security** - SCCs, network policies, pod security standards
- **Multi-cluster** - Advanced Cluster Management (ACM)
- **GitOps** - Built-in OpenShift GitOps (ArgoCD)
- **Service Mesh** - Red Hat Service Mesh (Istio)
- **Serverless** - OpenShift Serverless (Knative)

---

## Architecture Design

### Cluster Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster (4.14+)                     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Control Plane (3 nodes)                   │ │
│  │  • API Server  • etcd  • Scheduler  • Controllers          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                Infrastructure Nodes (3 nodes)               │ │
│  │  • Router  • Registry  • Monitoring  • Logging             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  Worker Nodes (10+ nodes)                   │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │            Namespace: datalyptica-catalog            │  │ │
│  │  │  • PostgreSQL Operator (3 replicas)                  │  │ │
│  │  │  • Nessie (3 replicas)                               │  │ │
│  │  │  • Redis Operator (3 replicas)                       │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │           Namespace: datalyptica-streaming           │  │ │
│  │  │  • Strimzi Kafka Operator (KRaft mode)               │  │ │
│  │  │    - 5 Kafka brokers                                 │  │ │
│  │  │    - 3 Schema Registry                               │  │ │
│  │  │    - 3 Kafka Connect                                 │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │          Namespace: datalyptica-processing           │  │ │
│  │  │  • Spark Operator (on-demand pods)                   │  │ │
│  │  │  • Flink Operator (JobManager + TaskManagers)        │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │            Namespace: datalyptica-query              │  │ │
│  │  │  • Trino (1 coordinator, N workers)                  │  │ │
│  │  │  • ClickHouse Operator (cluster with replication)    │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │          Namespace: datalyptica-analytics            │  │ │
│  │  │  • Airflow (Kubernetes Executor)                     │  │ │
│  │  │  • JupyterHub (KubeSpawner)                          │  │ │
│  │  │  • MLflow                                            │  │ │
│  │  │  • Superset                                          │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Namespace: datalyptica-iam              │  │ │
│  │  │  • Keycloak Operator (3 replicas)                    │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │          Namespace: datalyptica-monitoring           │  │ │
│  │  │  • Prometheus Operator                               │  │ │
│  │  │  • Grafana Operator                                  │  │ │
│  │  │  • Loki Stack                                        │  │ │
│  │  │  • Alertmanager                                      │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      Storage (CSI)                          │ │
│  │  • Object Storage (S3-compatible via CSI or external)       │ │
│  │  • Block Storage (RWO for databases)                        │ │
│  │  • Shared Storage (RWX for shared configs)                  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cluster Requirements

### Minimum OpenShift Cluster

**For Small Deployment** (Development/Testing):

| Node Type | Count | vCPU | RAM | Storage | Role |
|-----------|-------|------|-----|---------|------|
| Control Plane | 3 | 8 | 32 GB | 200 GB | Master nodes |
| Infrastructure | 3 | 16 | 64 GB | 500 GB | Infra workloads |
| Worker | 5 | 32 | 128 GB | 1 TB | Application workloads |
| **Total** | **11** | **232** | **1,088 GB** | **5.6 TB** | |

**For Production Deployment**:

| Node Type | Count | vCPU | RAM | Storage | Role |
|-----------|-------|------|-----|---------|------|
| Control Plane | 3 | 16 | 64 GB | 500 GB | Master nodes (HA) |
| Infrastructure | 3 | 32 | 128 GB | 1 TB | Infra workloads |
| Worker (Catalog) | 3 | 32 | 128 GB | 2 TB | Database workloads |
| Worker (Streaming) | 5 | 32 | 128 GB | 2 TB | Kafka brokers |
| Worker (Processing) | 6 | 64 | 256 GB | 2 TB | Spark/Flink |
| Worker (Query) | 5 | 32 | 128 GB | 1 TB | Trino/ClickHouse |
| Worker (Analytics) | 3 | 32 | 128 GB | 1 TB | Airflow/Jupyter |
| **Total** | **28** | **896** | **3,456 GB** | **35 TB** | |

### OpenShift Version Requirements

- **Red Hat OpenShift**: 4.14+ (or higher)
- **Kubernetes**: 1.27+ (if using vanilla Kubernetes)
- **OpenShift Container Platform (OCP)** or **OKD** (community version)

### Required Operators

All available from OperatorHub:

| Operator | Purpose | Version |
|----------|---------|---------|
| **Strimzi Kafka Operator** | Kafka management | 0.39+ |
| **Crunchy PostgreSQL Operator** | PostgreSQL HA | 5.5+ |
| **ClickHouse Operator** | ClickHouse cluster | Latest |
| **Spark Operator** | Spark on K8s | 1.3+ |
| **Flink Kubernetes Operator** | Flink management | 1.7+ |
| **Keycloak Operator** | IAM | 24+ |
| **Redis Operator** | Redis clusters | Latest |
| **Prometheus Operator** | Monitoring | (built-in) |
| **Grafana Operator** | Dashboards | 5.9+ |
| **Loki Operator** | Log aggregation | Latest |

---

## Namespace Design

### Namespace Strategy

Organize by functional tier for isolation and resource management:

```yaml
# Namespace hierarchy
datalyptica/
├── datalyptica-catalog          # Metadata & catalog
│   ├── PostgreSQL (via operator)
│   ├── Nessie
│   └── Redis
├── datalyptica-streaming        # Event streaming
│   ├── Kafka (via Strimzi)
│   ├── Schema Registry
│   └── Kafka Connect
├── datalyptica-processing       # Data processing
│   ├── Spark jobs (via operator)
│   └── Flink jobs (via operator)
├── datalyptica-query            # Query engines
│   ├── Trino
│   └── ClickHouse (via operator)
├── datalyptica-analytics        # Analytics & ML
│   ├── Airflow
│   ├── JupyterHub
│   ├── MLflow
│   └── Superset
├── datalyptica-iam              # Identity & access
│   └── Keycloak (via operator)
├── datalyptica-monitoring       # Observability
│   ├── Prometheus
│   ├── Grafana
│   ├── Loki
│   └── Alertmanager
└── datalyptica-system           # Platform utilities
    ├── Operators
    └── Shared configs
```

### Resource Quotas per Namespace

```yaml
# Example for production
Catalog Namespace:
  CPU: 100 cores
  Memory: 400 GB
  Storage: 10 TB
  
Streaming Namespace:
  CPU: 200 cores
  Memory: 800 GB
  Storage: 20 TB
  
Processing Namespace:
  CPU: 400 cores (burstable)
  Memory: 1.6 TB
  Storage: 10 TB
  
Query Namespace:
  CPU: 200 cores
  Memory: 800 GB
  Storage: 10 TB
  
Analytics Namespace:
  CPU: 150 cores
  Memory: 600 GB
  Storage: 5 TB
```

---

## Storage Strategy

### Storage Classes

Define multiple storage classes for different workload types:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: datalyptica-fast-ssd
provisioner: kubernetes.io/aws-ebs  # or appropriate CSI driver
parameters:
  type: io2
  iopsPerGB: "50"
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: datalyptica-standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: datalyptica-shared
provisioner: efs.csi.aws.com  # or NFS CSI
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
  directoryPerms: "700"
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

### Storage Requirements by Component

| Component | Access Mode | Storage Class | Size | IOPS |
|-----------|-------------|---------------|------|------|
| PostgreSQL | RWO | fast-ssd | 500 GB per replica | High |
| Kafka | RWO | fast-ssd | 1 TB per broker | Very High |
| ClickHouse | RWO | fast-ssd | 500 GB per node | High |
| Redis | RWO | fast-ssd | 50 GB per replica | High |
| Spark PVCs | RWO | standard | Dynamic | Medium |
| Flink State | RWO | fast-ssd | 100 GB | High |
| Shared Configs | RWX | shared | 100 GB | Low |
| JupyterHub Homes | RWX | shared | 1 TB | Medium |

### Enterprise Object Storage Integration

**Option 1: External S3-Compatible Service**
```yaml
# Configure via environment variables
AWS_ENDPOINT: https://s3.enterprise.local
AWS_ACCESS_KEY_ID: <from-secret>
AWS_SECRET_ACCESS_KEY: <from-secret>
AWS_REGION: us-east-1
S3_BUCKET: datalyptica-warehouse
```

**Option 2: S3 CSI Driver** (if supported by storage provider)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: datalyptica-object-storage
provisioner: s3.csi.aws.com
parameters:
  mounter: geesefs
  endpoint: https://s3.enterprise.local
```

**Option 3: MinIO Operator** (if no enterprise storage available)
```yaml
# Deploy MinIO in distributed mode via operator
# Not recommended for production, but option for testing
```

---

## Component Deployment

### 1. PostgreSQL (Crunchy PostgreSQL Operator)

**Deployment**: StatefulSet via Crunchy Operator  
**HA**: 3 replicas with streaming replication  
**Backups**: Automated via operator (pgBackRest to S3)

```yaml
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: datalyptica-postgres
  namespace: datalyptica-catalog
spec:
  postgresVersion: 16
  instances:
    - name: main
      replicas: 3
      dataVolumeClaimSpec:
        storageClassName: datalyptica-fast-ssd
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 500Gi
      resources:
        requests:
          cpu: 4000m
          memory: 16Gi
        limits:
          cpu: 8000m
          memory: 32Gi
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - topologyKey: kubernetes.io/hostname
  backups:
    pgbackrest:
      repos:
        - name: repo1
          s3:
            bucket: datalyptica-backups
            endpoint: s3.enterprise.local
            region: us-east-1
          schedules:
            full: "0 2 * * 0"
            differential: "0 2 * * 1-6"
  monitoring:
    pgmonitor:
      exporter:
        image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-5.5.0-0
```

**Databases to Create**:
- `datalyptica` - Main platform DB
- `nessie` - Nessie catalog
- `keycloak` - Keycloak data
- `airflow` - Airflow metadata
- `superset` - Superset metadata
- `grafana` - Grafana config

---

### 2. Kafka (Strimzi Operator - KRaft Mode)

**Deployment**: StatefulSet via Strimzi Operator  
**HA**: 5 brokers with KRaft quorum (no Zookeeper!)  
**Replication**: Factor 3, min.insync.replicas 2

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: datalyptica-kafka
  namespace: datalyptica-streaming
spec:
  kafka:
    version: 3.6.1
    replicas: 5
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
    config:
      # KRaft mode configuration
      process.roles: broker,controller
      node.id: 1
      controller.quorum.voters: 1@datalyptica-kafka-0.datalyptica-kafka-brokers:9093,2@datalyptica-kafka-1.datalyptica-kafka-brokers:9093,3@datalyptica-kafka-2.datalyptica-kafka-brokers:9093,4@datalyptica-kafka-3.datalyptica-kafka-brokers:9093,5@datalyptica-kafka-4.datalyptica-kafka-brokers:9093
      
      # Performance tuning
      num.network.threads: 8
      num.io.threads: 16
      socket.send.buffer.bytes: 1048576
      socket.receive.buffer.bytes: 1048576
      
      # Replication
      default.replication.factor: 3
      min.insync.replicas: 2
      unclean.leader.election.enable: false
      
      # Log configuration
      log.retention.hours: 168
      log.segment.bytes: 1073741824
      compression.type: lz4
      
      # Producer/Consumer
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
    storage:
      type: persistent-claim
      size: 1Ti
      class: datalyptica-fast-ssd
      deleteClaim: false
    resources:
      requests:
        cpu: 8000m
        memory: 16Gi
      limits:
        cpu: 16000m
        memory: 32Gi
    jvmOptions:
      -Xms: 12288m
      -Xmx: 12288m
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml
    template:
      pod:
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - topologyKey: kubernetes.io/hostname
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

**Schema Registry Deployment**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: schema-registry
  namespace: datalyptica-streaming
spec:
  replicas: 3
  selector:
    matchLabels:
      app: schema-registry
  template:
    metadata:
      labels:
        app: schema-registry
    spec:
      containers:
        - name: schema-registry
          image: confluentinc/cp-schema-registry:7.6.0
          ports:
            - containerPort: 8085
          env:
            - name: SCHEMA_REGISTRY_HOST_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS
              value: "datalyptica-kafka-kafka-bootstrap:9092"
            - name: SCHEMA_REGISTRY_LISTENERS
              value: "http://0.0.0.0:8085"
          resources:
            requests:
              cpu: 1000m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
```

---

### 3. Nessie Catalog

**Deployment**: Deployment (stateless, backed by PostgreSQL)  
**HA**: 3 replicas with load balancing

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nessie
  namespace: datalyptica-catalog
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nessie
  template:
    metadata:
      labels:
        app: nessie
    spec:
      containers:
        - name: nessie
          image: ghcr.io/projectnessie/nessie:0.77.1
          ports:
            - containerPort: 19120
              name: http
          env:
            - name: QUARKUS_DATASOURCE_JDBC_URL
              value: "jdbc:postgresql://datalyptica-postgres-primary:5432/nessie"
            - name: QUARKUS_DATASOURCE_USERNAME
              valueFrom:
                secretKeyRef:
                  name: datalyptica-postgres-pguser-nessie
                  key: user
            - name: QUARKUS_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: datalyptica-postgres-pguser-nessie
                  key: password
            - name: NESSIE_VERSION_STORE_TYPE
              value: "JDBC"
            - name: QUARKUS_HTTP_PORT
              value: "19120"
          resources:
            requests:
              cpu: 2000m
              memory: 4Gi
            limits:
              cpu: 4000m
              memory: 8Gi
          livenessProbe:
            httpGet:
              path: /api/v2/config
              port: 19120
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/v2/config
              port: 19120
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nessie
  namespace: datalyptica-catalog
spec:
  selector:
    app: nessie
  ports:
    - protocol: TCP
      port: 19120
      targetPort: 19120
  type: ClusterIP
```

---

### 4. Spark (Spark Operator)

**Deployment**: SparkApplication CRDs via Spark Operator  
**Execution**: Dynamic pod creation per job

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-iceberg-job
  namespace: datalyptica-processing
spec:
  type: Scala
  mode: cluster
  image: "ghcr.io/datalyptica/spark:3.5.0-iceberg-1.4.3"
  imagePullPolicy: Always
  mainClass: com.datalyptica.DataProcessor
  mainApplicationFile: "s3a://datalyptica-apps/spark-jobs/processor.jar"
  sparkVersion: "3.5.0"
  restartPolicy:
    type: OnFailure
    onFailureRetries: 3
    onFailureRetryInterval: 10
    onSubmissionFailureRetries: 5
    onSubmissionFailureRetryInterval: 20
  driver:
    cores: 4
    coreLimit: "4000m"
    memory: "8g"
    serviceAccount: spark-operator
    env:
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: s3-credentials
            key: access-key
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: s3-credentials
            key: secret-key
    sparkConf:
      spark.sql.catalog.nessie: org.apache.iceberg.spark.SparkCatalog
      spark.sql.catalog.nessie.catalog-impl: org.apache.iceberg.nessie.NessieCatalog
      spark.sql.catalog.nessie.uri: http://nessie.datalyptica-catalog.svc.cluster.local:19120/api/v1
      spark.sql.catalog.nessie.warehouse: s3a://datalyptica-warehouse/iceberg
      spark.hadoop.fs.s3a.endpoint: https://s3.enterprise.local
      spark.hadoop.fs.s3a.path.style.access: true
  executor:
    cores: 8
    instances: 10
    memory: "32g"
    serviceAccount: spark-operator
```

---

### 5. Trino

**Deployment**: Deployment (coordinator) + StatefulSet (workers)  
**HA**: Multiple coordinators with discovery service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino-coordinator
  namespace: datalyptica-query
spec:
  replicas: 2
  selector:
    matchLabels:
      app: trino
      component: coordinator
  template:
    metadata:
      labels:
        app: trino
        component: coordinator
    spec:
      containers:
        - name: trino
          image: trinodb/trino:439
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: TRINO_ENVIRONMENT
              value: "production"
          volumeMounts:
            - name: config
              mountPath: /etc/trino
            - name: catalog
              mountPath: /etc/trino/catalog
          resources:
            requests:
              cpu: 8000m
              memory: 32Gi
            limits:
              cpu: 16000m
              memory: 64Gi
      volumes:
        - name: config
          configMap:
            name: trino-coordinator-config
        - name: catalog
          configMap:
            name: trino-catalogs
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: trino-worker
  namespace: datalyptica-query
spec:
  serviceName: trino-worker
  replicas: 10
  selector:
    matchLabels:
      app: trino
      component: worker
  template:
    metadata:
      labels:
        app: trino
        component: worker
    spec:
      containers:
        - name: trino
          image: trinodb/trino:439
          env:
            - name: TRINO_ENVIRONMENT
              value: "production"
          volumeMounts:
            - name: config
              mountPath: /etc/trino
            - name: catalog
              mountPath: /etc/trino/catalog
            - name: data
              mountPath: /data/trino
          resources:
            requests:
              cpu: 8000m
              memory: 32Gi
            limits:
              cpu: 16000m
              memory: 64Gi
      volumes:
        - name: config
          configMap:
            name: trino-worker-config
        - name: catalog
          configMap:
            name: trino-catalogs
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: datalyptica-fast-ssd
        resources:
          requests:
            storage: 500Gi
```

---

### 6. Airflow (Kubernetes Executor)

**Deployment**: Helm chart with KubernetesExecutor  
**HA**: 2 schedulers, 2 webservers, dynamic workers

```bash
helm install airflow apache-airflow/airflow \
  --namespace datalyptica-analytics \
  --set executor=KubernetesExecutor \
  --set scheduler.replicas=2 \
  --set webserver.replicas=2 \
  --set postgresql.enabled=false \
  --set externalDatabase.type=postgres \
  --set externalDatabase.host=datalyptica-postgres-primary.datalyptica-catalog \
  --set externalDatabase.database=airflow \
  --set data.metadataConnection.protocol=postgresql \
  --set workers.persistence.enabled=false \
  --set logs.persistence.enabled=true \
  --set logs.persistence.size=100Gi \
  --set dags.gitSync.enabled=true \
  --set dags.gitSync.repo=https://github.com/datalyptica/airflow-dags \
  --set serviceAccount.create=true
```

---

### 7. Monitoring Stack

**Prometheus Operator** (built-in to OpenShift):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: datalyptica
  namespace: datalyptica-monitoring
spec:
  replicas: 2
  retention: 30d
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: datalyptica-standard
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 500Gi
  serviceMonitorSelector:
    matchLabels:
      monitoring: datalyptica
  resources:
    requests:
      cpu: 4000m
      memory: 16Gi
    limits:
      cpu: 8000m
      memory: 32Gi
```

**Grafana Operator**:

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: datalyptica-grafana
  namespace: datalyptica-monitoring
spec:
  config:
    log:
      mode: "console"
    auth:
      disable_login_form: false
    security:
      admin_user: admin
      admin_password: admin
  deployment:
    spec:
      replicas: 3
      template:
        spec:
          containers:
            - name: grafana
              resources:
                requests:
                  cpu: 1000m
                  memory: 2Gi
                limits:
                  cpu: 2000m
                  memory: 4Gi
```

---

## High Availability

### Built-in HA Features

| Component | HA Mechanism | Replicas | Failover |
|-----------|--------------|----------|----------|
| **PostgreSQL** | Operator-managed replication | 3 | <30s |
| **Kafka** | KRaft quorum | 5 | <10s |
| **Nessie** | Load-balanced pods | 3 | <5s |
| **Redis** | Operator-managed sentinel | 3 | <10s |
| **Trino Coordinator** | Multiple instances | 2+ | <5s |
| **ClickHouse** | Operator replication | 3+ | <30s |
| **Keycloak** | Clustered pods | 3 | <5s |
| **Airflow Scheduler** | HA mode (K8s Executor) | 2 | <30s |
| **All Web UIs** | ReplicaSets | 2-3 | <5s |

### Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nessie-pdb
  namespace: datalyptica-catalog
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: nessie
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: kafka-pdb
  namespace: datalyptica-streaming
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      strimzi.io/kind: Kafka
```

---

## Security & RBAC

### Security Context Constraints (SCC)

Custom SCCs for specific workloads:

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: datalyptica-postgres-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities:
  - CHOWN
  - FOWNER
  - SETGID
  - SETUID
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 26
  uidRangeMax: 26
seLinuxContext:
  type: MustRunAs
fsGroup:
  type: MustRunAs
  ranges:
    - min: 26
      max: 26
supplementalGroups:
  type: RunAsAny
volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
```

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: datalyptica-catalog-netpol
  namespace: datalyptica-catalog
spec:
  podSelector:
    matchLabels:
      app: nessie
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: datalyptica-query
        - namespaceSelector:
            matchLabels:
              name: datalyptica-processing
      ports:
        - protocol: TCP
          port: 19120
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: datalyptica-catalog
      ports:
        - protocol: TCP
          port: 5432  # PostgreSQL
    - to:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 53  # DNS
```

---

## Networking

### Routes/Ingress

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: grafana
  namespace: datalyptica-monitoring
spec:
  host: grafana.datalyptica.apps.ocp.company.com
  to:
    kind: Service
    name: datalyptica-grafana-service
  port:
    targetPort: 3000
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: trino
  namespace: datalyptica-query
spec:
  host: trino.datalyptica.apps.ocp.company.com
  to:
    kind: Service
    name: trino-coordinator
  port:
    targetPort: 8080
  tls:
    termination: edge
```

### Service Mesh (Optional)

For advanced traffic management, mTLS, and observability:

```bash
# Install Red Hat Service Mesh Operator
oc apply -f servicemesh-operator.yaml

# Create Service Mesh Control Plane
oc apply -f servicemesh-controlplane.yaml

# Add namespaces to mesh
oc apply -f servicemesh-memberroll.yaml
```

---

## Monitoring & Observability

### ServiceMonitors for Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka-metrics
  namespace: datalyptica-streaming
  labels:
    monitoring: datalyptica
spec:
  selector:
    matchLabels:
      strimzi.io/kind: Kafka
  endpoints:
    - port: tcp-prometheus
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-metrics
  namespace: datalyptica-catalog
  labels:
    monitoring: datalyptica
spec:
  selector:
    matchLabels:
      postgres-operator.crunchydata.com/cluster: datalyptica-postgres
  endpoints:
    - port: exporter
      interval: 30s
```

---

## Deployment Steps

### 1. Install Operators

```bash
# Install required operators via OperatorHub
oc apply -f operators/strimzi-kafka-operator.yaml
oc apply -f operators/crunchy-postgres-operator.yaml
oc apply -f operators/clickhouse-operator.yaml
oc apply -f operators/spark-operator.yaml
oc apply -f operators/flink-operator.yaml
oc apply -f operators/keycloak-operator.yaml
oc apply -f operators/grafana-operator.yaml
```

### 2. Create Namespaces

```bash
oc apply -f manifests/namespaces.yaml
```

### 3. Deploy Catalog Layer

```bash
oc apply -f manifests/catalog/postgresql-cluster.yaml
oc apply -f manifests/catalog/nessie-deployment.yaml
oc apply -f manifests/catalog/redis-cluster.yaml
```

### 4. Deploy Streaming Layer

```bash
oc apply -f manifests/streaming/kafka-cluster.yaml
oc apply -f manifests/streaming/schema-registry.yaml
oc apply -f manifests/streaming/kafka-connect.yaml
```

### 5. Deploy Query Layer

```bash
oc apply -f manifests/query/trino.yaml
oc apply -f manifests/query/clickhouse-cluster.yaml
```

### 6. Deploy Analytics Layer

```bash
helm install airflow -f helm/airflow-values.yaml apache-airflow/airflow
helm install jupyterhub -f helm/jupyterhub-values.yaml jupyterhub/jupyterhub
```

### 7. Deploy Monitoring

```bash
oc apply -f manifests/monitoring/prometheus.yaml
oc apply -f manifests/monitoring/grafana.yaml
oc apply -f manifests/monitoring/loki.yaml
```

---

## Cost Comparison

### VM Deployment vs OpenShift

| Aspect | VM (50 VMs) | OpenShift (28 nodes) |
|--------|-------------|---------------------|
| **Hardware** | $250K | $200K |
| **Storage** | $500K-$2M | $300K-$1M (more efficient) |
| **Annual Ops** | $960K | $600K (less manual work) |
| **OpenShift License** | - | $150K/year |
| **Total Year 1** | $1.71M-$3.21M | $1.25M-$1.95M |
| **TCO (3 years)** | $3.63M-$5.63M | $2.45M-$3.35M |

**Savings**: 30-40% lower TCO with OpenShift

---

## Summary

OpenShift deployment provides:

✅ **Simpler Operations** - Operators manage complexity  
✅ **Better HA** - Built-in pod replication and self-healing  
✅ **Easier Scaling** - HPA, VPA, cluster autoscaler  
✅ **Faster Deployment** - Days instead of weeks  
✅ **Lower TCO** - 30-40% cost savings over 3 years  
✅ **Cloud-Native** - Modern architecture patterns  
✅ **Enterprise Support** - Red Hat support for entire stack  

**Next Steps**: Review architecture, provision OpenShift cluster, deploy operators!
