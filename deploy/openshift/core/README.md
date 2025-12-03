# Core Services - OpenShift Deployment

This directory contains OpenShift-ready manifests for core infrastructure services.

## Files

1. **01-postgresql.yaml** - PostgreSQL database (StatefulSet)
2. **02-redis.yaml** - Redis cache (StatefulSet)
3. **03-minio.yaml** - MinIO object storage (StatefulSet)
4. **04-nessie.yaml** - Nessie catalog (Deployment)

## Quick Deployment

### Prerequisites

- Project `datalyptica-core` created
- Service account `datalyptica-sa` created
- All secrets created (see main deployment guide)
- Storage class identified

### Deploy All Core Services

```bash
# Update storage class in all files first!
sed -i 's/storageClassName: standard/storageClassName: YOUR-STORAGE-CLASS/g' *.yaml

# Deploy in order
oc apply -f 01-postgresql.yaml
oc wait --for=condition=ready pod -l app=postgresql -n datalyptica-core --timeout=300s

oc apply -f 02-redis.yaml
oc wait --for=condition=ready pod -l app=redis -n datalyptica-core --timeout=300s

oc apply -f 03-minio.yaml
oc wait --for=condition=ready pod -l app=minio -n datalyptica-core --timeout=300s

oc apply -f 04-nessie.yaml
oc wait --for=condition=ready pod -l app=nessie -n datalyptica-core --timeout=300s
```

### Verify Deployment

```bash
oc get pods -n datalyptica-core
oc get svc -n datalyptica-core
oc get pvc -n datalyptica-core
```

## Individual Service Details

### PostgreSQL

- **Port**: 5432
- **Storage**: 10Gi
- **Databases**: postgres, nessie, airflow, superset, mlflow
- **User**: postgres

### Redis

- **Port**: 6379
- **Storage**: 5Gi
- **Auth**: Password from secret

### MinIO

- **API Port**: 9000
- **Console Port**: 9001
- **Storage**: 20Gi
- **Auth**: Root user/password from secret

### Nessie

- **Port**: 19120
- **Backend**: PostgreSQL (nessie database)
- **Store Type**: JDBC

## Creating Routes

```bash
# MinIO Console
oc create route edge minio-console --service=minio --port=9001 -n datalyptica-core

# Nessie API
oc create route edge nessie-api --service=nessie --port=19120 -n datalyptica-core

# Get route URLs
oc get routes -n datalyptica-core
```

## Post-Deployment Tasks

### Initialize MinIO Buckets

```bash
# Get MinIO credentials
MINIO_ROOT_USER=$(oc get secret minio-credentials -n datalyptica-core -o jsonpath='{.data.root-user}' | base64 -d)
MINIO_ROOT_PASSWORD=$(oc get secret minio-credentials -n datalyptica-core -o jsonpath='{.data.root-password}' | base64 -d)

# Create buckets
oc exec -n datalyptica-core minio-0 -- sh -c "
mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
mc mb local/lakehouse
mc mb local/warehouse
mc mb local/bronze
mc mb local/silver
mc mb local/gold
"
```

### Initialize Nessie

```bash
# Get route
NESSIE_URL=$(oc get route nessie-api -n datalyptica-core -o jsonpath='{.spec.host}')

# Create default branch
curl -X POST https://$NESSIE_URL/api/v2/trees \
  -H "Content-Type: application/json" \
  -d '{"name":"main","type":"BRANCH"}'

# Verify
curl https://$NESSIE_URL/api/v2/trees
```

## Troubleshooting

### PostgreSQL Issues

```bash
# Check logs
oc logs -f postgresql-0 -n datalyptica-core

# Test connection
oc exec -it postgresql-0 -n datalyptica-core -- psql -U postgres -c "SELECT version();"
```

### Redis Issues

```bash
# Check logs
oc logs -f redis-0 -n datalyptica-core

# Test connection
REDIS_PASSWORD=$(oc get secret redis-credentials -n datalyptica-core -o jsonpath='{.data.password}' | base64 -d)
oc exec -it redis-0 -n datalyptica-core -- redis-cli -a $REDIS_PASSWORD PING
```

### MinIO Issues

```bash
# Check logs
oc logs -f minio-0 -n datalyptica-core

# Access console via route
oc get route minio-console -n datalyptica-core
```

### Nessie Issues

```bash
# Check logs
oc logs -f deployment/nessie -n datalyptica-core

# Check health
NESSIE_URL=$(oc get route nessie-api -n datalyptica-core -o jsonpath='{.spec.host}')
curl https://$NESSIE_URL/q/health
```

### Storage Issues

```bash
# Check PVC status
oc get pvc -n datalyptica-core

# If pending, check events
oc describe pvc <pvc-name> -n datalyptica-core

# Check storage class
oc get storageclass
```

## Resource Requirements

| Service    | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
| ---------- | ----------- | --------- | -------------- | ------------ | ------- |
| PostgreSQL | 250m        | 1000m     | 512Mi          | 2Gi          | 10Gi    |
| Redis      | 100m        | 500m      | 256Mi          | 512Mi        | 5Gi     |
| MinIO      | 250m        | 1000m     | 512Mi          | 2Gi          | 20Gi    |
| Nessie     | 100m        | 500m      | 256Mi          | 1Gi          | -       |
| **Total**  | 700m        | 3000m     | 1.5Gi          | 5.5Gi        | 35Gi    |
