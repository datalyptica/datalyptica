# ShuDL Container Registry

## Available Images

All ShuDL images are published to GitHub Container Registry (GHCR) under the `ghcr.io/shugur-network/shudl/` namespace.

### Base Images

| Image | Latest | Version | Description |
|-------|--------|---------|-------------|
| `base-java` | `latest` | `v1.0.0` | Alpine-based Java 24 runtime with minimal dependencies |
| `base-postgresql` | `latest` | - | PostgreSQL base image for database services |

### Service Images

| Image | Latest | Version | Description |
|-------|--------|---------|-------------|
| `nessie` | `latest` | `v0.104.2` | Nessie data catalog with JDBC backend |
| `minio` | `latest` | `v1.0.0` | MinIO S3-compatible object storage |

## Usage

### Pull Images

```bash
# Pull latest versions
docker pull ghcr.io/shugur-network/shudl/base-java:latest
docker pull ghcr.io/shugur-network/shudl/nessie:latest
docker pull ghcr.io/shugur-network/shudl/minio:latest

# Pull specific versions
docker pull ghcr.io/shugur-network/shudl/nessie:v0.104.2
docker pull ghcr.io/shugur-network/shudl/base-java:v1.0.0
docker pull ghcr.io/shugur-network/shudl/minio:v1.0.0
```

### Build and Push New Images

```bash
# Build service image
docker build -t ghcr.io/shugur-network/shudl/service:latest ./docker/services/service/

# Tag with version
docker tag ghcr.io/shugur-network/shudl/service:latest ghcr.io/shugur-network/shudl/service:v1.0.0

# Push both tags
docker push ghcr.io/shugur-network/shudl/service:latest
docker push ghcr.io/shugur-network/shudl/service:v1.0.0
```

## Production Deployment

For production deployments, use specific version tags instead of `latest` to ensure reproducible deployments:

```yaml
# docker-compose.yml
services:
  nessie:
    image: ghcr.io/shugur-network/shudl/nessie:v0.104.2
    # ... rest of configuration
```

## Registry Authentication

To push images, ensure you're authenticated with GitHub Container Registry:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

## Image Hierarchy

```
ghcr.io/shugur-network/shudl/
├── base-java:latest, v1.0.0
├── base-postgresql:latest
├── nessie:latest, v0.104.2
└── minio:latest, v1.0.0
```

## Build Dependencies

- `base-java` → Used by `nessie` and other Java services
- `base-postgresql` → Used by PostgreSQL and Patroni services

## Health Checks

All service images include standardized health checks:

- **Nessie**: `curl -f http://localhost:19120/api/v2/config`
- **MinIO**: `curl -f http://localhost:9000/minio/health/live`

## Last Updated

Generated: $(date)
Images pushed: July 16, 2025
