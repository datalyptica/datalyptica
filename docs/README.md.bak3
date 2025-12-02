# Datalyptica Docker Images Development

Technical documentation for developing, building, and managing Docker images for the Datalyptica platform.

> **For deployment**: See [Deployment Guide](../docs/deployment/deployment-guide.md)

## 🏗️ Image Architecture

### Layered Hierarchy

```
base-alpine (Base OS + shusr user)
    ├── base-postgresql (Shared PostgreSQL)
    │   ├── postgresql (Standalone)
    │   └── patroni (HA)
    ├── base-java (Java Runtime)
    │   ├── nessie
    │   ├── trino
    │   └── spark
    └── minio
```

### Image Specifications

| Image             | Size   | Base            | Purpose                      |
| ----------------- | ------ | --------------- | ---------------------------- |
| `base-alpine`     | ~50MB  | alpine:latest   | Foundation with `shusr` user |
| `base-java`       | ~200MB | base-alpine     | Eclipse Temurin Java runtime |
| `base-postgresql` | ~150MB | base-alpine     | PostgreSQL base setup        |
| `minio`           | ~100MB | base-alpine     | S3-compatible object storage |
| `postgresql`      | ~155MB | base-postgresql | Standalone database          |
| `patroni`         | ~350MB | base-postgresql | HA PostgreSQL cluster        |
| `nessie`          | ~300MB | base-java       | Data catalog service         |
| `trino`           | ~400MB | base-java       | SQL query engine             |
| `spark`           | ~450MB | base-java       | Data processing engine       |

## 🔧 Development Environment

### Prerequisites

- Docker 20.10+
- Docker Buildx (for multi-platform builds)
- 16GB+ RAM (for building all images)
- 50GB+ disk space

### User Standardization

All images use the standardized `shusr` user:

- **User ID**: 1000
- **Group ID**: 1000
- **Non-root execution**: Enhanced security
- **Consistent permissions**: Cross-service compatibility

## 🛠️ Building Images

### Local Development

```bash
# Build all images locally
./build-local.sh

# Build specific image categories
./build.sh base        # Base images only
./build.sh services    # Service images only

# Build individual images
docker build -t ghcr.io/datalyptica/datalyptica/nessie:latest -f services/nessie/Dockerfile services/nessie
```

### Multi-Platform Builds

```bash
# Setup buildx for multi-platform
docker buildx create --name multiarch --use

# Build for multiple platforms
./build.sh --platform linux/amd64,linux/arm64
```

### Build Order (Dependencies)

1. **base-alpine** (foundation)
2. **base-java**, **base-postgresql** (parallel, depend on base-alpine)
3. **Service images** (depend on appropriate base)

## 📦 Registry Management

### Authentication

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

### Pushing Images

```bash
# Push all images
./push.sh

# Push specific tag
./push.sh v1.2.0

# Push individual image
docker push ghcr.io/datalyptica/datalyptica/nessie:latest
```

### Tagging Strategy

- `latest`: Most recent stable build
- `v{major}.{minor}.{patch}`: Semantic versions
- `{component-version}`: Service-specific versions (e.g., `nessie-0.104.2`)

## 🗂️ Directory Structure

```
docker/
├── base/                      # Base images
│   ├── alpine/
│   │   ├── Dockerfile
│   │   └── scripts/
│   ├── java/
│   │   ├── Dockerfile
│   │   └── scripts/
│   └── postgresql/
│       ├── Dockerfile
│       └── scripts/
├── services/                  # Service images
│   ├── minio/
│   │   ├── Dockerfile
│   │   └── scripts/
│   ├── nessie/
│   │   ├── Dockerfile
│   │   └── scripts/
│   └── [other services]/
├── config/                    # Configuration templates
│   ├── nessie/
│   ├── trino/
│   └── [other configs]/
├── build-local.sh            # Local build script
├── build.sh                  # Multi-platform build script
├── push.sh                   # Registry push script
└── README.md                 # This file
```

## 🔍 Image Development

### Dockerfile Standards

- **Multi-stage builds**: Optimize image size
- **Layer caching**: Organize instructions for best caching
- **Security**: Non-root user, minimal attack surface
- **Health checks**: Include appropriate health check commands
- **Labels**: Proper metadata and annotations

### Example Service Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM ghcr.io/datalyptica/datalyptica/base-java:latest

LABEL maintainer="Datalyptica Team <devops@datalyptica.com>"
LABEL org.opencontainers.image.source="https://github.com/datalyptica/datalyptica"

# Install service-specific dependencies
RUN apk add --no-cache curl

# Copy application files
COPY --chown=shusr:shusr ./app /opt/service/
COPY --chown=shusr:shusr ./scripts/entrypoint.sh /usr/local/bin/

# Configure permissions
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER shusr

# Expose service port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
  CMD curl -f http://localhost:8080/health || exit 1

# Entry point
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

### Entrypoint Script Pattern

```bash
#!/bin/sh
# Standard entrypoint pattern

set -e

# Environment validation
: ${REQUIRED_VAR:?'REQUIRED_VAR must be set'}

# Generate configuration from environment
envsubst < /opt/service/config.template > /opt/service/config.properties

# Start service
exec "$@"
```

## 🧪 Testing Images

### Local Testing

```bash
# Test image build
docker build -t test-image:local -f services/nessie/Dockerfile services/nessie

# Test image run
docker run --rm -p 8080:8080 test-image:local

# Test health check
docker run --rm test-image:local curl -f http://localhost:8080/health
```

### Integration Testing

```bash
# Test with docker-compose
docker-compose -f docker-compose.test.yml up -d

# Run test suite
./test-images.sh
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The build process integrates with GitHub Actions:

- **Triggered on**: Push to main, pull requests
- **Multi-platform builds**: linux/amd64, linux/arm64
- **Security scanning**: Trivy vulnerability scanning
- **Registry push**: Automatic push to GHCR on main branch

### Manual CI Trigger

```bash
# Trigger manual build via GitHub Actions
# Go to Actions tab → "Build and Push Images" → "Run workflow"
```

## 🐛 Troubleshooting

### Build Issues

```bash
# Clear build cache
docker builder prune -f

# Build with no cache
docker build --no-cache -t image:tag .

# Debug build
docker build --progress=plain -t image:tag . 2>&1 | tee build.log
```

### Permission Issues

```bash
# Fix ownership for development
sudo chown -R $(id -u):$(id -g) .

# Check user in container
docker run --rm image:tag id
```

### Size Optimization

```bash
# Analyze image layers
docker history image:tag

# Compare image sizes
docker images | grep datalyptica

# Remove unused images
docker image prune -f
```

## 🔧 Configuration Management

Images support environment-based configuration:

- **No config file mounting**: Everything via environment variables
- **Template-based**: Configuration generated at runtime
- **Validation**: Built-in environment validation

### Configuration Examples

```bash
# Nessie configuration
NESSIE_CATALOG_NAME=lakehouse
NESSIE_STORE_TYPE=JDBC
QUARKUS_DATASOURCE_HOST=postgresql

# Trino configuration
TRINO_COORDINATOR=true
TRINO_DISCOVERY_URI=http://trino:8080
TRINO_QUERY_MAX_MEMORY=4GB

# Spark configuration
SPARK_MODE=master
SPARK_MASTER_URL=spark://spark:7077
SPARK_DRIVER_MEMORY=2g
```

## 🔗 Integration

These Docker images integrate with:

- **Deployment**: [Deployment guides](../docs/deployment/)
- **Registry**: [Container registry](../docs/reference/container-registry.md)
- **Architecture**: [System architecture](../docs/reference/architecture.md)
- **Main Platform**: [Project README](../README.md)

---

**For deployment instructions**: See [Deployment Guide](../docs/deployment/deployment-guide.md)
