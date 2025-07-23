# GitHub Copilot Instructions for ShuDL

> **Project**: Shugur Data Lakehouse Platform (ShuDL)  
> **Purpose**: Comprehensive on-premises data lakehouse with Apache Iceberg, Nessie, MinIO, PostgreSQL, Trino, and Spark  
> **Architecture**: Docker Compose orchestrated multi-service platform with environment-driven configuration

## 📋 Project Overview

ShuDL is a production-ready data lakehouse platform that combines:
- **Apache Iceberg**: Table format with ACID transactions and time travel
- **Project Nessie**: Git-like data catalog with versioning
- **MinIO**: S3-compatible object storage
- **PostgreSQL/Patroni**: Metadata storage with optional HA
- **Trino**: Distributed SQL query engine
- **Apache Spark**: Big data processing framework

## 🏗️ Architecture Patterns

### Docker Compose Stack Architecture
```
MinIO (Object Storage) ←→ Nessie (Catalog) ←→ PostgreSQL (Metadata)
    ↓                         ↓                      ↓
  Trino (Query Engine) ←→ Spark (Compute) ←→ Lakehouse Tables
```

### Service Dependencies
1. **PostgreSQL** (foundational metadata store)
2. **MinIO** (object storage, parallel to PostgreSQL)
3. **Nessie** (depends on PostgreSQL + MinIO)
4. **Trino & Spark** (depend on Nessie + MinIO)

### Health Check System
- All services use standardized health checks
- Dependency management via Docker Compose `depends_on` with conditions
- Configurable timeouts, retries, and grace periods

## 🔧 Configuration Management System

### Environment-Driven Configuration
- **Central Configuration**: All settings in `docker/.env` file
- **No Config File Mounting**: Dynamic generation from environment variables
- **Template-Based**: Development (`.env.dev`) and production (`.env.prod`) templates
- **160+ Environment Variables**: Comprehensive configuration coverage

### Key Configuration Files
- `docker/.env` - Active environment configuration
- `docker/docker-compose.yml` - Service orchestration with env var substitution
- `docker/env-manager.sh` - Environment management utilities
- `docker/test-config.sh` - Configuration validation and testing

### Configuration Patterns
```bash
# Environment setup
./env-manager.sh setup dev|prod|custom

# Validation
./test-config.sh

# Service access patterns
POSTGRES_*=    # Database configuration
MINIO_*=       # Object storage
NESSIE_*=      # Catalog service
TRINO_*=       # Query engine
SPARK_*=       # Compute engine
S3_*=          # Shared storage credentials
```

## 🐳 Docker Image Architecture

### Base Image Hierarchy
```
base-alpine (50MB)
├── base-postgresql → postgresql/patroni
├── base-java (200MB) → nessie/trino/spark
└── minio (standalone)
```

### Standardized User: `shusr` (UID 1000)
- All containers run as non-root user
- Consistent permissions across all services
- Security-focused design

### Service Images
- **minio**: S3-compatible storage (~100MB)
- **postgresql**: Standalone database (~155MB)  
- **patroni**: HA PostgreSQL (~350MB)
- **nessie**: Data catalog (~300MB)
- **trino**: Query engine (~400MB)
- **spark**: Data processing (~500MB)

## 🛠️ Development Workflows

### Quick Start Pattern
```bash
cd docker/
./env-manager.sh setup dev
docker compose up -d
docker compose ps
./test-config.sh
```

### Configuration Changes
```bash
# Backup current configuration
./env-manager.sh backup

# Edit configuration
vim .env

# Validate changes
./test-config.sh

# Apply changes
docker compose down
docker compose up -d
```

### Build and Deployment
```bash
# Build all images
./build-all-images.sh

# Push to registry
./push-all-images.sh

# Status checking
./docker/status.sh
```

## 📁 Important File Locations

### Docker Compose Stack
- `docker/docker-compose.yml` - Main orchestration file
- `docker/.env` - Active configuration
- `docker/services/*/` - Service-specific Dockerfiles and scripts
- `docker/config/*/` - Legacy configuration files (reference only)

### Infrastructure
- `infra/terraform/` - Infrastructure as Code
- `infra/ansible/` - Configuration management
- `charts/lakehouse/` - Kubernetes Helm charts

### Documentation
- `README.md` - Main project documentation
- `docker/README-config.md` - Configuration management guide
- `docs/` - Detailed technical documentation

## 🔍 Troubleshooting Patterns

### Service Health Checks
```bash
# Check all services
docker compose ps

# View service logs
docker compose logs <service-name>

# Check specific service health
docker compose exec <service> health-check-command
```

### Configuration Debugging
```bash
# Validate configuration
./test-config.sh

# Show resolved configuration
./env-manager.sh show

# Check environment variables in container
docker compose exec <service> env | grep POSTGRES
```

### Common Service Endpoints
- MinIO Console: `http://localhost:9001` (admin/password123)
- Trino UI: `http://localhost:8080`
- Spark Master UI: `http://localhost:4040`
- Nessie API: `http://localhost:19120/api/v2`

## 🚀 Development Best Practices

### When Making Changes

1. **Always backup configuration first**: `./env-manager.sh backup`
2. **Validate before applying**: Use `./test-config.sh`
3. **Follow dependency order**: PostgreSQL → MinIO → Nessie → Trino/Spark
4. **Check service health**: Use health checks and logs
5. **Test integration**: Verify services can communicate

### Code Patterns to Follow

#### Environment Variable Naming
- Service prefix: `POSTGRES_*`, `MINIO_*`, `NESSIE_*`, etc.
- Consistent naming: `SERVICE_COMPONENT_SETTING`
- Example: `TRINO_QUERY_MAX_MEMORY`, `SPARK_DRIVER_MEMORY`

#### Service Configuration Generation
- Use entrypoint scripts for dynamic config generation
- Generate config files from environment variables at runtime
- Example: `docker/services/trino/scripts/entrypoint.sh`

#### Health Check Implementation
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
  CMD ["health-check-command"]
```

### Iceberg Integration Patterns
- **Nessie REST Catalog**: `NESSIE_URI=http://nessie:19120/api/v2`
- **S3 Storage**: MinIO with path-style access
- **Table Format**: Parquet with Snappy compression
- **Catalog Configuration**: REST-based with shared credentials

## 🔒 Security Considerations

### Authentication Patterns
- **PostgreSQL**: Username/password authentication
- **MinIO**: Access key/secret key (S3-compatible)
- **Nessie**: Optional JWT authentication
- **Trino**: Basic authentication support
- **Cross-service**: Shared S3 credentials

### Network Security
- **Internal networking**: Docker bridge network isolation
- **External access**: Only necessary ports exposed
- **Service communication**: Internal hostname resolution

### Secrets Management
- **Environment variables**: All credentials via .env
- **No hardcoded secrets**: Template-based configuration
- **Production security**: Placeholder values requiring updates

## 📊 Monitoring and Observability

### Health Monitoring
- **Service health checks**: Automated container health validation
- **Dependency health**: `depends_on` with health conditions
- **Endpoint monitoring**: HTTP health endpoints for all services

### Logging Patterns
- **Structured logging**: Consistent format across services
- **Service logs**: `docker compose logs <service>`
- **Debug logging**: Configurable log levels via environment variables

## 🎯 Common Tasks for AI Agents

### Configuration Tasks
- Environment variable management and validation
- Service dependency configuration
- Performance tuning (memory, connections, etc.)
- Security credential rotation

### Development Tasks  
- Service troubleshooting and debugging
- Integration testing between services
- Performance optimization
- Documentation updates

### Infrastructure Tasks
- Docker image building and optimization
- Service orchestration improvements
- Health check refinements
- Resource allocation tuning

## 📚 Key Resources

- **Main README**: `/README.md` - Project overview and quick start
- **Configuration Guide**: `/docker/README-config.md` - Environment management
- **Image Architecture**: `/docs/image-architecture.md` - Container structure
- **Migration Documentation**: `/docker/MIGRATION-SUMMARY.md` - Configuration evolution

---

**Note**: This is a production-ready data lakehouse platform. Always test configuration changes in development environment first and follow the established patterns for consistency and maintainability.
