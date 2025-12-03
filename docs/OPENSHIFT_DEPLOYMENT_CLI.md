# OpenShift Deployment Guide - CLI Method

**Platform**: Red Hat OpenShift 4.17+  
**Version**: Datalyptica 4.0.0  
**Method**: Command Line Interface (oc CLI)  
**Prerequisites**: oc CLI installed and authenticated

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Setup](#pre-deployment-setup)
3. [Phase 1: Operator Installation](#phase-1-operator-installation)
4. [Phase 2: Storage Configuration](#phase-2-storage-configuration)
5. [Phase 3: Core Services](#phase-3-core-services)
6. [Phase 4: Data Platform Services](#phase-4-data-platform-services)
7. [Phase 5: Analytics & ML Services](#phase-5-analytics--ml-services)
8. [Phase 6: Monitoring Stack](#phase-6-monitoring-stack)
9. [Phase 7: IAM Services](#phase-7-iam-services)
10. [Verification & Testing](#verification--testing)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

```bash
# Install OpenShift CLI
curl -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo mv oc /usr/local/bin/
sudo mv kubectl /usr/local/bin/

# Verify installation
oc version
```

### Login to OpenShift

```bash
# Login with credentials
oc login https://api.your-cluster.example.com:6443 \
  --username=your-username \
  --password=your-password

# Or with token
oc login --token=YOUR_TOKEN \
  --server=https://api.your-cluster.example.com:6443

# Verify login
oc whoami
oc cluster-info
```

### Clone Repository

```bash
git clone https://github.com/datalyptica/datalyptica.git
cd datalyptica
```

---

## Pre-Deployment Setup

### 1. Create Project/Namespaces

```bash
# Create all required namespaces
oc create namespace datalyptica-operators
oc create namespace datalyptica-storage
oc create namespace datalyptica-catalog
oc create namespace datalyptica-streaming
oc create namespace datalyptica-processing
oc create namespace datalyptica-query
oc create namespace datalyptica-analytics
oc create namespace datalyptica-monitoring
oc create namespace datalyptica-iam

# Verify namespaces
oc get namespaces | grep datalyptica
```

### 2. Configure Security Context Constraints (SCC)

```bash
# Create custom SCC for Datalyptica
cat <<EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: datalyptica-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities:
- NET_BIND_SERVICE
defaultAddCapabilities: []
fsGroup:
  type: MustRunAs
  ranges:
  - min: 1000
    max: 65535
groups: []
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 65535
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users: []
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
EOF

# Apply SCC to service accounts (repeat for each namespace)
oc adm policy add-scc-to-user datalyptica-scc \
  system:serviceaccount:datalyptica-storage:default
```

### 3. Create Storage Classes

```bash
# Fast SSD storage for databases
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: datalyptica-fast
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  fsType: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

# Standard storage for general use
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: datalyptica-standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "1000"
  throughput: "125"
  fsType: ext4
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

# Verify storage classes
oc get storageclass | grep datalyptica
```

### 4. Prepare Secrets

```bash
# Create secrets directory structure (if not exists)
mkdir -p secrets/passwords secrets/certificates

# Generate random passwords (example)
openssl rand -base64 32 > secrets/passwords/postgres_password
openssl rand -base64 32 > secrets/passwords/minio_root_password
openssl rand -base64 32 > secrets/passwords/keycloak_admin_password

# Create Kubernetes secrets for storage namespace
oc create secret generic postgres-credentials \
  --from-file=password=secrets/passwords/postgres_password \
  -n datalyptica-storage

oc create secret generic minio-credentials \
  --from-file=root-password=secrets/passwords/minio_root_password \
  -n datalyptica-storage

# Create secrets for IAM namespace
oc create secret generic keycloak-credentials \
  --from-file=admin-password=secrets/passwords/keycloak_admin_password \
  -n datalyptica-iam
```

---

## Phase 1: Operator Installation

### 1.1 Install Strimzi Kafka Operator (v0.49.0)

```bash
# Create OperatorGroup
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: strimzi-operator-group
  namespace: datalyptica-operators
spec:
  targetNamespaces:
  - datalyptica-streaming
EOF

# Create Subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: strimzi-kafka-operator
  namespace: datalyptica-operators
spec:
  channel: stable
  name: strimzi-kafka-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
  startingCSV: strimzi-cluster-operator.v0.49.0
EOF

# Wait for operator to be ready
oc wait --for=condition=Ready pod -l name=strimzi-cluster-operator \
  -n datalyptica-operators --timeout=300s

# Verify installation
oc get csv -n datalyptica-operators | grep strimzi
```

### 1.2 Install Crunchy PostgreSQL Operator (v5.8.5)

```bash
# Add Crunchy operator catalog source
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: crunchy-postgres-operator
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.connect.redhat.com/crunchydata/postgres-operator-bundle@sha256:latest
  displayName: Crunchy PostgreSQL Operator
  publisher: Crunchy Data
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

# Create OperatorGroup
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: postgres-operator-group
  namespace: datalyptica-operators
spec:
  targetNamespaces:
  - datalyptica-storage
EOF

# Create Subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: crunchy-postgres-operator
  namespace: datalyptica-operators
spec:
  channel: v5
  name: postgresql
  source: crunchy-postgres-operator
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
  startingCSV: postgresoperator.v5.8.5
EOF

# Wait for operator to be ready
oc wait --for=condition=Ready pod -l postgres-operator.crunchydata.com/control-plane=postgres-operator \
  -n datalyptica-operators --timeout=300s

# Verify installation
oc get csv -n datalyptica-operators | grep postgres
```

### 1.3 Install Flink Kubernetes Operator (v1.13.0)

```bash
# Add Helm repository
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.13.0/
helm repo update

# Install operator using Helm
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator \
  --namespace datalyptica-operators \
  --set watchNamespaces={datalyptica-processing} \
  --version 1.13.0

# Wait for operator to be ready
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=flink-kubernetes-operator \
  -n datalyptica-operators --timeout=300s

# Verify installation
oc get pods -n datalyptica-operators | grep flink-kubernetes-operator
```

### Verify All Operators

```bash
# Check all operators are running
oc get csv -n datalyptica-operators
oc get pods -n datalyptica-operators

# Expected output: All operators in "Succeeded" phase
```

---

## Phase 2: Storage Configuration

### 2.1 Deploy MinIO Object Storage

```bash
# Create PVC for MinIO
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-data
  namespace: datalyptica-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi
  storageClassName: datalyptica-standard
EOF

# Create MinIO Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: datalyptica-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:RELEASE.2025-10-15T17-29-55Z
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: admin
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: root-password
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-data
EOF

# Create MinIO Service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: datalyptica-storage
spec:
  type: ClusterIP
  ports:
  - port: 9000
    targetPort: 9000
    name: api
  - port: 9001
    targetPort: 9001
    name: console
  selector:
    app: minio
EOF

# Create MinIO Route for Console
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-console
  namespace: datalyptica-storage
spec:
  to:
    kind: Service
    name: minio
  port:
    targetPort: console
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Wait for MinIO to be ready
oc wait --for=condition=Ready pod -l app=minio \
  -n datalyptica-storage --timeout=300s

# Get MinIO console URL
oc get route minio-console -n datalyptica-storage -o jsonpath='{.spec.host}'
```

### 2.2 Deploy PostgreSQL (via Crunchy Operator)

```bash
# Create PostgreSQL Cluster Custom Resource
cat <<EOF | oc apply -f -
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: datalyptica-postgres
  namespace: datalyptica-storage
spec:
  postgresVersion: 16
  image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi8-16.6-0
  instances:
  - name: instance1
    replicas: 3
    dataVolumeClaimSpec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 100Gi
      storageClassName: datalyptica-fast
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                postgres-operator.crunchydata.com/cluster: datalyptica-postgres
                postgres-operator.crunchydata.com/instance-set: instance1
            topologyKey: kubernetes.io/hostname
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 8Gi
  backups:
    pgbackrest:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:ubi8-2.53.1-0
      repos:
      - name: repo1
        volume:
          volumeClaimSpec:
            accessModes:
            - ReadWriteOnce
            resources:
              requests:
                storage: 50Gi
            storageClassName: datalyptica-standard
  monitoring:
    pgmonitor:
      exporter:
        image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter:ubi8-5.8.5-0
  proxy:
    pgBouncer:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbouncer:ubi8-1.23-0
      replicas: 2
      resources:
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 1Gi
EOF

# Wait for PostgreSQL cluster to be ready
oc wait --for=condition=Ready postgrescluster/datalyptica-postgres \
  -n datalyptica-storage --timeout=600s

# Get PostgreSQL connection info
oc get secret datalyptica-postgres-pguser-datalyptica-postgres \
  -n datalyptica-storage -o jsonpath='{.data.uri}' | base64 -d
```

---

## Phase 3: Core Services

### 3.1 Deploy Redis (v8.4.0)

```bash
# Create Redis ConfigMap
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: datalyptica-catalog
data:
  redis.conf: |
    maxmemory 2gb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfsync everysec
EOF

# Create Redis PVC
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: datalyptica-catalog
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: datalyptica-fast
EOF

# Create Redis StatefulSet
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: datalyptica-catalog
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:8.4.0-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: data
          mountPath: /data
        - name: config
          mountPath: /etc/redis
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 4Gi
        livenessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: redis-data
      - name: config
        configMap:
          name: redis-config
EOF

# Create Redis Service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: datalyptica-catalog
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
  selector:
    app: redis
EOF

# Wait for Redis to be ready
oc wait --for=condition=Ready pod -l app=redis \
  -n datalyptica-catalog --timeout=300s
```

### 3.2 Deploy Nessie (v0.105.7)

```bash
# Create Nessie Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nessie
  namespace: datalyptica-catalog
spec:
  replicas: 2
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
        image: ghcr.io/projectnessie/nessie:0.105.7
        ports:
        - containerPort: 19120
          name: http
        env:
        - name: QUARKUS_DATASOURCE_JDBC_URL
          value: jdbc:postgresql://datalyptica-postgres-primary.datalyptica-storage.svc:5432/nessie
        - name: QUARKUS_DATASOURCE_USERNAME
          value: nessie
        - name: QUARKUS_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: NESSIE_VERSION_STORE_TYPE
          value: JDBC
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /q/health/live
            port: 19120
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /q/health/ready
            port: 19120
          initialDelaySeconds: 10
          periodSeconds: 5
EOF

# Create Nessie Service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nessie
  namespace: datalyptica-catalog
spec:
  type: ClusterIP
  ports:
  - port: 19120
    targetPort: 19120
    name: http
  selector:
    app: nessie
EOF

# Wait for Nessie to be ready
oc wait --for=condition=Ready pod -l app=nessie \
  -n datalyptica-catalog --timeout=300s
```

---

## Phase 4: Data Platform Services

### 4.1 Deploy Kafka (v4.1.1) using Strimzi

```bash
# Create Kafka Cluster Custom Resource (v1 API)
cat <<EOF | oc apply -f -
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: datalyptica-kafka
  namespace: datalyptica-streaming
spec:
  kafka:
    version: 4.1.1
    replicas: 3
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
      inter.broker.protocol.version: "4.1"
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        deleteClaim: false
        class: datalyptica-fast
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 8Gi
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 20Gi
      deleteClaim: false
      class: datalyptica-fast
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi
  entityOperator:
    topicOperator:
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: 500m
          memory: 1Gi
    userOperator:
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: 500m
          memory: 1Gi
EOF

# Wait for Kafka cluster to be ready (this may take 5-10 minutes)
oc wait kafka/datalyptica-kafka --for=condition=Ready \
  -n datalyptica-streaming --timeout=900s

# Verify Kafka cluster
oc get kafka -n datalyptica-streaming
oc get pods -n datalyptica-streaming | grep kafka
```

### 4.2 Deploy Trino (v478)

```bash
# Create Trino ConfigMap
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-config
  namespace: datalyptica-query
data:
  config.properties: |
    coordinator=true
    node-scheduler.include-coordinator=false
    http-server.http.port=8080
    query.max-memory=4GB
    query.max-memory-per-node=2GB
    discovery.uri=http://trino:8080

  catalog-iceberg.properties: |
    connector.name=iceberg
    iceberg.catalog.type=nessie
    iceberg.nessie-catalog.uri=http://nessie.datalyptica-catalog.svc:19120/api/v1
    iceberg.nessie-catalog.ref=main
    iceberg.nessie-catalog.default-warehouse-dir=s3a://lakehouse/iceberg
    fs.native-s3.enabled=true
    s3.endpoint=http://minio.datalyptica-storage.svc:9000
    s3.path-style-access=true
EOF

# Create Trino Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino
  namespace: datalyptica-query
spec:
  replicas: 3
  selector:
    matchLabels:
      app: trino
  template:
    metadata:
      labels:
        app: trino
    spec:
      containers:
      - name: trino
        image: trinodb/trino:478
        ports:
        - containerPort: 8080
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/trino
        resources:
          requests:
            cpu: 2000m
            memory: 4Gi
          limits:
            cpu: 4000m
            memory: 8Gi
        livenessProbe:
          httpGet:
            path: /v1/info
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /v1/info
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: trino-config
EOF

# Create Trino Service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: trino
  namespace: datalyptica-query
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: trino
EOF

# Wait for Trino to be ready
oc wait --for=condition=Ready pod -l app=trino \
  -n datalyptica-query --timeout=300s
```

### 4.3 Deploy Spark (v4.0.1)

```bash
# Create Spark Master Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-master
  namespace: datalyptica-processing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-master
  template:
    metadata:
      labels:
        app: spark-master
    spec:
      containers:
      - name: spark-master
        image: apache/spark:4.0.1-scala2.13-java17-python3-ubuntu
        command: ["/opt/spark/bin/spark-class"]
        args: ["org.apache.spark.deploy.master.Master"]
        ports:
        - containerPort: 7077
          name: spark
        - containerPort: 8080
          name: web
        env:
        - name: SPARK_MODE
          value: master
        - name: SPARK_MASTER_HOST
          value: spark-master
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
EOF

# Create Spark Worker Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-worker
  namespace: datalyptica-processing
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spark-worker
  template:
    metadata:
      labels:
        app: spark-worker
    spec:
      containers:
      - name: spark-worker
        image: apache/spark:4.0.1-scala2.13-java17-python3-ubuntu
        command: ["/opt/spark/bin/spark-class"]
        args:
        - org.apache.spark.deploy.worker.Worker
        - spark://spark-master:7077
        ports:
        - containerPort: 8081
          name: web
        env:
        - name: SPARK_MODE
          value: worker
        - name: SPARK_MASTER_URL
          value: spark://spark-master:7077
        - name: SPARK_WORKER_CORES
          value: "4"
        - name: SPARK_WORKER_MEMORY
          value: 4g
        resources:
          requests:
            cpu: 2000m
            memory: 4Gi
          limits:
            cpu: 4000m
            memory: 8Gi
EOF

# Create Spark Services
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: spark-master
  namespace: datalyptica-processing
spec:
  type: ClusterIP
  ports:
  - port: 7077
    targetPort: 7077
    name: spark
  - port: 8080
    targetPort: 8080
    name: web
  selector:
    app: spark-master
EOF

# Wait for Spark to be ready
oc wait --for=condition=Ready pod -l app=spark-master \
  -n datalyptica-processing --timeout=300s
```

---

## Phase 5: Analytics & ML Services

### 5.1 Deploy Apache Airflow (v3.1.3)

```bash
# Create Airflow Database in PostgreSQL
oc exec -it datalyptica-postgres-instance1-xxxx -n datalyptica-storage -- \
  psql -U postgres -c "CREATE DATABASE airflow;"

# Create Airflow ConfigMap
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-config
  namespace: datalyptica-analytics
data:
  AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:password@datalyptica-postgres-primary.datalyptica-storage.svc:5432/airflow
  AIRFLOW__CORE__EXECUTOR: KubernetesExecutor
  AIRFLOW__KUBERNETES__NAMESPACE: datalyptica-analytics
  AIRFLOW__WEBSERVER__BASE_URL: http://airflow:8080
EOF

# Create Airflow Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-webserver
  namespace: datalyptica-analytics
spec:
  replicas: 2
  selector:
    matchLabels:
      app: airflow-webserver
  template:
    metadata:
      labels:
        app: airflow-webserver
    spec:
      initContainers:
      - name: airflow-init
        image: apache/airflow:3.1.3-python3.11
        command: ["airflow", "db", "migrate"]
        envFrom:
        - configMapRef:
            name: airflow-config
      containers:
      - name: airflow-webserver
        image: apache/airflow:3.1.3-python3.11
        command: ["airflow", "webserver"]
        ports:
        - containerPort: 8080
          name: web
        envFrom:
        - configMapRef:
            name: airflow-config
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
EOF

# Create Airflow Scheduler Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-scheduler
  namespace: datalyptica-analytics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow-scheduler
  template:
    metadata:
      labels:
        app: airflow-scheduler
    spec:
      containers:
      - name: airflow-scheduler
        image: apache/airflow:3.1.3-python3.11
        command: ["airflow", "scheduler"]
        envFrom:
        - configMapRef:
            name: airflow-config
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
EOF

# Create Airflow Service
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: airflow
  namespace: datalyptica-analytics
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: web
  selector:
    app: airflow-webserver
EOF

# Create Route for Airflow Web UI
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: airflow
  namespace: datalyptica-analytics
spec:
  to:
    kind: Service
    name: airflow
  port:
    targetPort: web
  tls:
    termination: edge
EOF

# Get Airflow URL
oc get route airflow -n datalyptica-analytics -o jsonpath='{.spec.host}'
```

### 5.2 Deploy MLflow (v3.6.0)

```bash
# Create MLflow Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow
  namespace: datalyptica-analytics
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      containers:
      - name: mlflow
        image: ghcr.io/mlflow/mlflow:v3.6.0
        command:
        - mlflow
        - server
        - --host=0.0.0.0
        - --port=5000
        - --backend-store-uri=postgresql://mlflow:password@datalyptica-postgres-primary.datalyptica-storage.svc:5432/mlflow
        - --default-artifact-root=s3://mlflow/artifacts
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: AWS_ACCESS_KEY_ID
          value: admin
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: root-password
        - name: MLFLOW_S3_ENDPOINT_URL
          value: http://minio.datalyptica-storage.svc:9000
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
EOF

# Create MLflow Service and Route
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mlflow
  namespace: datalyptica-analytics
spec:
  type: ClusterIP
  ports:
  - port: 5000
    targetPort: 5000
  selector:
    app: mlflow
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: mlflow
  namespace: datalyptica-analytics
spec:
  to:
    kind: Service
    name: mlflow
  port:
    targetPort: 5000
  tls:
    termination: edge
EOF
```

---

## Phase 6: Monitoring Stack

### 6.1 Deploy Prometheus (v3.8.0)

```bash
# Create Prometheus ConfigMap (use the one from configs/)
oc create configmap prometheus-config \
  --from-file=prometheus.yml=configs/prometheus/prometheus.yml \
  --from-file=alerts.yml=configs/prometheus/alerts.yml \
  -n datalyptica-monitoring

# Create Prometheus PVC
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: datalyptica-monitoring
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: datalyptica-standard
EOF

# Create Prometheus Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: datalyptica-monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v3.8.0
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.retention.time=30d
        - --web.enable-lifecycle
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        persistentVolumeClaim:
          claimName: prometheus-data
EOF

# Create Service and Route
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: datalyptica-monitoring
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    app: prometheus
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: prometheus
  namespace: datalyptica-monitoring
spec:
  to:
    kind: Service
    name: prometheus
  port:
    targetPort: 9090
  tls:
    termination: edge
EOF
```

### 6.2 Deploy Grafana (v12.3.0)

```bash
# Create Grafana ConfigMaps
oc create configmap grafana-datasources \
  --from-file=prometheus.yml=configs/grafana/provisioning/datasources/prometheus.yml \
  --from-file=loki.yml=configs/grafana/provisioning/datasources/loki.yml \
  -n datalyptica-monitoring

# Create Grafana PVC
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data
  namespace: datalyptica-monitoring
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: datalyptica-standard
EOF

# Create Grafana Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: datalyptica-monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:12.3.0
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: admin-password
        volumeMounts:
        - name: data
          mountPath: /var/lib/grafana
        - name: datasources
          mountPath: /etc/grafana/provisioning/datasources
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: grafana-data
      - name: datasources
        configMap:
          name: grafana-datasources
EOF

# Create Service and Route
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: datalyptica-monitoring
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: grafana
  namespace: datalyptica-monitoring
spec:
  to:
    kind: Service
    name: grafana
  port:
    targetPort: 3000
  tls:
    termination: edge
EOF
```

---

## Phase 7: IAM Services

### 7.1 Deploy Keycloak (v26.4.7)

```bash
# Create Keycloak Database
oc exec -it datalyptica-postgres-instance1-xxxx -n datalyptica-storage -- \
  psql -U postgres -c "CREATE DATABASE keycloak;"

# Create Keycloak Deployment
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: datalyptica-iam
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:26.4.7
        args: ["start"]
        env:
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://datalyptica-postgres-primary.datalyptica-storage.svc:5432/keycloak
        - name: KC_DB_USERNAME
          value: keycloak
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: KEYCLOAK_ADMIN
          value: admin
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-credentials
              key: admin-password
        - name: KC_PROXY
          value: edge
        - name: KC_HOSTNAME_STRICT
          value: "false"
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
EOF

# Create Service and Route
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: datalyptica-iam
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: keycloak
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: keycloak
  namespace: datalyptica-iam
spec:
  to:
    kind: Service
    name: keycloak
  port:
    targetPort: 8080
  tls:
    termination: edge
EOF

# Get Keycloak URL
oc get route keycloak -n datalyptica-iam -o jsonpath='{.spec.host}'
```

---

## Verification & Testing

### Check All Pods Status

```bash
# Check operators
oc get pods -n datalyptica-operators

# Check storage
oc get pods -n datalyptica-storage

# Check catalog
oc get pods -n datalyptica-catalog

# Check streaming
oc get pods -n datalyptica-streaming

# Check processing
oc get pods -n datalyptica-processing

# Check query
oc get pods -n datalyptica-query

# Check analytics
oc get pods -n datalyptica-analytics

# Check monitoring
oc get pods -n datalyptica-monitoring

# Check IAM
oc get pods -n datalyptica-iam

# Get all routes
oc get routes --all-namespaces | grep datalyptica
```

### Test Service Connectivity

```bash
# Test MinIO
oc exec -it deployment/minio -n datalyptica-storage -- \
  mc alias set local http://localhost:9000 admin PASSWORD

# Test PostgreSQL
oc exec -it datalyptica-postgres-instance1-xxxx -n datalyptica-storage -- \
  psql -U postgres -c "SELECT version();"

# Test Redis
oc exec -it redis-0 -n datalyptica-catalog -- redis-cli ping

# Test Kafka
oc exec -it datalyptica-kafka-kafka-0 -n datalyptica-streaming -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

---

## Troubleshooting

### View Pod Logs

```bash
# View logs for any pod
oc logs -f <pod-name> -n <namespace>

# View previous logs if pod crashed
oc logs --previous <pod-name> -n <namespace>

# View logs for specific container in multi-container pod
oc logs -f <pod-name> -c <container-name> -n <namespace>
```

### Debug Pod Issues

```bash
# Describe pod for events and status
oc describe pod <pod-name> -n <namespace>

# Get pod YAML
oc get pod <pod-name> -n <namespace> -o yaml

# Execute commands inside pod
oc exec -it <pod-name> -n <namespace> -- /bin/bash
```

### Common Issues

**Issue: Pod stuck in Pending**

```bash
# Check PVC status
oc get pvc -n <namespace>

# Check node resources
oc describe node | grep -A 5 "Allocated resources"
```

**Issue: ImagePullBackOff**

```bash
# Check image pull secrets
oc get secrets -n <namespace>

# Verify image exists
oc describe pod <pod-name> -n <namespace> | grep -A 10 Events
```

**Issue: CrashLoopBackOff**

```bash
# Check logs
oc logs --previous <pod-name> -n <namespace>

# Check liveness/readiness probe configuration
oc get pod <pod-name> -n <namespace> -o yaml | grep -A 10 livenessProbe
```

---

## Next Steps

1. **Configure Networking**: Set up network policies for inter-service communication
2. **Enable TLS**: Configure TLS certificates for all external routes
3. **Set up Backups**: Configure backup strategies for stateful services
4. **Configure Monitoring**: Set up alerts and dashboards in Grafana
5. **Performance Tuning**: Adjust resource limits based on workload
6. **Security Hardening**: Implement RBAC, pod security policies, and secrets management

---

## Additional Resources

- **OpenShift Documentation**: https://docs.openshift.com/
- **Component Versions**: See `/deploy/openshift/docs/COMPONENT-VERSIONS.md`
- **Migration Guides**: See `/deploy/openshift/docs/COMPONENT-VERSIONS.md`
- **Troubleshooting**: See `/archive/TROUBLESHOOTING.md`

---

**Deployment Complete!** 🎉

All services should now be running on OpenShift. Use the routes to access the web UIs:

- MinIO Console
- Grafana Dashboard
- Airflow Web UI
- MLflow UI
- Keycloak Admin Console
