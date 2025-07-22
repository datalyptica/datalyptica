# ShuDL Docker Images

This directory contains all Docker images for the ShuDL (Shugur Data Lakehouse) platform. All images have been standardized to use the `shusr` user (UID 1000) for consistent security and permissions.

## Architecture Overview

### Base Images
- **base-alpine**: Alpine Linux foundation with `shusr` user and common utilities
- **base-java**: Java runtime environment based on Eclipse Temurin with `shusr` user  
- **base-postgresql**: PostgreSQL base with `shusr` user and database setup

### Service Images
- **minio**: S3-compatible object storage
- **postgresql**: Standalone PostgreSQL database
- **patroni**: High-availability PostgreSQL with Patroni
- **nessie**: Git-like data catalog with REST API
- **trino**: Distributed SQL query engine
- **spark**: Apache Spark with Iceberg support

## User Standardization

All images now use the standardized `shusr` user:
- **User ID**: 1000
- **Group ID**: 1000
- **User Name**: shusr
- **Group Name**: shusr
- **Security**: Non-root execution for all services

## Build Scripts

### Quick Build and Status
```bash
# Build all images sequentially
./build-simple.sh

# Check build status
./status.sh

# Push to GitHub Container Registry
./push.sh
```

### Individual Image Builds
```bash
# Build base images first
docker build -t ghcr.io/shugur-network/shudl/base-alpine:latest -f base/alpine/Dockerfile base/alpine
docker build -t ghcr.io/shugur-network/shudl/base-java:latest -f base/java/Dockerfile base/java
docker build -t ghcr.io/shugur-network/shudl/base-postgresql:latest -f base/postgresql/Dockerfile base/postgresql

# Build service images
docker build -t ghcr.io/shugur-network/shudl/minio:latest -f services/minio/Dockerfile services/minio
docker build -t ghcr.io/shugur-network/shudl/postgresql:latest -f services/postgresql/Dockerfile services/postgresql
docker build -t ghcr.io/shugur-network/shudl/patroni:latest -f services/patroni/Dockerfile services/patroni
docker build -t ghcr.io/shugur-network/shudl/nessie:latest -f services/nessie/Dockerfile services/nessie
docker build -t ghcr.io/shugur-network/shudl/trino:latest -f services/trino/Dockerfile services/trino
docker build -t ghcr.io/shugur-network/shudl/spark:latest -f services/spark/Dockerfile services/spark
```

## Push to Registry

### Prerequisites
1. **GitHub Token**: Create a personal access token with `write:packages` permission
2. **Login**: Log in to GitHub Container Registry

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin

# Push all images
./push.sh

# Or push individually
docker push ghcr.io/shugur-network/shudl/base-alpine:latest
docker push ghcr.io/shugur-network/shudl/base-java:latest
docker push ghcr.io/shugur-network/shudl/base-postgresql:latest
docker push ghcr.io/shugur-network/shudl/minio:latest
docker push ghcr.io/shugur-network/shudl/postgresql:latest
docker push ghcr.io/shugur-network/shudl/patroni:latest
docker push ghcr.io/shugur-network/shudl/nessie:latest
docker push ghcr.io/shugur-network/shudl/trino:latest
docker push ghcr.io/shugur-network/shudl/spark:latest
```

## Image Dependencies

```
base-alpine
├── base-postgresql
│   ├── postgresql
│   └── patroni
├── minio
└── base-java
    ├── nessie
    ├── trino
    └── spark
```

## Key Changes (User Standardization)

### Before (Mixed Users)
- Nessie: custom `nessie` user
- Trino: custom `trino` user  
- Spark: custom `spark` user
- Others: various user configurations

### After (Standardized shusr)
- **All services**: `shusr` user (UID 1000)
- **Consistent permissions**: All services use same user/group
- **Security**: Non-root execution maintained
- **Compatibility**: Works with existing volume mounts and configs

## Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `build.sh` | Build all images with multi-platform support | `./build.sh [tag]` |
| `build-simple.sh` | Build all images sequentially | `./build-simple.sh` |
| `push.sh` | Push all images to registry | `./push.sh [tag]` |
| `status.sh` | Check build status and provide instructions | `./status.sh` |

## Configuration Files

Service-specific configurations are stored in `config/`:
- `minio/`: MinIO server configuration
- `nessie/`: Nessie application properties
- `postgresql/`: PostgreSQL server configuration
- `spark/`: Spark defaults and environment
- `trino/`: Trino server and catalog configurations

## Health Checks

All images include health checks:
- **MinIO**: `http://localhost:9000/minio/health/live`
- **Nessie**: `http://localhost:19120/api/v2/config`
- **Trino**: `http://localhost:8080/v1/info`
- **Spark**: `http://localhost:4040`
- **PostgreSQL**: `pg_isready -h localhost -p 5432`

## Troubleshooting

### Build Issues
```bash
# Check Docker daemon
docker version

# Clean build cache
docker system prune -f

# Build with verbose output
docker build --progress=plain -t <image-name> <context>
```

### Permission Issues
All services run as `shusr` (UID 1000). If you encounter permission issues:
```bash
# Fix ownership of mounted volumes
sudo chown -R 1000:1000 /path/to/volume
```

### Image Size Optimization
Images are optimized with:
- Multi-stage builds where applicable
- Minimal base images (Alpine Linux)
- Cleaned package caches
- Shared base layers

## Integration with ShuDL

These images are designed to work seamlessly with:
- **Docker Compose**: `../docker-compose.yml`
- **Kubernetes**: `../charts/lakehouse/`
- **Testing**: `../tmp/run_all_tests.sh`

For more information, see the main ShuDL documentation.