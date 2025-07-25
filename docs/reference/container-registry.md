# ShuDL Container Registry

## Available Images

All ShuDL images are published to GitHub Container Registry (GHCR) under the `ghcr.io/shugur-network/shudl/` namespace.

### Base Images

| Image | Latest | Version | Size | Description |
|-------|--------|---------|------|-------------|
| `base-alpine` | `latest` | `v1.0.0` | ~50MB | Alpine Linux foundation with `shusr` user and common utilities |
| `base-java` | `latest` | `v1.0.0` | ~200MB | Eclipse Temurin Java runtime with `shusr` user |
| `base-postgresql` | `latest` | `v1.0.0` | ~150MB | PostgreSQL base image with `shusr` user for database services |

### Service Images

| Image | Latest | Version | Size | Description |
|-------|--------|---------|------|-------------|
| `minio` | `latest` | `v1.0.0` | ~100MB | MinIO S3-compatible object storage with `shusr` user |
| `postgresql` | `latest` | `v1.0.0` | ~155MB | Standalone PostgreSQL database for development |
| `patroni` | `latest` | `v1.0.0` | ~350MB | High-availability PostgreSQL with Patroni for production |
| `nessie` | `latest` | `v0.104.2` | ~300MB | Git-like data catalog with JDBC backend |
| `trino` | `latest` | `v448` | ~400MB | Distributed SQL query engine with REST catalog integration |
| `spark` | `latest` | `v3.5` | ~450MB | Apache Spark with Iceberg support for big data processing |

## Usage

### Pull Images

```bash
# Pull latest versions of all base images
docker pull ghcr.io/shugur-network/shudl/base-alpine:latest
docker pull ghcr.io/shugur-network/shudl/base-java:latest
docker pull ghcr.io/shugur-network/shudl/base-postgresql:latest

# Pull latest service images
docker pull ghcr.io/shugur-network/shudl/minio:latest
docker pull ghcr.io/shugur-network/shudl/postgresql:latest
docker pull ghcr.io/shugur-network/shudl/patroni:latest
docker pull ghcr.io/shugur-network/shudl/nessie:latest
docker pull ghcr.io/shugur-network/shudl/trino:latest
docker pull ghcr.io/shugur-network/shudl/spark:latest

# Pull specific versions
docker pull ghcr.io/shugur-network/shudl/nessie:v0.104.2
docker pull ghcr.io/shugur-network/shudl/trino:v448
docker pull ghcr.io/shugur-network/shudl/spark:v3.5
```

### Build and Push New Images

```bash
# Build service image locally
docker build -t ghcr.io/shugur-network/shudl/service:latest ./docker/services/service/

# Tag with version
docker tag ghcr.io/shugur-network/shudl/service:latest ghcr.io/shugur-network/shudl/service:v1.0.0

# Push both tags
docker push ghcr.io/shugur-network/shudl/service:latest
docker push ghcr.io/shugur-network/shudl/service:v1.0.0
```

## Registry Authentication

### Setup GitHub Container Registry Access

1. **Create Personal Access Token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with `write:packages` permission

2. **Login to Registry**:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin
   ```

3. **Verify Access**:
   ```bash
   docker pull ghcr.io/shugur-network/shudl/base-alpine:latest
   ```

## Image Architecture

### Dependencies

The images follow a layered architecture for optimization:

```
base-alpine (Foundation)
    ├── base-postgresql
    │   ├── postgresql (Standalone DB)
    │   └── patroni (HA DB)
    ├── base-java
    │   ├── nessie (Catalog)
    │   ├── trino (Query Engine)
    │   └── spark (Compute Engine)
    └── minio (Object Storage)
```

### User Standardization

All images use the standardized `shusr` user:
- **User ID**: 1000
- **Group ID**: 1000
- **Purpose**: Non-root execution for enhanced security

## Building Images

### Local Development

```bash
# Build all images locally
cd docker
./build-local.sh

# Build from root directory
cd ..
./build-all-images.sh
```

### CI/CD Integration

The GitHub Actions workflow automatically:
- Builds images on `main` branch pushes
- Performs security scans with Trivy
- Pushes to GHCR with proper tags
- Supports manual workflow triggers

## Version Management

### Tagging Strategy

- **`latest`**: Always points to the most recent stable build
- **`v{version}`**: Specific version tags (e.g., `v1.0.0`, `v0.104.2`)
- **Component versions**: Service-specific versions (e.g., Nessie `v0.104.2`, Trino `v448`)

### Compatibility Matrix

| ShuDL Version | Nessie | Trino | Spark | MinIO | PostgreSQL |
|---------------|--------|-------|-------|-------|------------|
| v1.0.0 | 0.104.2 | 448 | 3.5 | Latest | 16 |

## Security & Scanning

### Security Features

- **Minimal base images**: Alpine Linux for reduced attack surface
- **Non-root execution**: All services run as `shusr` user
- **Regular updates**: Base images updated with security patches
- **Vulnerability scanning**: Automated Trivy scans in CI/CD

### Security Scan Results

All images are scanned for vulnerabilities before publication. Check the [Actions](https://github.com/Shugur-Network/shudl/actions) tab for latest scan reports.

## Registry Cleanup

### Automated Cleanup

GitHub Container Registry automatically:
- Retains latest 10 versions of each image
- Removes untagged images after 7 days
- Keeps versioned releases indefinitely

### Manual Cleanup

```bash
# Clean local images
docker image prune -f

# Remove specific image versions
docker rmi ghcr.io/shugur-network/shudl/service:old-version
```

## Troubleshooting

### Common Issues

1. **Authentication failures**:
   ```bash
   # Verify token permissions
   echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin
   ```

2. **Pull rate limits**:
   ```bash
   # Authenticate to increase rate limits
   docker login ghcr.io
   ```

3. **Image not found**:
   ```bash
   # Check available tags
   curl -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://ghcr.io/v2/shugur-network/shudl/base-alpine/tags/list
   ```

### Support

For registry-related issues:
- Check [GitHub Container Registry documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- File issues in the [ShuDL repository](https://github.com/Shugur-Network/shudl/issues)

## Integration

These container images integrate seamlessly with:
- **Docker Compose**: Standard orchestration
- **Docker Run Script**: Alternative deployment method
- **Kubernetes**: Helm charts in `charts/lakehouse/`
- **Web Installer**: Go-based deployment API
- **CI/CD**: Automated building and testing

For complete platform documentation, see the [main README](../README.md).
