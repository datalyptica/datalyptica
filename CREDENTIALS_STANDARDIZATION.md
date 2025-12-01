# Datalyptica Credentials & Database Standardization

## Overview

This document defines the standardized naming convention for all databases, users, and credentials across the Datalyptica platform.

## Standardization Rules

### 1. Service-Specific Credentials

Each service MUST have its own dedicated:

- Database name
- Database user
- Password (stored in secrets)
- Connection credentials

### 2. Naming Convention

**Database Names:**

```
<service_name>
```

**Database Users:**

```
<service_name>
```

**Password Secrets:**

```
secrets/passwords/<service_name>_password
```

**Environment Variables:**

```
<SERVICE>_DB_NAME=<service_name>
<SERVICE>_DB_USER=<service_name>
<SERVICE>_DB_PASSWORD_FILE=/run/secrets/<service_name>_password
```

## Service Credential Matrix

| Service            | Database Name    | DB User            | Password Secret          | Port | Purpose                      |
| ------------------ | ---------------- | ------------------ | ------------------------ | ---- | ---------------------------- |
| **Core Platform**  |
| Datalyptica        | `datalyptica`    | `datalyptica`      | `datalyptica_password`   | 5432 | Main platform database       |
| Nessie             | `nessie`         | `nessie`           | `nessie_password`        | 5432 | Catalog metadata             |
| Keycloak           | `keycloak`       | `keycloak`         | `keycloak_db_password`   | 5432 | Identity & access management |
| **Analytics & ML** |
| Airflow            | `airflow`        | `airflow`          | `airflow_password`       | 5432 | Workflow metadata            |
| JupyterHub         | `jupyterhub`     | `jupyterhub`       | `jupyterhub_password`    | 5432 | Notebook server state        |
| MLflow             | `mlflow`         | `mlflow`           | `mlflow_password`        | 5432 | ML tracking & registry       |
| Superset           | `superset`       | `superset`         | `superset_password`      | 5432 | BI metadata                  |
| **Data Storage**   |
| MinIO              | N/A              | `minio_admin`      | `minio_root_password`    | 9000 | Object storage admin         |
| ClickHouse         | `default`        | `clickhouse_user`  | `clickhouse_password`    | 9000 | OLAP queries                 |
| **Infrastructure** |
| Postgres           | `postgres`       | `postgres`         | `postgres_password`      | 5432 | System database              |
| Grafana            | N/A              | `grafana_admin`    | `grafana_admin_password` | 3000 | Monitoring dashboards        |

## Environment Variable Standards

### PostgreSQL Connection Pattern

```bash
# Service-specific PostgreSQL credentials
<SERVICE>_DB_HOST=postgresql
<SERVICE>_DB_PORT=5432
<SERVICE>_DB_NAME=<service>
<SERVICE>_DB_USER=<service>
<SERVICE>_DB_PASSWORD=<from_secret_file>
```

### Example: Airflow

```bash
AIRFLOW_DB_HOST=postgresql
AIRFLOW_DB_PORT=5432
AIRFLOW_DB_NAME=airflow
AIRFLOW_DB_USER=airflow
AIRFLOW_DB_PASSWORD_FILE=/run/secrets/airflow_password
```

### Example: MLflow

```bash
MLFLOW_DB_HOST=postgresql
MLFLOW_DB_PORT=5432
MLFLOW_DB_NAME=mlflow
MLFLOW_DB_USER=mlflow
MLFLOW_DB_PASSWORD_FILE=/run/secrets/mlflow_password
```

## Secret File Structure

```
secrets/
└── passwords/
    ├── postgres_password              # PostgreSQL superuser
    ├── postgres_replication_password  # Replication user
    ├── datalyptica_password          # Main platform DB
    ├── nessie_password               # Nessie catalog
    ├── keycloak_password             # Keycloak IAM
    ├── airflow_password              # Airflow workflows
    ├── jupyterhub_password           # JupyterHub notebooks
    ├── mlflow_password               # MLflow tracking
    ├── superset_password             # Superset BI
    ├── minio_root_password           # MinIO object storage
    ├── clickhouse_password           # ClickHouse OLAP
    ├── grafana_admin_password        # Grafana monitoring
    └── s3_secret_key                 # S3 access credentials
```

## Database Initialization Order

1. **PostgreSQL System** - Create superuser and replication user
2. **Core Platform**
   - `datalyptica` database with `datalyptica` user
   - `nessie` database with `nessie` user
   - `keycloak` database with `keycloak` user
3. **Analytics & ML**
   - `airflow` database with `airflow` user
   - `jupyterhub` database with `jupyterhub` user
   - `mlflow` database with `mlflow` user
   - `superset` database with `superset` user

## Security Best Practices

### Password Requirements

- **Development:** Minimum 12 characters
- **Production:** Minimum 16 characters
- Must include: uppercase, lowercase, numbers, special characters
- Rotate every 90 days in production

### Password Generation

```bash
# Generate secure password (16 characters)
openssl rand -base64 16

# Generate secure password (32 characters)
openssl rand -base64 32

# Generate alphanumeric password
openssl rand -hex 16
```

### Secret File Permissions

```bash
chmod 600 secrets/passwords/*
chown root:root secrets/passwords/*
```

## Connection String Patterns

### PostgreSQL (psycopg2)

```python
postgresql://{user}:{password}@{host}:{port}/{database}
```

### PostgreSQL (SQLAlchemy)

```python
postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}
```

### MinIO (S3)

```python
s3://{access_key}:{secret_key}@{endpoint}/{bucket}
```

### ClickHouse (HTTP)

```python
clickhouse://{user}:{password}@{host}:{port}/{database}
```

## Migration from Old Naming

### Services Requiring Updates

| Current Name         | Standardized Name         | Action Required    |
| -------------------- | ------------------------- | ------------------ |
| `SHUDL_USER`         | `DATALYPTICA_DB_USER`     | ✅ Already updated |
| `SHUDL_PASSWORD`     | `DATALYPTICA_DB_PASSWORD` | ✅ Already updated |
| `SHUDL_DB`           | `DATALYPTICA_DB_NAME`     | ✅ Already updated |
| `JUPYTERHUB_DB_NAME` | `JUPYTERHUB_DB_NAME`      | ✅ Compliant       |
| `MLFLOW_DB_NAME`     | `MLFLOW_DB_NAME`          | ✅ Compliant       |
| `SUPERSET_DB_NAME`   | `SUPERSET_DB_NAME`        | ✅ Compliant       |
| `AIRFLOW_DB_NAME`    | `AIRFLOW_DB_NAME`         | ✅ Compliant       |

## Implementation Checklist

- [ ] Create all secret files in `secrets/passwords/`
- [ ] Update `.env` files with standardized variable names
- [ ] Update `docker-compose.yml` with new environment variables
- [ ] Update `init-databases.sh` script with all databases
- [ ] Update service-specific entrypoint scripts
- [ ] Test database connections for each service
- [ ] Document connection strings in service READMEs
- [ ] Implement password rotation policy
- [ ] Set up secret management (Vault/AWS Secrets Manager)
- [ ] Configure backup strategy for each database

## Verification Commands

### List All Databases

```bash
docker exec datalyptica-postgresql psql -U postgres -c "\l"
```

### List All Users

```bash
docker exec datalyptica-postgresql psql -U postgres -c "\du"
```

### Test Service Connection

```bash
# Example: Test Airflow connection
docker exec datalyptica-postgresql psql \
  -U airflow_user \
  -d airflow_db \
  -c "SELECT version();"
```

### Verify Permissions

```bash
# Check database ownership
docker exec datalyptica-postgresql psql -U postgres -c "
SELECT datname, pg_catalog.pg_get_userbyid(datdba) AS owner
FROM pg_database
WHERE datname NOT IN ('template0', 'template1');
"
```

## Troubleshooting

### Connection Refused

- Verify database exists: `\l` in psql
- Check user exists: `\du` in psql
- Verify password secret file exists
- Check service environment variables

### Permission Denied

- Ensure user owns the database
- Grant necessary privileges:
  ```sql
  GRANT ALL PRIVILEGES ON DATABASE <dbname> TO <user>;
  ```

### Database Not Found

- Run initialization script: `./scripts/init-databases.sh`
- Manually create:
  ```sql
  CREATE DATABASE <dbname> OWNER <user>;
  ```

## References

- PostgreSQL Documentation: https://www.postgresql.org/docs/
- Docker Secrets: https://docs.docker.com/engine/swarm/secrets/
- Connection Pooling: See `configs/pgbouncer/` (if using PgBouncer)
- High Availability: See `POSTGRESQL_HA.md`

---

**© 2025 Datalyptica. All rights reserved.**
