# Platform Renaming: ShuDL → Datalyptica

**Date:** December 1, 2025  
**Status:** ✅ Completed

---

## Overview

The data lakehouse platform has been renamed from **ShuDL** to **Datalyptica** to better reflect the platform's mission and technology stack.

### Name Origin

**Datalyptica** (Greek: αἰθήρ) means "the upper sky" or "pure, fresh air" in Greek mythology. It represents the space where data flows freely, perfectly aligning with a lakehouse architecture that combines the flexibility of data lakes with the structure of data warehouses.

---

## Naming Conventions

| Context | Old Name | New Name | Usage |
|---------|----------|----------|-------|
| **Display Name** | ShuDL | Datalyptica | Documentation, UI, logs |
| **File/Database Names** | shudl | datalyptica | Filenames, database names, user names |
| **Environment Variables** | SHUDL_* | DATALYPTICA_* | DATALYPTICA_VERSION, DATALYPTICA_DB, DATALYPTICA_USER |
| **Docker Registry** | shugur-network | datalyptica | ghcr.io/datalyptica/datalyptica/* |

---

## Changes Applied

### 1. Docker Configuration

**File:** `docker/docker-compose.yml`

- **Secrets:** `shudl_password` → `datalyptica_password`
- **Environment Variables:**
  - `SHUDL_VERSION` → `DATALYPTICA_VERSION`
  - `SHUDL_DB` → `DATALYPTICA_DB`
  - `SHUDL_USER` → `DATALYPTICA_USER`
  - `SHUDL_PASSWORD` → `DATALYPTICA_PASSWORD`
  - `SHUDL_PASSWORD_FILE` → `DATALYPTICA_PASSWORD_FILE`

- **Docker Images:** All images updated from:
  ```
  ghcr.io/shugur-network/shudl/<service>:${SHUDL_VERSION}
  ```
  To:
  ```
  ghcr.io/datalyptica/datalyptica/<service>:${DATALYPTICA_VERSION}
  ```

- **Services Updated:**
  - minio, postgresql, nessie, trino
  - spark (master & worker), flink (jobmanager & taskmanager)
  - kafka, schema-registry, kafka-connect
  - clickhouse, dbt, great-expectations
  - jupyterhub, mlflow, superset
  - airflow (webserver, scheduler, worker)

### 2. Configuration Files

**Spark Configuration** (`configs/spark/spark-defaults.conf`):
```properties
spark.master  spark://datalyptica-spark-master:7077
```

**Kafka Configuration**:
```
KAFKA_CLUSTERS_0_NAME=datalyptica-cluster
```

**Great Expectations**:
```
GE_JUPYTER_TOKEN=datalyptica-ge-token
```

### 3. Database Changes

**PostgreSQL:**
- Database: `shudl` → `datalyptica`
- User: `shudl` → `datalyptica`
- Password file: `shudl_password` → `datalyptica_password`

**Nessie:**
- Owner: `shudl` → `datalyptica`
- Username: `shudl` → `datalyptica`

### 4. Scripts Updated

All initialization and setup scripts updated:

- `scripts/init-databases.sh` - PostgreSQL initialization
- `scripts/init-minio-buckets.sh` - MinIO bucket setup
- `scripts/init-kafka-topics.sh` - Kafka topic management
- `scripts/verify-services.sh` - Service health checks
- `scripts/init-dev-environment.sh` - Orchestration script
- `scripts/configure-keycloak.sh` - Keycloak configuration
- `scripts/generate-secrets.sh` - Secret generation
- `scripts/generate-certificates.sh` - TLS certificate generation
- `scripts/setup-loki.sh` - Log aggregation setup
- `scripts/setup-alloy.sh` - Grafana Alloy setup

**Key Updates:**
```bash
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-datalyptica}
DATALYPTICA_PASSWORD=$(cat "${PROJECT_ROOT}/secrets/passwords/datalyptica_password")
```

**Keycloak Realm:**
- Realm: `shudl` → `datalyptica`
- Display Name: "ShuDL Platform" → "Datalyptica Platform"
- Clients: `shudl-api` → `datalyptica-api`
- User emails: `*@shudl.local` → `*@datalyptica.local`

### 5. Documentation

**README.md:**
```markdown
# Datalyptica - Datalyptica Data Lakehouse Platform

Datalyptica (Datalyptica Data Lakehouse) is a comprehensive on-premises 
data lakehouse platform built on Apache Iceberg...
```

**ENVIRONMENT_VARIABLES.md:**
- Title: "ShuDL Platform" → "Datalyptica Platform"
- All `SHUDL_*` variables → `DATALYPTICA_*`
- Examples updated:
  - `shudl-minio` → `datalyptica-minio`
  - `shudl-postgresql` → `datalyptica-postgresql`
  - `.shudl_prod_secrets` → `.datalyptica_prod_secrets`

**Other Documentation:**
- `.gitignore` header updated
- `KAFKA_ARCHITECTURE_DECISION.md` references updated
- Phase 2 progress docs updated

### 6. Logging Configuration

**Loki/Grafana:**
```yaml
- job_name: datalyptica
  static_configs:
    - labels:
        job: datalyptica
        __path__: /var/log/datalyptica/*.log
```

**Query Examples:**
```
{project="datalyptica"} | json | level="ERROR"
rate({project="datalyptica"}[5m])
```

### 7. SSL/TLS Certificates

**Certificate Subject:**
```
O = Datalyptica
CN = Datalyptica-CA
displayName = Datalyptica Platform
```

---

## Migration Checklist

### Immediate Actions Needed

- [ ] **Rebuild Docker Images** with new naming
  ```bash
  cd docker && docker compose build --no-cache
  ```

- [ ] **Update Environment Files**
  - Update `.env` files with `DATALYPTICA_VERSION`, `DATALYPTICA_DB`, etc.
  - Rename any `SHUDL_*` variables to `DATALYPTICA_*`

- [ ] **Regenerate Secrets** (if needed)
  ```bash
  ./scripts/generate-secrets.sh
  ```

- [ ] **Update Docker Registry**
  - Push images to `ghcr.io/datalyptica/datalyptica/*`
  - Update image pull secrets if using private registry

- [ ] **Database Migration** (for existing deployments)
  ```sql
  -- Rename database
  ALTER DATABASE shudl RENAME TO datalyptica;
  
  -- Rename user
  ALTER USER shudl RENAME TO datalyptica;
  ```

- [ ] **Keycloak Reconfiguration**
  ```bash
  ./scripts/configure-keycloak.sh
  ```

- [ ] **Update Monitoring**
  - Update Grafana dashboard queries: `shudl` → `datalyptica`
  - Update alert rules and log filters

### Verification Steps

- [ ] All services start successfully with new naming
- [ ] Database connections work with new credentials
- [ ] Keycloak authentication functions properly
- [ ] Monitoring dashboards display correct data
- [ ] Integration tests pass
- [ ] Documentation accurately reflects new naming

---

## Container Name Examples

With `COMPOSE_PROJECT_NAME=datalyptica`, containers will be named:

- `datalyptica-minio`
- `datalyptica-postgresql`
- `datalyptica-nessie`
- `datalyptica-trino`
- `datalyptica-spark-master`
- `datalyptica-spark-worker`
- `datalyptica-kafka`
- `datalyptica-flink-jobmanager`
- `datalyptica-airflow-webserver`

---

## Docker Command Updates

### Old Commands:
```bash
docker exec shudl-trino trino --execute "SHOW CATALOGS"
docker exec shudl-postgresql pg_isready
docker network inspect shudl_data
```

### New Commands:
```bash
docker exec datalyptica-trino trino --execute "SHOW CATALOGS"
docker exec datalyptica-postgresql pg_isready
docker network inspect datalyptica_data
```

---

## Benefits of Renaming

1. **Better Brand Identity** - "Datalyptica" is more memorable and meaningful
2. **Professional Image** - Sounds more enterprise-ready
3. **SEO Friendly** - Unique name that's easy to search for
4. **Mythology Connection** - Aligns with data-as-air philosophy
5. **International Appeal** - Greek origin is universally recognized

---

## Rollback Procedure

If rollback is needed:

```bash
# Reverse the renaming
find . -type f \( -name "*.yml" -o -name "*.md" -o -name "*.sh" \) \
  -exec sed -i '' \
    -e 's/datalyptica/shudl/g' \
    -e 's/Datalyptica/ShuDL/g' \
    -e 's/DATALYPTICA/SHUDL/g' \
    -e 's/datalyptica/shugur-network/g' \
    {} +

# Rename password file back
mv secrets/passwords/datalyptica_password secrets/passwords/shudl_password
```

---

## Support

For questions or issues related to the renaming:
- Review this document thoroughly
- Check environment variable configurations
- Verify all secret files exist with new names
- Ensure Docker images are rebuilt with new tags

---

**Last Updated:** December 1, 2025  
**Renamed By:** Senior Data Platform Architect  
**Approved By:** Platform Owner
