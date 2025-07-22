# ShuDL (Shugur Data Lakehouse) - AI Coding Agent Instructions

## Architecture Overview

ShuDL is a comprehensive Data Lakehouse platform integrating:
- **MinIO** (S3-compatible object storage) 
- **PostgreSQL/Patroni** (metadata store with HA)
- **Nessie** (Git-like catalog with JDBC2 backend + REST API)
- **Trino** (query engine with REST catalog integration)
- **Spark** (compute engine with Iceberg support)

ShuDL bundles  
| Layer | Component | Version | Notes |
|-------|-----------|---------|-------|
| Object store | **MinIO** | RELEASE.2025-06-13 | S3, erasure 8 + 3 |
| Metadata DB | **PostgreSQL 16 / Patroni** | HA via K8s DCS / etcd |
| Table catalog | **Project Nessie** | **0.104.2** | JDBC2 backend |
| Table format | **Apache Iceberg** | **1.9.1** | Spec v3 |
| Ingestion | **Debezium 2.5** + **Kafka (KRaft) 4.x** | No ZooKeeper |
| SQL engine | **Trino** | **448** | REST catalog |
| Batch engine | **Spark** | **3.5** | Iceberg jars |
| Security | Keycloak OIDC · Apache Ranger 3.x |
| Observability | Prometheus 2.50, Grafana 11, Loki |
| Admin UI | Lakehouse Manager portal (React + Go) |
---

ShuDL is designed for both development and production use cases, providing a unified platform for data ingestion, storage, and analytics. It supports a variety of deployment models, from local Docker setups to full-scale Kubernetes clusters.
ShuDL is built with a focus on modularity and extensibility, allowing users to customize and scale their data lakehouse as needed. The platform is optimized for performance and reliability, ensuring that data operations can be performed efficiently across large datasets.

The platform supports both standalone (Docker) and distributed or H/A (Kubernetes / VM) deployments with identical configurations.

## 2 Deployment Types

| Driver (`lakectl`) | Modes | Target | P0 status |
|-------------------|-------|--------|-----------|
| **docker** | **stand-alone only** | Dev / PoC | working |
| **k8s** | stand-alone or **HA** | KinD & prod K8s | stand-alone in P0 |
| **vm** | stand-alone or **HA** | Bare-metal / VMs | placeholder |
---

## Project Structure
```
docker/                  # Dockerfiles
charts/lakehouse/        # Helm umbrella chart
installer/cmd/lakectl/   # Interactive installer
infra/terraform/         # bare-metal K8s later
portal/                  # React + Go later
.github/workflows/       # CI pipelines
```

## Critical Project Patterns

### Docker Image Hierarchy
```
base/alpine → services/minio,nessie,trino
base/java → services/spark,trino  
base/postgresql → services/postgresql,patroni
```
- All images use non-root users (`shusr`)
- LABEL maintainer="devops@shugur.com".
- Multi-architecture builds (amd64/arm64) via `--platform` flag
- Standardized health checks on service-specific ports
- Build order enforced: base images → postgresql base → services

### Configuration Management
- External configs in `docker/config/<service>/` mounted as volumes
- Environment variables for runtime settings (credentials, endpoints)
- **Pattern**: JDBC URLs use service names: `jdbc:postgresql://postgresql:5432/nessie`
- **Pattern**: REST catalog endpoints: `http://nessie:19120/iceberg/main/`
- S3 endpoints always use path-style access: `s3.path-style-access=true`
- Kafka in KRaft mode (broker,controller) — no ZooKeeper.

### Service Dependencies
- **PostgreSQL** must be healthy before starting Nessie
- **MinIO** must be ready before Trino/Spark can access Iceberg tables
- **Nessie** must be fully initialized before Trino/Spark can query Iceberg tables
- **Trino** and **Spark** must be configured to use Nessie REST catalog


### Service Integration Model
The stack follows a dependency chain:
1. **PostgreSQL** (foundational metadata store)
2. **MinIO** (object storage, auto-creates `lakehouse` bucket)
3. **Nessie** (waits for PostgreSQL, provides REST catalog at `/iceberg/main/`)
4. **Trino + Spark** (consume Nessie REST catalog)
5. **Debezium + Kafka** (for CDC, not in P0)
6. **Keycloak** (for security, not in P0)



### Development Workflows

**Build Everything:**
```bash
./docker/build.sh [tag]  # Builds in dependency order
```

**Test Integration:**
```bash
./tmp/run_all_tests.sh          # Full integration test suite
./tmp/comprehensive_integration_test.sh  # Component health checks
./tmp/<service>_test.sh         # Individual service tests
```

**Deploy:**
```bash
# Docker Compose (development)
docker-compose up -d

# Kubernetes (production)
./installer/cmd/lakectl/lakectl  # Interactive installer
helm install lakehouse ./charts/lakehouse --set global.clusterMode=high-availability
```

### Key Version Dependencies
- **Nessie 0.104.2** with JDBC2 backend (not JPA)
- **Iceberg 1.9.1** libraries for Spark/Trino integration  
- **Trino 448** with REST catalog connector
- **Spark 3.5** with Iceberg runtime dependencies
- **PostgreSQL 16** with Patroni for HA


## Component-Specific Conventions

### MinIO (`docker/services/minio/`)
- Entrypoint auto-creates `lakehouse` bucket using MinIO client (`mc`)
- Credentials: `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` (default: admin/password123)
- Console on port 9001, API on port 9000

### Nessie (`docker/services/nessie/`)
- **Critical**: Uses JDBC2 backend, not MongoDB or JPA
- Startup script waits for PostgreSQL with `pg_isready` checks
- REST catalog endpoint: `/iceberg/main/` (note the trailing slash)
- JAR downloaded and configured via environment in Dockerfile

### Trino (`docker/services/trino/`)
- **Pattern**: Catalog configs go in `/opt/trino/etc/catalog/iceberg.properties`
- Uses `connector.name=iceberg` with `iceberg.catalog.type=rest`
- S3 configuration for MinIO includes `s3.endpoint` and `s3.path-style-access=true`

### Spark (`docker/services/spark/`)
- **Runtime Dependencies**: Downloads Iceberg JARs to `${SPARK_HOME}/jars/`
- **Modes**: `master`, `worker`, `shell`, `pyspark`, `sql` via `SPARK_MODE` env
- Python packages auto-installed: pandas, numpy, requests (versions pinned)
- REST catalog config via spark-defaults.conf: `spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.rest.RESTCatalog`

### PostgreSQL/Patroni (`docker/services/patroni/`)
- Development uses standalone PostgreSQL, production uses Patroni with Kubernetes DCS
- Patroni waits for etcd/Kubernetes API, creates cluster scope: `lakehouse`
- Database initialization via `scripts/init-db.sh` pattern

## Testing Patterns

**Integration Test Structure:**
- `wait_for_service()` functions with health endpoint polling
- Each test validates service health before proceeding to integration
- **Pattern**: Create test data → verify cross-service visibility → cleanup
- All tests use curl for REST API validation and SQL for query validation

**Health Check Endpoints:**
- MinIO: `http://localhost:9000/minio/health/live`
- Nessie: `http://localhost:19120/api/v2/config`  
- Trino: `http://localhost:8080/v1/info`
- Spark: `http://localhost:4040` (UI)
- PostgreSQL: `pg_isready -h postgresql -p 5432`

## Common Gotchas

1. **Nessie Backend**: Must use JDBC2, not JPA or MongoDB
2. **REST Catalog URLs**: Always include trailing slash: `/iceberg/main/`
3. **S3 Configuration**: MinIO requires `path-style-access=true` in all consumers
4. **Build Dependencies**: Base images must be built before service images
5. **Service Dependencies**: PostgreSQL must be healthy before Nessie starts
6. **Catalog Names**: Use `nessie` as catalog name in Trino/Spark configurations

## File Patterns to Follow

- Entrypoint scripts: Always include dependency waiting + service-specific initialization
- Dockerfiles: Multi-stage builds with explicit layer optimization
- Config files: Environment variable substitution with defaults
- Health checks: 30s interval, 60s start period, 3 retries standard
- Volume mounts: External configs as read-only, data volumes as read-write
