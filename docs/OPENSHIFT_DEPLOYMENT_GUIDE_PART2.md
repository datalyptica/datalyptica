# Datalyptica Platform - OpenShift Deployment Guide (Part 2)

**Continuation of main deployment guide**

---

## 8.4 Deploy Schema Registry

Schema Registry for Avro schema management:

```yaml
# File: schema-registry.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: schema-registry
  namespace: datalyptica-control
  labels:
    app: schema-registry
spec:
  replicas: 2
  selector:
    matchLabels:
      app: schema-registry
  template:
    metadata:
      labels:
        app: schema-registry
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: schema-registry
                topologyKey: kubernetes.io/hostname
      containers:
        - name: schema-registry
          image: confluentinc/cp-schema-registry:7.5.0
          ports:
            - containerPort: 8081
              name: http
            - containerPort: 8443
              name: https
          env:
            - name: SCHEMA_REGISTRY_HOST_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS
              value: "datalyptica-kafka-kafka-bootstrap:9092"
            - name: SCHEMA_REGISTRY_LISTENERS
              value: "http://0.0.0.0:8081"
            - name: SCHEMA_REGISTRY_KAFKASTORE_TOPIC
              value: "_schemas"
            - name: SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR
              value: "3"
            - name: SCHEMA_REGISTRY_AVRO_COMPATIBILITY_LEVEL
              value: "BACKWARD"
            - name: SCHEMA_REGISTRY_LOG4J_ROOT_LOGLEVEL
              value: "INFO"
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
          readinessProbe:
            httpGet:
              path: /subjects
              port: 8081
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /subjects
              port: 8081
            initialDelaySeconds: 60
            periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: schema-registry
  namespace: datalyptica-control
  labels:
    app: schema-registry
spec:
  type: ClusterIP
  ports:
    - port: 8081
      targetPort: 8081
      protocol: TCP
      name: http
  selector:
    app: schema-registry
```

Deploy:

```bash
oc apply -f schema-registry.yaml

# Wait for pods
oc wait --for=condition=Ready pod -l app=schema-registry -n datalyptica-control --timeout=300s

# Test Schema Registry
oc exec -n datalyptica-control deployment/schema-registry -- curl -s http://localhost:8081/subjects
```

### 8.5 Deploy Kafka Connect

Kafka Connect for CDC and integrations:

```yaml
# File: kafka-connect.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnect
metadata:
  name: datalyptica-connect
  namespace: datalyptica-control
  annotations:
    strimzi.io/use-connector-resources: "true"
spec:
  version: 3.6.0
  replicas: 2
  bootstrapServers: datalyptica-kafka-kafka-bootstrap:9092

  # Connector plugins
  build:
    output:
      type: docker
      image: image-registry.openshift-image-registry.svc:5000/datalyptica-control/kafka-connect:latest
    plugins:
      - name: debezium-postgres-connector
        artifacts:
          - type: tgz
            url: https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/2.5.0.Final/debezium-connector-postgres-2.5.0.Final-plugin.tar.gz
      - name: confluent-avro-converter
        artifacts:
          - type: zip
            url: https://packages.confluent.io/maven/io/confluent/kafka-connect-avro-converter/7.5.0/kafka-connect-avro-converter-7.5.0.zip

  # Configuration
  config:
    group.id: datalyptica-connect-cluster
    offset.storage.topic: connect-cluster-offsets
    config.storage.topic: connect-cluster-configs
    status.storage.topic: connect-cluster-status
    config.storage.replication.factor: 3
    offset.storage.replication.factor: 3
    status.storage.replication.factor: 3
    key.converter: io.confluent.connect.avro.AvroConverter
    value.converter: io.confluent.connect.avro.AvroConverter
    key.converter.schema.registry.url: http://schema-registry:8081
    value.converter.schema.registry.url: http://schema-registry:8081

  # Resources
  resources:
    requests:
      memory: 2Gi
      cpu: "1"
    limits:
      memory: 4Gi
      cpu: "2"

  # Metrics
  metricsConfig:
    type: jmxPrometheusExporter
    valueFrom:
      configMapKeyRef:
        name: connect-metrics
        key: metrics-config.yml
---
# Metrics ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: connect-metrics
  namespace: datalyptica-control
data:
  metrics-config.yml: |
    lowercaseOutputName: true
    rules:
    - pattern: "kafka.connect<type=connect-worker-metrics>([^:]+):"
      name: "kafka_connect_worker_$1"
    - pattern: "kafka.connect<type=connect-metrics, client-id=([^:]+)><>([^:]+)"
      name: "kafka_connect_$2"
      labels:
        client: "$1"
```

Deploy:

```bash
oc apply -f kafka-connect.yaml

# Wait for KafkaConnect to build and start
oc wait --for=condition=Ready kafkaconnect/datalyptica-connect -n datalyptica-control --timeout=900s

# Check pods
oc get pods -n datalyptica-control -l strimzi.io/cluster=datalyptica-connect
```

---

## 9. Compute Layer Deployment

### 9.1 Deploy Nessie Catalog

Nessie provides git-like data catalog with versioning:

```yaml
# File: nessie-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nessie
  namespace: datalyptica-data
  labels:
    app: nessie
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
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: nessie
                topologyKey: kubernetes.io/hostname
      containers:
        - name: nessie
          image: projectnessie/nessie:0.76.0
          ports:
            - containerPort: 19120
              name: http
            - containerPort: 19443
              name: https
          env:
            - name: QUARKUS_HTTP_PORT
              value: "19120"
            - name: QUARKUS_HTTP_HOST
              value: "0.0.0.0"
            - name: NESSIE_VERSION_STORE_TYPE
              value: "JDBC"
            # PostgreSQL connection
            - name: QUARKUS_DATASOURCE_DB_KIND
              value: "postgresql"
            - name: QUARKUS_DATASOURCE_JDBC_URL
              value: "jdbc:postgresql://postgresql-rw.datalyptica-storage.svc.cluster.local:5432/nessie"
            - name: QUARKUS_DATASOURCE_USERNAME
              value: "datalyptica"
            - name: QUARKUS_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: datalyptica-password
            # Connection pool
            - name: QUARKUS_DATASOURCE_JDBC_INITIAL_SIZE
              value: "10"
            - name: QUARKUS_DATASOURCE_JDBC_MIN_SIZE
              value: "10"
            - name: QUARKUS_DATASOURCE_JDBC_MAX_SIZE
              value: "50"
            # Catalog
            - name: NESSIE_CATALOG_DEFAULT_WAREHOUSE
              value: "warehouse"
            - name: NESSIE_CATALOG_WAREHOUSES_WAREHOUSE_LOCATION
              value: "s3a://lakehouse/warehouse"
            # S3/MinIO
            - name: S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
            - name: S3_REGION
              value: "us-east-1"
            # Metrics
            - name: NESSIE_MICROMETER_ENABLED
              value: "true"
            - name: NESSIE_MICROMETER_EXPORT_PROMETHEUS_ENABLED
              value: "true"
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
          readinessProbe:
            httpGet:
              path: /api/v2/config
              port: 19120
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /api/v2/config
              port: 19120
            initialDelaySeconds: 60
            periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: nessie
  namespace: datalyptica-data
  labels:
    app: nessie
spec:
  type: ClusterIP
  ports:
    - port: 19120
      targetPort: 19120
      protocol: TCP
      name: http
  selector:
    app: nessie
---
# Service for Prometheus metrics
apiVersion: v1
kind: Service
metadata:
  name: nessie-metrics
  namespace: datalyptica-data
  labels:
    app: nessie
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - port: 19120
      targetPort: 19120
      protocol: TCP
      name: metrics
  selector:
    app: nessie
```

Deploy:

```bash
oc apply -f nessie-deployment.yaml

# Wait for pods
oc wait --for=condition=Ready pod -l app=nessie -n datalyptica-data --timeout=300s

# Test Nessie API
oc exec -n datalyptica-data deployment/nessie -- curl -s http://localhost:19120/api/v2/config | jq .
```

### 9.2 Deploy Trino

Trino for interactive SQL queries:

```yaml
# File: trino-coordinator.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino-coordinator
  namespace: datalyptica-data
  labels:
    app: trino
    component: coordinator
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
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: trino
                  component: coordinator
              topologyKey: kubernetes.io/hostname
      containers:
        - name: trino
          image: trinodb/trino:440
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: TRINO_COORDINATOR
              value: "true"
            - name: TRINO_DISCOVERY_URI
              value: "http://trino-coordinator:8080"
            - name: TRINO_QUERY_MAX_MEMORY
              value: "4GB"
            # Iceberg catalog (Nessie)
            - name: TRINO_CATALOG_ICEBERG_CONNECTOR_NAME
              value: "iceberg"
            - name: TRINO_CATALOG_ICEBERG_CATALOG_TYPE
              value: "nessie"
            - name: TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI
              value: "http://nessie:19120/api/v2"
            - name: TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_REF
              value: "main"
            - name: TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_DEFAULT_WAREHOUSE_DIR
              value: "s3a://lakehouse/warehouse"
            # S3/MinIO
            - name: TRINO_CATALOG_ICEBERG_S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: TRINO_CATALOG_ICEBERG_S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: TRINO_CATALOG_ICEBERG_S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
            - name: TRINO_CATALOG_ICEBERG_S3_PATH_STYLE_ACCESS
              value: "true"
          resources:
            requests:
              memory: "4Gi"
              cpu: "2"
            limits:
              memory: "8Gi"
              cpu: "4"
          readinessProbe:
            httpGet:
              path: /v1/info
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /v1/info
              port: 8080
            initialDelaySeconds: 120
            periodSeconds: 30
          volumeMounts:
            - name: trino-config
              mountPath: /etc/trino
      volumes:
        - name: trino-config
          configMap:
            name: trino-config
---
# Trino ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-config
  namespace: datalyptica-data
data:
  config.properties: |
    coordinator=true
    node-scheduler.include-coordinator=false
    http-server.http.port=8080
    discovery.uri=http://trino-coordinator:8080
    query.max-memory=4GB
    query.max-memory-per-node=2GB
  jvm.config: |
    -server
    -Xmx8G
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32M
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:+ExitOnOutOfMemoryError
    -Djdk.attach.allowAttachSelf=true
  node.properties: |
    node.environment=production
    node.data-dir=/data/trino
  log.properties: |
    io.trino=INFO
---
apiVersion: v1
kind: Service
metadata:
  name: trino-coordinator
  namespace: datalyptica-data
  labels:
    app: trino
    component: coordinator
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app: trino
    component: coordinator
```

Deploy Trino Workers:

```yaml
# File: trino-worker.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino-worker
  namespace: datalyptica-data
  labels:
    app: trino
    component: worker
spec:
  replicas: 3
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
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: trino
                    component: worker
                topologyKey: kubernetes.io/hostname
      containers:
        - name: trino
          image: trinodb/trino:440
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: TRINO_COORDINATOR
              value: "false"
            - name: TRINO_DISCOVERY_URI
              value: "http://trino-coordinator:8080"
            # Same Iceberg/S3 config as coordinator
            - name: TRINO_CATALOG_ICEBERG_CONNECTOR_NAME
              value: "iceberg"
            - name: TRINO_CATALOG_ICEBERG_CATALOG_TYPE
              value: "nessie"
            - name: TRINO_CATALOG_ICEBERG_NESSIE_CATALOG_URI
              value: "http://nessie:19120/api/v2"
            - name: TRINO_CATALOG_ICEBERG_S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: TRINO_CATALOG_ICEBERG_S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: TRINO_CATALOG_ICEBERG_S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
            - name: TRINO_CATALOG_ICEBERG_S3_PATH_STYLE_ACCESS
              value: "true"
          resources:
            requests:
              memory: "8Gi"
              cpu: "4"
            limits:
              memory: "16Gi"
              cpu: "8"
          readinessProbe:
            httpGet:
              path: /v1/info
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /v1/info
              port: 8080
            initialDelaySeconds: 120
            periodSeconds: 30
          volumeMounts:
            - name: trino-worker-config
              mountPath: /etc/trino
      volumes:
        - name: trino-worker-config
          configMap:
            name: trino-worker-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-worker-config
  namespace: datalyptica-data
data:
  config.properties: |
    coordinator=false
    http-server.http.port=8080
    discovery.uri=http://trino-coordinator:8080
    query.max-memory=12GB
    query.max-memory-per-node=6GB
  jvm.config: |
    -server
    -Xmx16G
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32M
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:+ExitOnOutOfMemoryError
    -Djdk.attach.allowAttachSelf=true
  node.properties: |
    node.environment=production
    node.data-dir=/data/trino
  log.properties: |
    io.trino=INFO
```

Deploy:

```bash
oc apply -f trino-coordinator.yaml
oc apply -f trino-worker.yaml

# Wait for coordinators
oc wait --for=condition=Ready pod -l app=trino,component=coordinator -n datalyptica-data --timeout=300s

# Wait for workers
oc wait --for=condition=Ready pod -l app=trino,component=worker -n datalyptica-data --timeout=300s

# Test Trino
oc exec -n datalyptica-data deployment/trino-coordinator -- trino --execute "SELECT 1"
```

### 9.3 Deploy Spark

Spark for batch processing:

```yaml
# File: spark-master.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-master
  namespace: datalyptica-data
  labels:
    app: spark
    component: master
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spark
      component: master
  template:
    metadata:
      labels:
        app: spark
        component: master
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: spark
                  component: master
              topologyKey: kubernetes.io/hostname
      containers:
        - name: spark-master
          image: apache/spark:3.5.0-scala2.12-java17-python3
          command: ["/opt/spark/bin/spark-class"]
          args:
            [
              "org.apache.spark.deploy.master.Master",
              "--host",
              "0.0.0.0",
              "--port",
              "7077",
              "--webui-port",
              "8080",
            ]
          ports:
            - containerPort: 7077
              name: spark-master
            - containerPort: 8080
              name: web-ui
          env:
            - name: SPARK_MODE
              value: "master"
            - name: SPARK_MASTER_HOST
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            # Iceberg configuration
            - name: SPARK_ICEBERG_CATALOG_NAME
              value: "nessie"
            - name: SPARK_ICEBERG_URI
              value: "http://nessie:19120/api/v2"
            - name: SPARK_ICEBERG_REF
              value: "main"
            - name: SPARK_ICEBERG_WAREHOUSE
              value: "s3a://lakehouse/warehouse"
            # S3/MinIO
            - name: S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
            - name: S3_REGION
              value: "us-east-1"
          resources:
            requests:
              memory: "2Gi"
              cpu: "1"
            limits:
              memory: "4Gi"
              cpu: "2"
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: 7077
            initialDelaySeconds: 60
            periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: spark-master
  namespace: datalyptica-data
  labels:
    app: spark
    component: master
spec:
  type: ClusterIP
  ports:
    - port: 7077
      targetPort: 7077
      protocol: TCP
      name: spark-master
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: web-ui
  selector:
    app: spark
    component: master
```

Spark Workers:

```yaml
# File: spark-worker.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-worker
  namespace: datalyptica-data
  labels:
    app: spark
    component: worker
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spark
      component: worker
  template:
    metadata:
      labels:
        app: spark
        component: worker
    spec:
      containers:
        - name: spark-worker
          image: apache/spark:3.5.0-scala2.12-java17-python3
          command: ["/opt/spark/bin/spark-class"]
          args:
            [
              "org.apache.spark.deploy.worker.Worker",
              "spark://spark-master:7077",
              "--webui-port",
              "8081",
            ]
          ports:
            - containerPort: 8081
              name: web-ui
          env:
            - name: SPARK_MODE
              value: "worker"
            - name: SPARK_MASTER_URL
              value: "spark://spark-master:7077"
            - name: SPARK_WORKER_MEMORY
              value: "8G"
            - name: SPARK_WORKER_CORES
              value: "4"
            # Same Iceberg/S3 config
            - name: SPARK_ICEBERG_CATALOG_NAME
              value: "nessie"
            - name: SPARK_ICEBERG_URI
              value: "http://nessie:19120/api/v2"
            - name: S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
          resources:
            requests:
              memory: "8Gi"
              cpu: "4"
            limits:
              memory: "16Gi"
              cpu: "8"
          readinessProbe:
            httpGet:
              path: /
              port: 8081
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 8081
            initialDelaySeconds: 60
            periodSeconds: 30
```

Deploy:

```bash
oc apply -f spark-master.yaml
oc apply -f spark-worker.yaml

# Wait for master
oc wait --for=condition=Ready pod -l app=spark,component=master -n datalyptica-data --timeout=300s

# Wait for workers
oc wait --for=condition=Ready pod -l app=spark,component=worker -n datalyptica-data --timeout=300s

# Test Spark
oc exec -n datalyptica-data deployment/spark-master -- /opt/spark/bin/spark-submit --version
```

### 9.4 Deploy Flink

Flink for stream processing:

```yaml
# File: flink-jobmanager.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flink-jobmanager
  namespace: datalyptica-data
  labels:
    app: flink
    component: jobmanager
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flink
      component: jobmanager
  template:
    metadata:
      labels:
        app: flink
        component: jobmanager
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: flink
                  component: jobmanager
              topologyKey: kubernetes.io/hostname
      containers:
        - name: jobmanager
          image: flink:1.18.0-scala_2.12-java11
          command: ["/docker-entrypoint.sh"]
          args: ["jobmanager"]
          ports:
            - containerPort: 8081
              name: web-ui
            - containerPort: 6123
              name: rpc
          env:
            - name: JOB_MANAGER_RPC_ADDRESS
              value: "flink-jobmanager"
            - name: KAFKA_BOOTSTRAP_SERVERS
              value: "datalyptica-kafka-kafka-bootstrap.datalyptica-control.svc.cluster.local:9092"
            - name: NESSIE_URI
              value: "http://nessie:19120/api/v2"
            - name: WAREHOUSE_LOCATION
              value: "s3a://lakehouse/warehouse"
            - name: S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
          resources:
            requests:
              memory: "2Gi"
              cpu: "1"
            limits:
              memory: "4Gi"
              cpu: "2"
          readinessProbe:
            httpGet:
              path: /overview
              port: 8081
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /overview
              port: 8081
            initialDelaySeconds: 60
            periodSeconds: 30
          volumeMounts:
            - name: checkpoints
              mountPath: /opt/flink/checkpoints
            - name: savepoints
              mountPath: /opt/flink/savepoints
      volumes:
        - name: checkpoints
          persistentVolumeClaim:
            claimName: flink-checkpoints
        - name: savepoints
          persistentVolumeClaim:
            claimName: flink-savepoints
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: flink-checkpoints
  namespace: datalyptica-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: flink-savepoints
  namespace: datalyptica-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: Service
metadata:
  name: flink-jobmanager
  namespace: datalyptica-data
  labels:
    app: flink
    component: jobmanager
spec:
  type: ClusterIP
  ports:
    - port: 8081
      targetPort: 8081
      protocol: TCP
      name: web-ui
    - port: 6123
      targetPort: 6123
      protocol: TCP
      name: rpc
  selector:
    app: flink
    component: jobmanager
```

Flink TaskManagers:

```yaml
# File: flink-taskmanager.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flink-taskmanager
  namespace: datalyptica-data
  labels:
    app: flink
    component: taskmanager
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flink
      component: taskmanager
  template:
    metadata:
      labels:
        app: flink
        component: taskmanager
    spec:
      containers:
        - name: taskmanager
          image: flink:1.18.0-scala_2.12-java11
          command: ["/docker-entrypoint.sh"]
          args: ["taskmanager"]
          env:
            - name: JOB_MANAGER_RPC_ADDRESS
              value: "flink-jobmanager"
            - name: TASK_MANAGER_NUMBER_OF_TASK_SLOTS
              value: "4"
            - name: KAFKA_BOOTSTRAP_SERVERS
              value: "datalyptica-kafka-kafka-bootstrap.datalyptica-control.svc.cluster.local:9092"
            - name: NESSIE_URI
              value: "http://nessie:19120/api/v2"
            - name: S3_ENDPOINT
              value: "http://minio.datalyptica-storage.svc.cluster.local:9000"
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
          resources:
            requests:
              memory: "4Gi"
              cpu: "2"
            limits:
              memory: "8Gi"
              cpu: "4"
          volumeMounts:
            - name: checkpoints
              mountPath: /opt/flink/checkpoints
            - name: savepoints
              mountPath: /opt/flink/savepoints
      volumes:
        - name: checkpoints
          persistentVolumeClaim:
            claimName: flink-checkpoints
        - name: savepoints
          persistentVolumeClaim:
            claimName: flink-savepoints
```

Deploy:

```bash
oc apply -f flink-jobmanager.yaml
oc apply -f flink-taskmanager.yaml

# Wait for JobManager
oc wait --for=condition=Ready pod -l app=flink,component=jobmanager -n datalyptica-data --timeout=300s

# Wait for TaskManagers
oc wait --for=condition=Ready pod -l app=flink,component=taskmanager -n datalyptica-data --timeout=300s

# Test Flink
oc exec -n datalyptica-data deployment/flink-jobmanager -- flink --version
```

### 9.5 Deploy ClickHouse

ClickHouse for OLAP queries:

```yaml
# File: clickhouse.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: clickhouse
  namespace: datalyptica-data
  labels:
    app: clickhouse
spec:
  serviceName: clickhouse
  replicas: 3
  selector:
    matchLabels:
      app: clickhouse
  template:
    metadata:
      labels:
        app: clickhouse
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: clickhouse
              topologyKey: kubernetes.io/hostname
      containers:
        - name: clickhouse
          image: clickhouse/clickhouse-server:24-alpine
          ports:
            - containerPort: 8123
              name: http
            - containerPort: 9000
              name: native
            - containerPort: 9009
              name: interserver
          env:
            - name: CLICKHOUSE_DB
              value: "default"
            - name: CLICKHOUSE_USER
              value: "default"
            - name: CLICKHOUSE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: clickhouse-credentials
                  key: password
            - name: CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT
              value: "1"
          resources:
            requests:
              memory: "4Gi"
              cpu: "2"
            limits:
              memory: "8Gi"
              cpu: "4"
          readinessProbe:
            httpGet:
              path: /ping
              port: 8123
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /ping
              port: 8123
            initialDelaySeconds: 60
            periodSeconds: 30
          volumeMounts:
            - name: data
              mountPath: /var/lib/clickhouse
            - name: logs
              mountPath: /var/log/clickhouse-server
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 500Gi
    - metadata:
        name: logs
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: clickhouse
  namespace: datalyptica-data
  labels:
    app: clickhouse
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - port: 8123
      targetPort: 8123
      protocol: TCP
      name: http
    - port: 9000
      targetPort: 9000
      protocol: TCP
      name: native
  selector:
    app: clickhouse
---
apiVersion: v1
kind: Service
metadata:
  name: clickhouse-client
  namespace: datalyptica-data
  labels:
    app: clickhouse
spec:
  type: ClusterIP
  ports:
    - port: 8123
      targetPort: 8123
      protocol: TCP
      name: http
    - port: 9000
      targetPort: 9000
      protocol: TCP
      name: native
  selector:
    app: clickhouse
```

Deploy:

```bash
oc apply -f clickhouse.yaml

# Wait for StatefulSet
oc wait --for=condition=Ready pod -l app=clickhouse -n datalyptica-data --timeout=600s

# Test ClickHouse
oc exec -n datalyptica-data clickhouse-0 -- clickhouse-client --query "SELECT 1"
```

---

This concludes Part 2 of the OpenShift deployment guide. Would you like me to continue with Part 3, which will cover:

- Observability Stack (Prometheus, Grafana, Loki, Alertmanager)
- Keycloak IAM deployment
- Network Policies and Security
- Routes and Ingress
- Validation procedures
- Operational runbooks
- Monitoring and alerting configuration
- Backup and DR procedures
- Troubleshooting guides
- Complete deployment scripts

Shall I proceed with Part 3?
