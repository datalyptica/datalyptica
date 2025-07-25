# Image Architecture

## Overview

The ShuDL platform uses a layered image architecture to optimize for different deployment scenarios while maintaining code reuse and security best practices.

## Image Hierarchy

```
base-alpine (Base OS)
    ├── base-postgresql (Shared PostgreSQL)
    │   ├── postgresql (Standalone)
    │   └── patroni (HA)
    ├── base-java (Java Runtime)
    │   ├── nessie
    │   ├── trino
    │   └── spark
    └── minio
```

## Image Details

### Base Images

#### `base-alpine`
- **Purpose**: Lightweight base with common utilities
- **Size**: ~50MB
- **Features**: curl, wget, bash, non-root user
- **Used by**: All service images

#### `base-java`
- **Purpose**: Java runtime environment
- **Size**: ~200MB
- **Features**: OpenJDK 21, common utilities
- **Used by**: Java-based services (Nessie, Trino, Spark)

### PostgreSQL Images

#### `base-postgresql`
- **Purpose**: Shared PostgreSQL installation
- **Size**: ~150MB
- **Features**: PostgreSQL 16, basic configuration
- **Inherits from**: `base-alpine`
- **Used by**: `postgresql`, `patroni`

#### `postgresql` (Standalone)
- **Purpose**: Simple PostgreSQL for development/standalone
- **Size**: ~155MB
- **Features**: Basic initialization, no replication
- **Inherits from**: `base-postgresql`
- **Use case**: Docker Compose, local development

#### `patroni` (HA)
- **Purpose**: PostgreSQL with high availability
- **Size**: ~350MB
- **Features**: Patroni, Python, Kubernetes DCS, automatic failover
- **Inherits from**: `base-postgresql`
- **Use case**: Production Kubernetes deployments

### Service Images

#### `minio`
- **Purpose**: Object storage server
- **Size**: ~100MB
- **Features**: MinIO server, client tools
- **Inherits from**: `base-alpine`

#### `nessie`
- **Purpose**: Catalog server for data lakehouse
- **Size**: ~300MB
- **Features**: Nessie server, JDBC backend
- **Inherits from**: `base-java`

#### `trino`
- **Purpose**: SQL query engine
- **Size**: ~400MB
- **Features**: Trino server, Iceberg plugin
- **Inherits from**: `base-java`

#### `spark`
- **Purpose**: Apache Spark for data processing
- **Size**: ~500MB
- **Features**: Spark master/worker, Iceberg support
- **Inherits from**: `base-java`

## Benefits of This Architecture

### 1. **Optimized Resource Usage**
- **Standalone**: ~155MB (minimal overhead)
- **HA**: ~350MB (includes Patroni + dependencies)
- **Shared layers**: Reduces storage and bandwidth

### 2. **Security**
- **Minimal attack surface**: Each image contains only necessary packages
- **Non-root execution**: All images run as non-privileged user
- **Regular updates**: Base images can be updated independently

### 3. **Maintainability**
- **Single responsibility**: Each image has one clear purpose
- **Code reuse**: Shared base images reduce duplication
- **Clear dependencies**: Inheritance chain is explicit

### 4. **Operational Clarity**
- **Different health checks**: Standalone vs. HA have different monitoring
- **Different logging**: Each mode has appropriate log levels
- **Different troubleshooting**: Clear procedures for each deployment type

## Deployment Scenarios

### Development (Docker Compose)
```yaml
services:
  postgresql:
    image: ghcr.io/org/repo/postgresql:latest
    # Simple standalone PostgreSQL
```

### Production (Kubernetes)
```yaml
# PostgreSQL HA with Patroni
- image: ghcr.io/org/repo/patroni:latest
  # Automatic failover, etcd coordination
```

## Build Process

### 1. Base Images
```bash
# Build base images first
docker build -t ghcr.io/org/repo/base-alpine docker/base/alpine/
docker build -t ghcr.io/org/repo/base-java docker/base/java/
```

### 2. PostgreSQL Images
```bash
# Build shared base
docker build -t ghcr.io/org/repo/base-postgresql docker/base/postgresql/

# Build specific variants
docker build -t ghcr.io/org/repo/postgresql docker/services/postgresql/
docker build -t ghcr.io/org/repo/patroni docker/services/patroni/
```

### 3. Service Images
```bash
# Build service images
docker build -t ghcr.io/org/repo/minio docker/services/minio/
docker build -t ghcr.io/org/repo/nessie docker/services/nessie/
docker build -t ghcr.io/org/repo/trino docker/services/trino/
docker build -t ghcr.io/org/repo/spark docker/services/spark/
```

The GitHub Actions workflow builds images in the correct order:
1. Base images (`base-alpine`, `base-java`)
2. PostgreSQL base (`base-postgresql`)
3. Service images (`postgresql`, `patroni`, `minio`, `nessie`, `trino`, `spark`)

Each image is published as a separate package in the container registry for optimal discoverability and versioning.

## Best Practices

### 1. **Layer Optimization**
- Install packages in single RUN command
- Remove package caches in same layer
- Use multi-stage builds for complex dependencies

### 2. **Security**
- Run as non-root user
- Use specific package versions
- Regular security updates

### 3. **Monitoring**
- Health checks for each image type
- Appropriate log levels
- Metrics endpoints where applicable

### 4. **Documentation**
- Clear image purposes
- Usage examples
- Troubleshooting guides 