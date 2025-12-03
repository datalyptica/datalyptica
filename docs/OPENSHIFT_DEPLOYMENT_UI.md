# OpenShift Deployment Guide - Web Console UI Method

**Platform**: Red Hat OpenShift 4.17+  
**Version**: Datalyptica 4.0.0  
**Method**: Web Console (Browser-based UI)  
**Prerequisites**: OpenShift cluster access with admin privileges

---

## Table of Contents

1. [Accessing OpenShift Web Console](#accessing-openshift-web-console)
2. [Pre-Deployment Setup](#pre-deployment-setup)
3. [Phase 1: Install Operators](#phase-1-install-operators)
4. [Phase 2: Create Projects](#phase-2-create-projects)
5. [Phase 3: Configure Storage](#phase-3-configure-storage)
6. [Phase 4: Deploy Storage Services](#phase-4-deploy-storage-services)
7. [Phase 5: Deploy Catalog Services](#phase-5-deploy-catalog-services)
8. [Phase 6: Deploy Streaming Services](#phase-6-deploy-streaming-services)
9. [Phase 7: Deploy Processing Services](#phase-7-deploy-processing-services)
10. [Phase 8: Deploy Analytics Services](#phase-8-deploy-analytics-services)
11. [Phase 9: Deploy Monitoring Services](#phase-9-deploy-monitoring-services)
12. [Phase 10: Deploy IAM Services](#phase-10-deploy-iam-services)
13. [Verification & Access](#verification--access)
14. [UI Navigation Guide](#ui-navigation-guide)

---

## Accessing OpenShift Web Console

### 1. Login to Web Console

1. **Open Browser** and navigate to your OpenShift cluster URL:
   ```
   https://console-openshift-console.apps.your-cluster.example.com
   ```

2. **Select Authentication Method**:
   - Click on your identity provider (e.g., LDAP, OAuth, htpasswd)
   - Enter your username and password
   - Click **Log in**

3. **Verify Access**:
   - You should see the OpenShift web console dashboard
   - Check that you're in the **Administrator** perspective (top-left dropdown)

### 2. Switch to Administrator Perspective

If you're in Developer perspective:
1. Click the **perspective switcher** (top-left corner)
2. Select **Administrator**

---

## Pre-Deployment Setup

### 1. Create Security Context Constraints (SCC)

1. **Navigate to User Management**:
   - Left sidebar → **User Management** → **RoleBindings**

2. **Create Custom SCC**:
   - Click **Create** → **From YAML**
   - Paste the following YAML:

```yaml
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
```

3. **Click Create**

### 2. Create Storage Classes

1. **Navigate to Storage**:
   - Left sidebar → **Storage** → **StorageClasses**

2. **Create Fast Storage Class**:
   - Click **Create StorageClass**
   - **Name**: `datalyptica-fast`
   - **Provisioner**: Select your cloud provider (e.g., `kubernetes.io/aws-ebs`)
   - **Parameters**:
     - `type`: `gp3`
     - `iops`: `3000`
     - `throughput`: `125`
     - `fsType`: `ext4`
   - **Reclaim Policy**: `Retain`
   - **Volume Binding Mode**: `WaitForFirstConsumer`
   - **Allow Volume Expansion**: ✅ Check
   - Click **Create**

3. **Create Standard Storage Class**:
   - Repeat above steps with:
     - **Name**: `datalyptica-standard`
     - **Parameters** → `iops`: `1000`
   - Click **Create**

---

## Phase 1: Install Operators

### 1.1 Install Strimzi Kafka Operator

1. **Navigate to OperatorHub**:
   - Left sidebar → **Operators** → **OperatorHub**

2. **Search for Strimzi**:
   - In search box, type: `Strimzi`
   - Click on **Strimzi** tile

3. **Install Operator**:
   - Click **Install**
   - **Installation Mode**: Select `A specific namespace on the cluster`
   - **Installed Namespace**: Create new namespace `datalyptica-operators`
   - **Update Channel**: `stable`
   - **Approval Strategy**: `Automatic`
   - Click **Install**

4. **Wait for Installation**:
   - Click **View Operator** when ready
   - Verify **Status** shows `Succeeded`

### 1.2 Install Crunchy PostgreSQL Operator

1. **Navigate to OperatorHub**:
   - Left sidebar → **Operators** → **OperatorHub**

2. **Search for PostgreSQL**:
   - Type: `Crunchy PostgreSQL`
   - Click on **Crunchy Postgres for Kubernetes** tile

3. **Install Operator**:
   - Click **Install**
   - **Installation Mode**: `A specific namespace on the cluster`
   - **Installed Namespace**: Select `datalyptica-operators`
   - **Update Channel**: `v5`
   - **Approval Strategy**: `Automatic`
   - Click **Install**

4. **Verify Installation**:
   - Wait for status to show `Succeeded`

### 1.3 Install Flink Kubernetes Operator

**Note**: Flink operator may need to be installed via Helm or YAML (not always available in OperatorHub)

1. **Navigate to Import YAML**:
   - Top-right → **+** (Import YAML) button

2. **Deploy Flink Operator** (if not in OperatorHub):
   - You'll need to use CLI for Helm installation
   - See CLI guide for Flink operator installation

---

## Phase 2: Create Projects

1. **Navigate to Projects**:
   - Left sidebar → **Home** → **Projects**

2. **Create Projects** (repeat for each):
   - Click **Create Project**
   - **Name**: Enter project name
   - **Display Name**: (optional) User-friendly name
   - **Description**: (optional) Project purpose
   - Click **Create**

**Required Projects**:
- `datalyptica-operators` (if not created during operator install)
- `datalyptica-storage`
- `datalyptica-catalog`
- `datalyptica-streaming`
- `datalyptica-processing`
- `datalyptica-query`
- `datalyptica-analytics`
- `datalyptica-monitoring`
- `datalyptica-iam`

---

## Phase 3: Configure Storage

### Create Secrets for Credentials

1. **Navigate to Secrets**:
   - Left sidebar → **Workloads** → **Secrets**
   - **Project**: Select `datalyptica-storage` from top dropdown

2. **Create PostgreSQL Secret**:
   - Click **Create** → **Key/Value Secret**
   - **Secret Name**: `postgres-credentials`
   - **Key**: `password`
   - **Value**: Generate strong password (e.g., use password generator)
   - Click **Create**

3. **Create MinIO Secret**:
   - Click **Create** → **Key/Value Secret**
   - **Secret Name**: `minio-credentials`
   - **Key**: `root-password`
   - **Value**: Generate strong password
   - Click **Create**

4. **Repeat for other namespaces**:
   - Switch to `datalyptica-iam` project
   - Create `keycloak-credentials` secret
   - Switch to `datalyptica-monitoring` project
   - Create `grafana-credentials` secret

---

## Phase 4: Deploy Storage Services

### 4.1 Deploy MinIO Object Storage

1. **Navigate to Deployments**:
   - Left sidebar → **Workloads** → **Deployments**
   - **Project**: Select `datalyptica-storage`

2. **Create PVC First**:
   - Left sidebar → **Storage** → **PersistentVolumeClaims**
   - Click **Create PersistentVolumeClaim**
   - **Name**: `minio-data`
   - **Storage Class**: `datalyptica-standard`
   - **Access Mode**: `Single User (RWO)`
   - **Size**: `500 GiB`
   - Click **Create**

3. **Create MinIO Deployment**:
   - Go to **Workloads** → **Deployments**
   - Click **Create Deployment**
   - Click **Edit YAML** and paste:

```yaml
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
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-data
```

4. **Create MinIO Service**:
   - Left sidebar → **Networking** → **Services**
   - Click **Create Service**
   - Click **Edit YAML** and paste:

```yaml
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
```

5. **Create Route for MinIO Console**:
   - Left sidebar → **Networking** → **Routes**
   - Click **Create Route**
   - **Name**: `minio-console`
   - **Service**: `minio`
   - **Target Port**: `9001 → console`
   - **Security**: ✅ Check **Secure Route**
   - **TLS Termination**: `Edge`
   - Click **Create**

6. **Verify MinIO is Running**:
   - Go to **Workloads** → **Pods**
   - Find pod starting with `minio-`
   - Status should be **Running**
   - Click on pod → **Logs** tab to check startup

### 4.2 Deploy PostgreSQL (Using Crunchy Operator)

1. **Navigate to Installed Operators**:
   - Left sidebar → **Operators** → **Installed Operators**
   - **Project**: Select `datalyptica-storage`
   - Click on **Crunchy Postgres for Kubernetes**

2. **Create PostgreSQL Cluster**:
   - Click **PostgresCluster** tab
   - Click **Create PostgresCluster**
   - Click **YAML view** and paste:

```yaml
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
```

3. **Click Create**

4. **Monitor Progress**:
   - Go to **Workloads** → **Pods**
   - Wait for all PostgreSQL pods to show **Running**
   - This may take 3-5 minutes

---

## Phase 5: Deploy Catalog Services

### 5.1 Deploy Redis

1. **Switch Project**:
   - Top dropdown → Select `datalyptica-catalog`

2. **Create ConfigMap**:
   - Left sidebar → **Workloads** → **ConfigMaps**
   - Click **Create ConfigMap**
   - **Name**: `redis-config`
   - **Key**: `redis.conf`
   - **Value**: 
```
maxmemory 2gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
```
   - Click **Create**

3. **Create PVC**:
   - **Storage** → **PersistentVolumeClaims**
   - Click **Create PersistentVolumeClaim**
   - **Name**: `redis-data`
   - **Storage Class**: `datalyptica-fast`
   - **Access Mode**: `Single User (RWO)`
   - **Size**: `20 GiB`
   - Click **Create**

4. **Create StatefulSet**:
   - **Workloads** → **StatefulSets**
   - Click **Create StatefulSet**
   - Switch to **YAML view** and paste:

```yaml
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
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: redis-data
      - name: config
        configMap:
          name: redis-config
```

5. **Create Service**:
   - **Networking** → **Services**
   - Click **Create Service**
   - Paste YAML:

```yaml
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
  selector:
    app: redis
```

### 5.2 Deploy Nessie

1. **Create Deployment**:
   - **Workloads** → **Deployments**
   - Click **Create Deployment**
   - Paste YAML:

```yaml
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
```

2. **Create Service**:
   - **Networking** → **Services**
   - Create service with port 19120

---

## Phase 6: Deploy Streaming Services

### 6.1 Deploy Kafka (Using Strimzi Operator)

1. **Switch Project**:
   - Select `datalyptica-streaming`

2. **Navigate to Strimzi Operator**:
   - **Operators** → **Installed Operators**
   - Click **Strimzi**

3. **Create Kafka Cluster**:
   - Click **Kafka** tab
   - Click **Create Kafka**
   - Switch to **YAML view** and paste:

```yaml
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
    topicOperator: {}
    userOperator: {}
```

4. **Click Create**

5. **Monitor Kafka Deployment**:
   - Go to **Workloads** → **Pods**
   - Wait for all Kafka and ZooKeeper pods to be **Running**
   - This may take 5-10 minutes

---

## Phase 7: Deploy Processing Services

### 7.1 Deploy Spark

1. **Switch Project**:
   - Select `datalyptica-processing`

2. **Create Spark Master Deployment**:
   - **Workloads** → **Deployments**
   - Click **Create Deployment**
   - Use YAML from CLI guide for Spark master

3. **Create Spark Worker Deployment**:
   - Create another deployment for Spark workers
   - Set replicas to 3

4. **Create Services**:
   - Create service for Spark master (ports 7077, 8080)

### 7.2 Deploy Trino

1. **Create ConfigMap**:
   - **Workloads** → **ConfigMaps**
   - Create `trino-config` with catalog configurations

2. **Create Deployment**:
   - **Workloads** → **Deployments**
   - Create Trino deployment with 3 replicas
   - Image: `trinodb/trino:478`

3. **Create Service**:
   - Port 8080 for Trino UI and queries

---

## Phase 8: Deploy Analytics Services

### 8.1 Deploy Apache Airflow

1. **Switch Project**:
   - Select `datalyptica-analytics`

2. **Create ConfigMap**:
   - Create `airflow-config` with environment variables

3. **Create Webserver Deployment**:
   - Image: `apache/airflow:3.1.3-python3.11`
   - Command: `airflow webserver`
   - Port: 8080

4. **Create Scheduler Deployment**:
   - Same image
   - Command: `airflow scheduler`

5. **Create Service and Route**:
   - Service on port 8080
   - Create Route for external access

### 8.2 Deploy MLflow

1. **Create Deployment**:
   - Image: `ghcr.io/mlflow/mlflow:v3.6.0`
   - Port: 5000

2. **Create Service and Route**:
   - Expose port 5000
   - Create route for MLflow UI

### 8.3 Deploy Superset

1. **Create Deployment**:
   - Image: `apache/superset:5.0.0`
   - Port: 8088

2. **Create Service and Route**:
   - Expose port 8088

### 8.4 Deploy JupyterHub

1. **Create Deployment**:
   - Image: `jupyterhub/jupyterhub:5.4.2`
   - Port: 8000

2. **Create Service and Route**:
   - Expose port 8000

---

## Phase 9: Deploy Monitoring Services

### 9.1 Deploy Prometheus

1. **Switch Project**:
   - Select `datalyptica-monitoring`

2. **Create ConfigMap**:
   - **Workloads** → **ConfigMaps**
   - Name: `prometheus-config`
   - Upload your `prometheus.yml` and `alerts.yml` files

3. **Create PVC**:
   - Name: `prometheus-data`
   - Size: 50GiB
   - Storage class: `datalyptica-standard`

4. **Create Deployment**:
   - Image: `prom/prometheus:v3.8.0`
   - Port: 9090
   - Mount ConfigMap and PVC

5. **Create Service and Route**:
   - Service on port 9090
   - Create Route with TLS

### 9.2 Deploy Grafana

1. **Create ConfigMaps**:
   - `grafana-datasources` - Upload datasource YAML files

2. **Create Secret**:
   - Name: `grafana-credentials`
   - Key: `admin-password`
   - Value: Strong password

3. **Create PVC**:
   - Name: `grafana-data`
   - Size: 10GiB

4. **Create Deployment**:
   - Image: `grafana/grafana:12.3.0`
   - Port: 3000
   - Mount PVC and ConfigMaps

5. **Create Service and Route**:
   - Service on port 3000
   - Create Route with TLS

### 9.3 Deploy Loki

1. **Create ConfigMap**:
   - Upload `loki-config.yml`

2. **Create PVC**:
   - Name: `loki-data`
   - Size: 50GiB

3. **Create Deployment**:
   - Image: `grafana/loki:3.6.2`
   - Port: 3100

4. **Create Service**:
   - Internal service on port 3100

---

## Phase 10: Deploy IAM Services

### 10.1 Deploy Keycloak

1. **Switch Project**:
   - Select `datalyptica-iam`

2. **Create Secret** (if not already created):
   - Name: `keycloak-credentials`
   - Key: `admin-password`

3. **Create Deployment**:
   - **Workloads** → **Deployments**
   - Click **Create Deployment**
   - Paste YAML:

```yaml
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
```

4. **Create Service**:
   - Port: 8080

5. **Create Route**:
   - **Networking** → **Routes**
   - Create route with TLS termination

---

## Verification & Access

### Check All Deployments

1. **Navigate to Workloads** → **Pods**
2. **Select All Projects** from dropdown
3. **Filter** by `datalyptica-` to see all pods
4. **Verify** all pods show **Running** status

### Access Services via Routes

1. **Navigate to Networking** → **Routes**
2. **Select All Projects**
3. **Click on Location URL** for each route:
   - MinIO Console
   - Grafana Dashboard
   - Airflow Web UI
   - MLflow UI
   - Superset
   - JupyterHub
   - Keycloak Admin Console
   - Prometheus UI

### View Logs

1. **Go to Pod**:
   - **Workloads** → **Pods**
   - Click on pod name

2. **View Logs**:
   - Click **Logs** tab
   - Use search box to filter logs
   - Toggle **Follow** to stream logs in real-time

### Monitor Resources

1. **Navigate to Observe** → **Dashboards**
2. **Select Project** from dropdown
3. **View Metrics**:
   - CPU Usage
   - Memory Usage
   - Network I/O
   - Storage Usage

---

## UI Navigation Guide

### Quick Navigation Tips

**Left Sidebar Sections**:
- **Home**: Projects, Search, Events, Status
- **Operators**: OperatorHub, Installed Operators
- **Workloads**: Pods, Deployments, StatefulSets, Jobs, CronJobs
- **Networking**: Services, Routes, Ingresses, Network Policies
- **Storage**: PersistentVolumeClaims, PersistentVolumes, StorageClasses
- **Builds**: BuildConfigs, Builds, ImageStreams
- **Pipelines**: Pipelines, Pipeline Runs, Tasks
- **Observe**: Alerting, Metrics, Dashboards, Logging
- **Compute**: Nodes, Machine Sets, Machines
- **User Management**: Users, Groups, ServiceAccounts, RoleBindings
- **Administration**: Cluster Settings, Namespaces, Custom Resource Definitions

### Useful Shortcuts

- **Search**: Top search bar - find any resource by name
- **Import YAML**: **+** button (top-right) - paste YAML directly
- **Project Selector**: Top dropdown - switch between projects quickly
- **Perspective Switcher**: Top-left - switch between Administrator/Developer views
- **Help**: **?** button (top-right) - documentation and quick start guides
- **User Menu**: Top-right avatar - logout, preferences

### Common Tasks

**View All Resources in Project**:
1. Select project from dropdown
2. Left sidebar → **Home** → **Search**
3. Select **Resources** → **All**

**Monitor Pod Status**:
1. **Workloads** → **Pods**
2. Click pod name
3. View **Details**, **Metrics**, **Logs**, **Terminal**, **Events**, **YAML**

**Edit Resource**:
1. Find resource (Deployment, Service, etc.)
2. Click resource name
3. Click **Actions** → **Edit [Resource]**
4. Or click **YAML** tab to edit directly

**Scale Deployment**:
1. **Workloads** → **Deployments**
2. Click deployment name
3. Click **Actions** → **Edit Pod Count**
4. Set desired replicas
5. Click **Save**

**Create Route**:
1. **Networking** → **Routes**
2. Click **Create Route**
3. Fill in: Name, Service, Target Port
4. Check **Secure Route** for HTTPS
5. Click **Create**

---

## Troubleshooting in UI

### Pod Issues

**Pod Not Starting**:
1. Go to **Workloads** → **Pods**
2. Click on problematic pod
3. Check **Events** tab for errors
4. Check **Logs** tab for container errors
5. Check **YAML** tab for configuration issues

**ImagePullBackOff**:
1. Check image name and tag in pod YAML
2. Verify image exists and is accessible
3. Check if image pull secrets are configured

**CrashLoopBackOff**:
1. View pod **Logs** tab
2. Look for application errors
3. Check **Events** tab for details
4. Verify resource limits aren't too low

### Storage Issues

**PVC Pending**:
1. **Storage** → **PersistentVolumeClaims**
2. Click PVC name
3. Check **Events** tab
4. Verify StorageClass exists and is correct
5. Check if volume binding mode is correct

### Network Issues

**Service Not Accessible**:
1. **Networking** → **Services**
2. Verify service selector matches pod labels
3. Check endpoints: Click service → **Pods** tab
4. Verify target port matches container port

**Route Not Working**:
1. **Networking** → **Routes**
2. Verify service exists and is healthy
3. Check TLS termination settings
4. Verify target port is correct

---

## Next Steps After Deployment

1. **Configure Monitoring Dashboards**:
   - Login to Grafana
   - Import pre-built dashboards
   - Configure alerts

2. **Set Up Data Pipelines**:
   - Access Airflow UI
   - Create DAGs
   - Schedule jobs

3. **Configure Security**:
   - Set up Keycloak realms
   - Configure RBAC
   - Enable TLS everywhere

4. **Performance Tuning**:
   - Monitor resource usage
   - Adjust replica counts
   - Scale up/down as needed

5. **Backup Configuration**:
   - Set up automated backups
   - Test restore procedures

---

## Additional Resources

- **OpenShift Web Console Guide**: https://docs.openshift.com/container-platform/4.17/web_console/web-console.html
- **Component Versions**: `/deploy/openshift/docs/COMPONENT-VERSIONS.md`
- **CLI Guide**: `/docs/OPENSHIFT_DEPLOYMENT_CLI.md`
- **Troubleshooting**: `/archive/TROUBLESHOOTING.md`

---

**Congratulations!** 🎉

You've successfully deployed the Datalyptica platform using the OpenShift Web Console. All services are now accessible via their respective routes.
