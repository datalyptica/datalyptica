# ShuDL Configuration Management

This document describes the new environment-based configuration system for ShuDL, where all configuration is managed through environment variables defined in Docker Compose and `.env` files.

## Overview

Instead of maintaining separate configuration files for each service, all configuration is now:
- Defined as environment variables in `docker-compose.yml`
- Values provided through `.env` files
- Easily customizable for different environments (dev, staging, prod)
- Centrally managed and version controlled

## Quick Start

1. **Setup Development Environment:**
   ```bash
   ./env-manager.sh setup dev
   docker-compose up -d
   ```

2. **Setup Production Environment:**
   ```bash
   ./env-manager.sh setup prod
   # IMPORTANT: Edit .env and change all CHANGE_ME_* values!
   vim .env
   docker-compose up -d
   ```

3. **Custom Environment:**
   ```bash
   ./env-manager.sh setup custom
   # Follow interactive prompts
   docker-compose up -d
   ```

## File Structure

```
├── .env                           # Active environment configuration
├── .env.dev                       # Development template
├── .env.prod                      # Production template
├── docker-compose.yml             # Main compose file with env vars
├── docker-compose.override.yml    # Development overrides
└── env-manager.sh                 # Environment management script
```

## Environment Variables

### Global Configuration
- `COMPOSE_PROJECT_NAME`: Project name prefix for containers
- `NETWORK_NAME`: Docker network name

### PostgreSQL
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Database credentials
- `POSTGRES_MAX_CONNECTIONS`: Maximum database connections
- `POSTGRES_SHARED_BUFFERS`: Shared memory buffer size
- `POSTGRES_EFFECTIVE_CACHE_SIZE`: Cache size hint for planner

### MinIO Object Storage
- `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`: MinIO admin credentials
- `MINIO_API_PORT`, `MINIO_CONSOLE_PORT`: Service ports
- `MINIO_BUCKET_NAME`: Default bucket name
- `MINIO_REGION`: S3 region

### Nessie Catalog
- `NESSIE_PORT`: Service port
- `NESSIE_VERSION_STORE_TYPE`: Backend type (JDBC2)
- `NESSIE_WAREHOUSE_LOCATION`: Default warehouse location
- `NESSIE_CORS_*`: CORS configuration

### Trino Query Engine
- `TRINO_PORT`: Service port
- `TRINO_QUERY_MAX_MEMORY`: Maximum memory per query
- `TRINO_ICEBERG_*`: Iceberg catalog configuration

### Spark Compute Engine
- `SPARK_DRIVER_MEMORY`, `SPARK_EXECUTOR_MEMORY`: Memory allocation
- `SPARK_EXECUTOR_CORES`, `SPARK_EXECUTOR_INSTANCES`: Resource allocation
- `SPARK_ICEBERG_*`: Iceberg configuration

### S3/Storage (shared)
- `S3_ENDPOINT`: MinIO endpoint URL
- `S3_ACCESS_KEY`, `S3_SECRET_KEY`: S3 credentials
- `S3_REGION`: S3 region
- `S3_PATH_STYLE_ACCESS`: Enable path-style S3 access

### Health Checks
- `HEALTHCHECK_INTERVAL`: How often to run health checks
- `HEALTHCHECK_TIMEOUT`: Health check timeout
- `HEALTHCHECK_RETRIES`: Number of retries
- `HEALTHCHECK_START_PERIOD`: Grace period after container start

## Environment Management

### Environment Manager Script

The `env-manager.sh` script provides comprehensive environment management:

```bash
# Setup environments
./env-manager.sh setup dev     # Development environment
./env-manager.sh setup prod    # Production environment  
./env-manager.sh setup custom  # Interactive custom setup

# Manage configuration
./env-manager.sh validate      # Validate current config
./env-manager.sh show          # Show current settings (hides secrets)
./env-manager.sh backup        # Backup current .env
./env-manager.sh restore       # Restore from backup
```

### Environment Templates

#### Development (`.env.dev`)
- Lower resource allocation
- Insecure default passwords (for development only)
- Faster health checks
- Debug logging enabled

#### Production (`.env.prod`)
- Higher resource allocation
- Placeholder values for secure passwords
- Conservative health check timings
- Restricted CORS settings

## Migration from Configuration Files

The previous configuration files have been replaced as follows:

| Old Configuration File | New Environment Variables |
|------------------------|---------------------------|
| `docker/config/postgresql/postgresql.conf` | `POSTGRES_*` variables |
| `docker/config/trino/config.properties` | `TRINO_*` variables |
| `docker/config/trino/catalog/iceberg.properties` | `ICEBERG_*` and `S3_*` variables |
| `docker/config/spark/spark-defaults.conf` | `SPARK_*` variables |
| `docker/config/nessie/application.properties` | `NESSIE_*` and `QUARKUS_*` variables |

## Best Practices

### Security
1. **Never commit production credentials** to version control
2. **Change default passwords** in production environments
3. **Use environment-specific .env files** for different deployments
4. **Backup configurations** before making changes

### Resource Management
1. **Adjust memory settings** based on available resources
2. **Scale executor instances** based on workload
3. **Monitor health check intervals** to balance responsiveness and resource usage

### Development Workflow
1. **Use development environment** for local testing
2. **Test configuration changes** in development first
3. **Validate environment** before deployment
4. **Use override files** for temporary development changes

## Deployment Examples

### Local Development
```bash
# Setup and start development environment
./env-manager.sh setup dev
docker-compose up -d

# Check service health
docker-compose ps
```

### Staging Environment
```bash
# Create staging-specific configuration
cp .env.prod .env.staging
# Edit .env.staging with staging-specific values
vim .env.staging

# Deploy with staging config
ln -sf .env.staging .env
./env-manager.sh validate
docker-compose up -d
```

### Production Deployment
```bash
# Setup production environment
./env-manager.sh setup prod

# CRITICAL: Update all CHANGE_ME_* values
vim .env

# Validate before deployment
./env-manager.sh validate

# Deploy
docker-compose up -d
```

## Troubleshooting

### Configuration Issues
```bash
# Validate current configuration
./env-manager.sh validate

# Show current settings (secrets hidden)
./env-manager.sh show

# Check for missing variables
docker-compose config
```

### Service Issues
```bash
# Check service logs
docker-compose logs <service-name>

# Verify environment variables
docker-compose exec <service-name> env | grep POSTGRES
```

### Reset Configuration
```bash
# Backup current config
./env-manager.sh backup

# Reset to development defaults
./env-manager.sh setup dev
```

## Advanced Configuration

### Custom Environment Variables

You can add custom environment variables by:
1. Adding them to your `.env` file
2. Referencing them in `docker-compose.yml`
3. Using them in service entrypoint scripts

### Multi-Environment Deployment

For managing multiple environments:
```bash
# Create environment-specific files
cp .env .env.dev-local
cp .env .env.staging
cp .env .env.prod

# Switch between environments
ln -sf .env.staging .env
docker-compose up -d
```

### Override Files

Use Docker Compose override files for environment-specific customizations:
```bash
# Development with overrides
docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d

# Production (no overrides)
docker-compose up -d
```

This configuration system provides a flexible, maintainable approach to managing ShuDL deployments across different environments while keeping sensitive information secure and separate from the codebase.
