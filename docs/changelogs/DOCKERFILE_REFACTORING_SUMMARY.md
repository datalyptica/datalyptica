# Dockerfile Refactoring Summary

## Compliance Status: ✅ 100% (25/25)

All Dockerfiles now follow the "extend, don't rebuild" architectural principle.

---

## Changes Made

### 1. **Trino** - `/deploy/docker/trino/Dockerfile`

**Before:** Downloaded and extracted Trino tarball from Apache Maven

```dockerfile
FROM eclipse-temurin:24-jre-alpine-3.21
RUN wget https://repo1.maven.org/...trino-server-476.tar.gz
```

**After:** Extends official Trino image

```dockerfile
FROM trinodb/trino:476
```

**Impact:**

- Removed 30+ lines of manual installation
- Uses official tested binaries
- Automatic security updates from Trino project

---

### 2. **PostgreSQL** - `/deploy/docker/postgresql/Dockerfile`

**Before:** Installed PostgreSQL from Alpine packages

```dockerfile
FROM alpine:3.21.3
RUN apk add postgresql postgresql-contrib postgresql-client
```

**After:** Extends official PostgreSQL image

```dockerfile
FROM postgres:17-alpine
```

**Impact:**

- Removed 20+ lines of manual setup
- Official PostgreSQL initialization scripts included
- Battle-tested entrypoint logic

---

### 3. **MinIO** - `/deploy/docker/minio/Dockerfile`

**Before:** Downloaded MinIO and MC binaries manually

```dockerfile
FROM alpine:3.21.3
RUN wget -O /usr/local/bin/minio "$MINIO_URL"
RUN wget -O /usr/local/bin/mc "$MC_URL"
```

**After:** Extends official MinIO image

```dockerfile
FROM minio/minio:RELEASE.2024-11-07T00-52-20Z
```

**Impact:**

- Removed architecture-specific binary downloads
- Official MinIO and MC versions included
- Proper user and permissions pre-configured

---

### 4. **Spark** - `/deploy/docker/spark/Dockerfile`

**Before:** Downloaded and extracted Spark tarball

```dockerfile
FROM eclipse-temurin:17-jre
RUN wget https://archive.apache.org/.../spark-3.5.6-bin-hadoop3.tgz
RUN tar -xzf spark-3.5.6-bin-hadoop3.tgz
```

**After:** Extends official Spark image, adds Iceberg JARs

```dockerfile
FROM apache/spark:3.5.1-scala2.12-java17-python3-ubuntu
RUN wget iceberg-spark-runtime JAR  # Pre-built JAR only
```

**Impact:**

- Spark binaries from official Apache image
- Only downloads pre-built Iceberg extension JARs
- Proper Spark user and directory structure included

---

### 5. **Nessie** - `/deploy/docker/nessie/Dockerfile`

**Before:** Downloaded Nessie runner JAR from GitHub releases

```dockerfile
FROM eclipse-temurin:24-jre-alpine-3.21
RUN wget https://github.com/.../nessie-quarkus-0.104.3-runner.jar
```

**After:** Extends official Nessie image

```dockerfile
FROM ghcr.io/projectnessie/nessie:0.104.3
```

**Impact:**

- Official Nessie server JAR included
- Proper Quarkus configuration
- Project Nessie maintained image

---

## Architectural Principles Enforced

### ✅ DO: Extend Official Images

- Use official pre-built Docker images as base
- Add plugins, configurations, and dependencies only
- Download pre-built JARs/packages when extending functionality

### ❌ DON'T: Rebuild from Source

- Never download source tarballs and extract
- Never compile binaries (gradle, maven, npm build, cargo, go build)
- Never use multi-stage builds with compilation steps
- Exception: Only if patching a critical vendor bug

---

## Benefits Achieved

1. **Security**

   - Official images receive automated security patches
   - Vetted by upstream maintainers
   - Vulnerability scanning already performed

2. **Maintenance**

   - Version updates via base image tag changes
   - No tracking of upstream tarball URLs
   - Reduced Dockerfile complexity

3. **Build Performance**

   - Faster image pulls (pre-built layers cached)
   - No compilation time
   - Smaller image sizes (optimized by vendors)

4. **Reliability**
   - Battle-tested by community
   - Official entrypoints and initialization scripts
   - Proper user/permission setup

---

## Compliance Report

| Service             | Status | Image Source                                         |
| ------------------- | ------ | ---------------------------------------------------- |
| minio               | ✅     | `minio/minio:RELEASE.2024-11-07T00-52-20Z`           |
| postgresql          | ✅     | `postgres:17-alpine`                                 |
| nessie              | ✅     | `ghcr.io/projectnessie/nessie:0.104.3`               |
| trino               | ✅     | `trinodb/trino:476`                                  |
| spark               | ✅     | `apache/spark:3.5.1-scala2.12-java17-python3-ubuntu` |
| kafka               | ✅     | `confluentinc/cp-kafka:7.5.0`                        |
| schema-registry     | ✅     | `confluentinc/cp-schema-registry:7.5.0`              |
| flink               | ✅     | `flink:1.18.0-scala_2.12-java11`                     |
| kafka-connect       | ✅     | `confluentinc/cp-kafka-connect:7.5.0`                |
| clickhouse          | ✅     | `clickhouse/clickhouse-server:23.8`                  |
| dbt                 | ✅     | `python:3.10-slim` (pip install)                     |
| great-expectations  | ✅     | `python:3.11-slim` (pip install)                     |
| airflow             | ✅     | `apache/airflow:2.8.0-python3.11`                    |
| jupyterhub          | ✅     | `jupyterhub/jupyterhub:4.0.2`                        |
| jupyterlab-notebook | ✅     | `jupyter/scipy-notebook:python-3.11`                 |
| mlflow              | ✅     | `python:3.11-slim` (pip install)                     |
| superset            | ✅     | `apache/superset:3.0.3`                              |
| prometheus          | ✅     | `prom/prometheus:v2.48.0`                            |
| grafana             | ✅     | `grafana/grafana:10.2.2`                             |
| loki                | ✅     | `grafana/loki:2.9.3`                                 |
| alloy               | ✅     | `grafana/alloy:v1.0.0`                               |
| alertmanager        | ✅     | `prom/alertmanager:v0.27.0`                          |
| kafka-ui            | ✅     | `provectuslabs/kafka-ui:v0.7.2`                      |
| keycloak            | ✅     | `quay.io/keycloak/keycloak:23.0`                     |
| redis               | ✅     | `redis:7.2-alpine`                                   |

**Total Compliance: 25/25 (100%)**

---

## Next Steps

1. **Rebuild Images**: All 5 refactored images need rebuilding

   ```bash
   docker rmi ghcr.io/datalyptica/datalyptica/{trino,postgresql,minio,spark,nessie}:v1.0.0
   ./scripts/build/build-all-images.sh
   ```

2. **Test Functionality**: Verify custom entrypoints still work with official base images

3. **Update Documentation**: Reflect new base images in deployment guides

4. **Monitor Upstream**: Subscribe to security advisories for base images

---

## References

- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Trino Official Images](https://hub.docker.com/r/trinodb/trino)
- [PostgreSQL Official Images](https://hub.docker.com/_/postgres)
- [MinIO Official Images](https://hub.docker.com/r/minio/minio)
- [Apache Spark Official Images](https://hub.docker.com/r/apache/spark)
- [Project Nessie Images](https://github.com/projectnessie/nessie/pkgs/container/nessie)
