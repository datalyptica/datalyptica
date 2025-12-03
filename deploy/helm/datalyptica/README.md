# Datalyptica Helm Chart

A comprehensive Helm chart for deploying the Datalyptica Data Platform on Kubernetes.

## Introduction

This chart bootstraps a complete data platform deployment on a Kubernetes cluster using the Helm package manager. It includes:

- **Core Services**: PostgreSQL, Redis, MinIO, Nessie
- **Processing Engines**: Trino, Flink, Spark
- **Streaming**: Kafka + Schema Registry
- **Analytics**: ClickHouse
- **Orchestration**: Apache Airflow
- **Visualization**: Apache Superset
- **Monitoring** (optional): Prometheus, Grafana

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+
- PV provisioner support in the underlying infrastructure (for persistence)
- 16GB+ RAM recommended for full deployment
- StorageClass configured for dynamic provisioning

## Installing the Chart

### Quick Start

```bash
# Install with default configuration
helm install datalyptica ./deploy/helm/datalyptica

# Install in a specific namespace
helm install datalyptica ./deploy/helm/datalyptica -n datalyptica --create-namespace

# Install with custom values
helm install datalyptica ./deploy/helm/datalyptica -f my-values.yaml
```

### Minimal Installation (Core Services Only)

```bash
cat <<EOF > minimal-values.yaml
# Enable only core services
trino:
  enabled: false
flink:
  enabled: false
kafka:
  enabled: false
spark:
  enabled: false
clickhouse:
  enabled: false
airflow:
  enabled: false
superset:
  enabled: false
EOF

helm install datalyptica ./deploy/helm/datalyptica -f minimal-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall datalyptica

# Also delete the namespaces if desired
kubectl delete namespace datalyptica-core datalyptica-apps datalyptica-monitoring
```

## Configuration

The following table lists the configurable parameters of the Datalyptica chart and their default values.

### Global Parameters

| Parameter                | Description                     | Default        |
| ------------------------ | ------------------------------- | -------------- |
| `global.imageRegistry`   | Global Docker image registry    | `""`           |
| `global.imagePullPolicy` | Global Docker image pull policy | `IfNotPresent` |
| `global.storageClass`    | Global storage class for PVC    | `standard`     |

### Namespace Configuration

| Parameter               | Description                        | Default                  |
| ----------------------- | ---------------------------------- | ------------------------ |
| `namespaces.core`       | Namespace for core services        | `datalyptica-core`       |
| `namespaces.apps`       | Namespace for application services | `datalyptica-apps`       |
| `namespaces.monitoring` | Namespace for monitoring stack     | `datalyptica-monitoring` |

### PostgreSQL

| Parameter                          | Description                                         | Default     |
| ---------------------------------- | --------------------------------------------------- | ----------- |
| `postgresql.enabled`               | Enable PostgreSQL                                   | `true`      |
| `postgresql.image.repository`      | PostgreSQL image repository                         | `postgres`  |
| `postgresql.image.tag`             | PostgreSQL image tag                                | `15-alpine` |
| `postgresql.replicas`              | Number of replicas                                  | `1`         |
| `postgresql.auth.postgresPassword` | PostgreSQL admin password (auto-generated if empty) | `""`        |
| `postgresql.persistence.enabled`   | Enable persistence                                  | `true`      |
| `postgresql.persistence.size`      | PVC size                                            | `10Gi`      |

### Redis

| Parameter                | Description                              | Default    |
| ------------------------ | ---------------------------------------- | ---------- |
| `redis.enabled`          | Enable Redis                             | `true`     |
| `redis.image.repository` | Redis image repository                   | `redis`    |
| `redis.image.tag`        | Redis image tag                          | `7-alpine` |
| `redis.auth.password`    | Redis password (auto-generated if empty) | `""`       |
| `redis.persistence.size` | PVC size                                 | `5Gi`      |

### MinIO

| Parameter                 | Description                                   | Default       |
| ------------------------- | --------------------------------------------- | ------------- |
| `minio.enabled`           | Enable MinIO                                  | `true`        |
| `minio.image.repository`  | MinIO image repository                        | `minio/minio` |
| `minio.image.tag`         | MinIO image tag                               | `latest`      |
| `minio.auth.rootUser`     | MinIO root user                               | `admin`       |
| `minio.auth.rootPassword` | MinIO root password (auto-generated if empty) | `""`          |
| `minio.persistence.size`  | PVC size                                      | `50Gi`        |

### Trino

| Parameter                    | Description          | Default |
| ---------------------------- | -------------------- | ------- |
| `trino.enabled`              | Enable Trino         | `true`  |
| `trino.coordinator.replicas` | Coordinator replicas | `1`     |
| `trino.worker.replicas`      | Worker replicas      | `2`     |

### Airflow

| Parameter                    | Description           | Default          |
| ---------------------------- | --------------------- | ---------------- |
| `airflow.enabled`            | Enable Airflow        | `true`           |
| `airflow.executor`           | Airflow executor type | `CeleryExecutor` |
| `airflow.webserver.replicas` | Webserver replicas    | `1`              |
| `airflow.scheduler.replicas` | Scheduler replicas    | `1`              |
| `airflow.worker.replicas`    | Worker replicas       | `2`              |

For a complete list of parameters, see `values.yaml`.

## Examples

### Custom Storage Classes

```yaml
global:
  storageClass: "fast-ssd"

postgresql:
  persistence:
    size: 100Gi

minio:
  persistence:
    size: 1Ti
```

### Scaling Workers

```yaml
trino:
  worker:
    replicas: 5
    resources:
      requests:
        memory: 8Gi
        cpu: 4

spark:
  worker:
    replicas: 10
    memory: 8g
    cores: 4
```

### Enable Monitoring

```yaml
prometheus:
  enabled: true
  persistence:
    size: 50Gi

grafana:
  enabled: true
  auth:
    adminPassword: "your-secure-password"
```

### Custom Image Registry

```yaml
global:
  imageRegistry: "myregistry.example.com"
  imagePullPolicy: Always
```

## Persistence

By default, all stateful services use persistent volumes. To disable persistence for a service:

```yaml
postgresql:
  persistence:
    enabled: false
```

**Warning**: Disabling persistence will result in data loss on pod restart.

## Security

### Passwords

All passwords are auto-generated if not provided. To set custom passwords:

```yaml
postgresql:
  auth:
    postgresPassword: "custom-postgres-password"
    airflowPassword: "custom-airflow-password"

redis:
  auth:
    password: "custom-redis-password"

minio:
  auth:
    rootPassword: "custom-minio-password"
```

### Security Contexts

All pods run with non-root users by default for OpenShift compatibility. To customize:

```yaml
postgresql:
  securityContext:
    runAsNonRoot: true
    runAsUser: 999
    fsGroup: 999
```

## Accessing Services

After installation, use `kubectl port-forward` to access services:

```bash
# PostgreSQL
kubectl port-forward -n datalyptica-core svc/postgresql 5432:5432

# MinIO Console
kubectl port-forward -n datalyptica-core svc/minio 9001:9001

# Trino UI
kubectl port-forward -n datalyptica-apps svc/trino-coordinator 8080:8080

# Airflow UI
kubectl port-forward -n datalyptica-apps svc/airflow-webserver 8082:8082

# Superset UI
kubectl port-forward -n datalyptica-apps svc/superset 8088:8088
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade datalyptica ./deploy/helm/datalyptica -f new-values.yaml

# View upgrade history
helm history datalyptica

# Rollback to previous version
helm rollback datalyptica
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n datalyptica-core
kubectl get pods -n datalyptica-apps
```

### View Logs

```bash
kubectl logs -n datalyptica-core <pod-name>
kubectl logs -n datalyptica-core <pod-name> -c <container-name>
```

### Retrieve Secrets

```bash
# PostgreSQL password
kubectl get secret -n datalyptica-core postgresql-credentials -o jsonpath='{.data.postgres-password}' | base64 -d

# MinIO root password
kubectl get secret -n datalyptica-core minio-credentials -o jsonpath='{.data.root-password}' | base64 -d

# Redis password
kubectl get secret -n datalyptica-core redis-credentials -o jsonpath='{.data.password}' | base64 -d
```

### Pod Not Starting

Check events and describe the pod:

```bash
kubectl describe pod -n datalyptica-core <pod-name>
kubectl get events -n datalyptica-core --sort-by='.lastTimestamp'
```

### PVC Issues

Check PVC status:

```bash
kubectl get pvc -n datalyptica-core
kubectl describe pvc -n datalyptica-core <pvc-name>
```

## License

Apache 2.0 License

## Support

For issues and questions, please open a GitHub issue at https://github.com/yourusername/datalyptica
