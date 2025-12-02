# Analytics & ML Services - Quick Reference

## Service Overview

| Service              | Port | Image                                  | Size   | Purpose                |
| -------------------- | ---- | -------------------------------------- | ------ | ---------------------- |
| Redis                | 6379 | redis:7.2-alpine                       | ~30MB  | Cache & message broker |
| JupyterHub           | 8000 | ghcr.io/.../jupyterhub:v1.0.0          | ~1.5GB | Multi-user notebooks   |
| JupyterLab (spawned) | -    | ghcr.io/.../jupyterlab-notebook:v1.0.0 | ~2GB   | User notebooks         |
| MLflow               | 5000 | ghcr.io/.../mlflow:v1.0.0              | ~1.2GB | Experiment tracking    |
| Superset             | 8088 | ghcr.io/.../superset:v1.0.0            | ~2.5GB | BI platform            |
| Airflow Webserver    | 8090 | ghcr.io/.../airflow:v1.0.0             | ~2GB   | Workflow UI            |
| Airflow Scheduler    | -    | ghcr.io/.../airflow:v1.0.0             | ~2GB   | DAG scheduler          |
| Airflow Worker       | -    | ghcr.io/.../airflow:v1.0.0             | ~2GB   | Task executor          |

## Quick Commands

### Build All Images

```bash
./scripts/build/build-analytics-ml-services.sh
```

### Start All Services

```bash
cd docker
docker compose up -d redis jupyterhub mlflow superset airflow-webserver airflow-scheduler airflow-worker
```

### Check Status

```bash
docker compose ps | grep -E "redis|jupyterhub|mlflow|superset|airflow"
```

### View Logs

```bash
docker logs -f docker-jupyterhub
docker logs -f docker-mlflow
docker logs -f docker-superset
docker logs -f docker-airflow-webserver
```

### Stop Services

```bash
docker compose stop jupyterhub mlflow superset airflow-webserver airflow-scheduler airflow-worker redis
```

## Access URLs

- **JupyterHub**: http://localhost:8000
- **MLflow**: http://localhost:5000
- **Superset**: http://localhost:8088
- **Airflow**: http://localhost:8090

## Default Credentials

| Service    | Username             | Password    |
| ---------- | -------------------- | ----------- |
| JupyterHub | admin (configurable) | Set via env |
| MLflow     | -                    | No auth     |
| Superset   | admin                | admin123    |
| Airflow    | admin                | admin123    |

## Key Environment Variables

See `docker/.env` for all variables. Key ones:

```bash
# JupyterHub
JUPYTERHUB_ADMIN_USER=admin
JUPYTERHUB_OPEN_SIGNUP=False

# Superset
SUPERSET_ADMIN_USERNAME=admin
SUPERSET_SECRET_KEY=<generate>

# Airflow
AIRFLOW_ADMIN_USERNAME=admin
AIRFLOW_SECRET_KEY=<generate>
AIRFLOW_FERNET_KEY=<generate>
```

Generate secrets: `./scripts/generate-analytics-secrets.sh`

## Common Operations

### JupyterHub: Create Admin User

```bash
docker exec -it docker-jupyterhub jupyterhub token admin
```

### MLflow: Create Bucket

```bash
docker exec docker-minio mc mb minio/mlflow-artifacts
```

### Superset: Reset Admin Password

```bash
docker exec -it docker-superset superset fab reset-password --username admin
```

### Airflow: List DAGs

```bash
docker exec docker-airflow-webserver airflow dags list
```

## Troubleshooting

### JupyterHub notebook won't spawn

- Check Docker socket mounted: `/var/run/docker.sock`
- Verify spawner image exists
- Check hub logs: `docker logs docker-jupyterhub`

### MLflow artifacts not saving

- Verify MinIO credentials in env
- Create bucket: `mlflow-artifacts`
- Check connectivity to MinIO

### Superset slow dashboards

- Check Redis: `docker exec docker-redis redis-cli ping`
- Increase worker count
- Enable caching in dashboard settings

### Airflow tasks not executing

- Check worker: `docker logs docker-airflow-worker`
- Verify Redis connection
- Check DAG syntax: `airflow dags list-runs`

## Documentation

- **Integration Guide**: `../../docs/ANALYTICS_ML_SERVICES_INTEGRATION.md`
- **Summary**: `../../docs/ANALYTICS_ML_SERVICES_SUMMARY.md`
- **Build Script**: `../../scripts/build/build-analytics-ml-services.sh`
- **Secrets Script**: `../../scripts/generate-analytics-secrets.sh`
