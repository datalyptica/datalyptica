# Kubernetes/Helm Quick Reference

## Installation Commands

### Prerequisites

```bash
# Install kubectl (macOS)
brew install kubectl

# Install Kind
brew install kind

# Install Helm
brew install helm
```

### Deploy with Automated Script

```bash
# Full deployment with Helm (recommended)
./scripts/deploy_local_k8s.sh

# Deploy with kubectl manifests
./scripts/deploy_local_k8s.sh --use-kubectl

# Cleanup everything
./scripts/deploy_local_k8s.sh cleanup

# Help
./scripts/deploy_local_k8s.sh --help
```

### Manual Deployment

#### Option 1: Helm (Recommended)

```bash
# Create Kind cluster
kind create cluster --name datalyptica

# Install chart
helm install datalyptica ./deploy/helm/datalyptica

# View installation notes
helm get notes datalyptica

# Check status
helm status datalyptica

# Upgrade
helm upgrade datalyptica ./deploy/helm/datalyptica

# Uninstall
helm uninstall datalyptica
```

#### Option 2: kubectl

```bash
# Create Kind cluster
kind create cluster --name datalyptica

# Create namespaces
kubectl create namespace datalyptica-core
kubectl create namespace datalyptica-apps

# Deploy core services
kubectl apply -f deploy/k8s/core/ -R

# Deploy app services
kubectl apply -f deploy/k8s/apps/ -R

# Delete all
kubectl delete namespace datalyptica-core datalyptica-apps
```

## Service Access

### Port Forwarding

```bash
# PostgreSQL
kubectl port-forward -n datalyptica-core svc/postgresql 5432:5432

# Redis
kubectl port-forward -n datalyptica-core svc/redis 6379:6379

# MinIO Console
kubectl port-forward -n datalyptica-core svc/minio 9001:9001

# MinIO API
kubectl port-forward -n datalyptica-core svc/minio 9000:9000

# Nessie
kubectl port-forward -n datalyptica-core svc/nessie 19120:19120

# Trino
kubectl port-forward -n datalyptica-apps svc/trino-coordinator 8080:8080

# Flink
kubectl port-forward -n datalyptica-apps svc/flink-jobmanager 8081:8081

# Kafka
kubectl port-forward -n datalyptica-apps svc/kafka 9092:9092

# Schema Registry
kubectl port-forward -n datalyptica-apps svc/schema-registry 8085:8085

# Spark Master
kubectl port-forward -n datalyptica-apps svc/spark-master 4040:4040 7077:7077

# ClickHouse
kubectl port-forward -n datalyptica-apps svc/clickhouse 8123:8123

# Airflow
kubectl port-forward -n datalyptica-apps svc/airflow-webserver 8082:8082

# Superset
kubectl port-forward -n datalyptica-apps svc/superset 8088:8088
```

### Service URLs (after port-forward)

- **MinIO Console**: http://localhost:9001
- **Trino UI**: http://localhost:8080
- **Flink UI**: http://localhost:8081
- **Spark UI**: http://localhost:4040
- **Airflow UI**: http://localhost:8082
- **Superset UI**: http://localhost:8088
- **Nessie API**: http://localhost:19120/api/v2

## Credentials

### Retrieve Secrets

```bash
# PostgreSQL admin password
kubectl get secret -n datalyptica-core postgresql-credentials -o jsonpath='{.data.postgres-password}' | base64 -d

# Redis password
kubectl get secret -n datalyptica-core redis-credentials -o jsonpath='{.data.password}' | base64 -d

# MinIO root user
kubectl get secret -n datalyptica-core minio-credentials -o jsonpath='{.data.root-user}' | base64 -d

# MinIO root password
kubectl get secret -n datalyptica-core minio-credentials -o jsonpath='{.data.root-password}' | base64 -d

# MinIO access key
kubectl get secret -n datalyptica-core minio-credentials -o jsonpath='{.data.access-key}' | base64 -d

# MinIO secret key
kubectl get secret -n datalyptica-core minio-credentials -o jsonpath='{.data.secret-key}' | base64 -d

# ClickHouse password
kubectl get secret -n datalyptica-apps clickhouse-credentials -o jsonpath='{.data.password}' | base64 -d

# Superset admin password
kubectl get secret -n datalyptica-apps superset-credentials -o jsonpath='{.data.admin-password}' | base64 -d

# Superset secret key
kubectl get secret -n datalyptica-apps superset-credentials -o jsonpath='{.data.secret-key}' | base64 -d
```

### Default Credentials

- **Airflow**: admin / admin (created by init container)
- **Superset**: admin / <use secret above>

## Monitoring Commands

### Pod Status

```bash
# All pods in core namespace
kubectl get pods -n datalyptica-core

# All pods in apps namespace
kubectl get pods -n datalyptica-apps

# All pods across all namespaces
kubectl get pods -A

# Watch pods
kubectl get pods -n datalyptica-core -w

# Detailed pod info
kubectl describe pod -n datalyptica-core <pod-name>
```

### Logs

```bash
# View pod logs
kubectl logs -n datalyptica-core <pod-name>

# View specific container logs
kubectl logs -n datalyptica-core <pod-name> -c <container-name>

# Follow logs
kubectl logs -n datalyptica-core <pod-name> -f

# Previous container logs (after restart)
kubectl logs -n datalyptica-core <pod-name> --previous
```

### Services

```bash
# List services
kubectl get svc -n datalyptica-core
kubectl get svc -n datalyptica-apps

# Describe service
kubectl describe svc -n datalyptica-core postgresql
```

### Persistent Volumes

```bash
# List PVCs
kubectl get pvc -n datalyptica-core
kubectl get pvc -n datalyptica-apps

# Describe PVC
kubectl describe pvc -n datalyptica-core <pvc-name>

# List PVs
kubectl get pv
```

### Events

```bash
# Recent events in namespace
kubectl get events -n datalyptica-core --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n datalyptica-core -w
```

## Helm Commands

### Chart Management

```bash
# Validate chart
./scripts/validate_helm_chart.sh

# Lint chart
helm lint deploy/helm/datalyptica

# Template chart (dry-run)
helm template datalyptica deploy/helm/datalyptica

# Package chart
helm package deploy/helm/datalyptica

# Install chart
helm install datalyptica deploy/helm/datalyptica

# Install with custom values
helm install datalyptica deploy/helm/datalyptica -f my-values.yaml

# Upgrade release
helm upgrade datalyptica deploy/helm/datalyptica

# Show values
helm get values datalyptica

# Show all release info
helm get all datalyptica

# List releases
helm list

# Release history
helm history datalyptica

# Rollback to previous version
helm rollback datalyptica

# Rollback to specific revision
helm rollback datalyptica 2

# Uninstall release
helm uninstall datalyptica
```

### Testing

```bash
# Install in dry-run mode
helm install datalyptica deploy/helm/datalyptica --dry-run --debug

# Render specific template
helm template datalyptica deploy/helm/datalyptica -s templates/core/postgresql.yaml

# Diff before upgrade (requires helm-diff plugin)
helm diff upgrade datalyptica deploy/helm/datalyptica
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pod -n datalyptica-core <pod-name>

# Describe pod for events
kubectl describe pod -n datalyptica-core <pod-name>

# Check logs
kubectl logs -n datalyptica-core <pod-name>

# Check previous logs if crashed
kubectl logs -n datalyptica-core <pod-name> --previous

# Interactive shell in pod
kubectl exec -it -n datalyptica-core <pod-name> -- /bin/sh
```

### PVC Issues

```bash
# Check PVC status
kubectl get pvc -n datalyptica-core

# Describe PVC
kubectl describe pvc -n datalyptica-core <pvc-name>

# Check storage class
kubectl get storageclass

# Delete stuck PVC (after deleting pod)
kubectl delete pvc -n datalyptica-core <pvc-name>
```

### Service Connection Issues

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgresql.datalyptica-core.svc.cluster.local

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- postgresql.datalyptica-core.svc.cluster.local:5432

# Check service endpoints
kubectl get endpoints -n datalyptica-core postgresql
```

### Helm Issues

```bash
# Check Helm release status
helm status datalyptica

# View rendered templates
helm get manifest datalyptica

# Check Helm values
helm get values datalyptica

# Debug template rendering
helm template datalyptica deploy/helm/datalyptica --debug
```

## Configuration Examples

### Minimal Deployment (Core Only)

```yaml
# minimal-values.yaml
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
```

```bash
helm install datalyptica deploy/helm/datalyptica -f minimal-values.yaml
```

### Custom Storage

```yaml
# storage-values.yaml
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
# scale-values.yaml
trino:
  worker:
    replicas: 5
    resources:
      requests:
        cpu: 4
        memory: 8Gi

spark:
  worker:
    replicas: 10
    cores: 4
    memory: 8g
```

### Custom Image Registry

```yaml
# registry-values.yaml
global:
  imageRegistry: "myregistry.example.com"
  imagePullPolicy: Always
```

### Enable Monitoring

```yaml
# monitoring-values.yaml
prometheus:
  enabled: true
  persistence:
    size: 50Gi

grafana:
  enabled: true
  auth:
    adminPassword: "secure-password"
```

## Cleanup

### Helm

```bash
# Uninstall release
helm uninstall datalyptica

# Delete namespaces
kubectl delete namespace datalyptica-core datalyptica-apps datalyptica-monitoring
```

### kubectl

```bash
# Delete all resources
kubectl delete namespace datalyptica-core datalyptica-apps
```

### Kind Cluster

```bash
# Delete cluster
kind delete cluster --name datalyptica

# Or use script
./scripts/deploy_local_k8s.sh cleanup
```

## Useful Aliases

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Kubernetes
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kx='kubectl exec -it'

# Namespaces
alias kgpc='kubectl get pods -n datalyptica-core'
alias kgpa='kubectl get pods -n datalyptica-apps'
alias klc='kubectl logs -n datalyptica-core'
alias kla='kubectl logs -n datalyptica-apps'

# Helm
alias h='helm'
alias hl='helm list'
alias hi='helm install'
alias hu='helm upgrade'
alias hd='helm delete'
```

## Resources

- **Helm Documentation**: https://helm.sh/docs/
- **Kind Documentation**: https://kind.sigs.k8s.io/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
