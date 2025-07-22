# ShuDL Docker Configuration Management

This directory contains the comprehensive Docker-based configuration for ShuDL Data Lakehouse, where all service configurations are managed through environment variables and Docker Compose.

## Overview

All configuration that was previously scattered across multiple configuration files in `config/` subdirectories is now:
- Centralized in environment variables defined in `.env`
- Applied through `docker-compose.yml` 
- Easily customizable for different environments
- Version controlled and maintainable

## Quick Start

```bash
# Navigate to docker directory
cd docker/

# Setup development environment
./env-manager.sh setup dev

# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

## File Structure

```
docker/
├── .env                           # Active environment configuration
├── .env.dev                       # Development template
├── .env.prod                      # Production template
├── docker-compose.yml             # Main compose file with all env vars
├── docker-compose.override.yml    # Development overrides (optional)
├── env-manager.sh                 # Environment management script
├── test-config.sh                 # Configuration validation script
└── config/                        # Legacy config files (reference only)
    ├── minio/
    ├── nessie/
    ├── postgresql/
    ├── spark/
    └── trino/
```

## Configuration Migration

All configuration from individual config files has been migrated to environment variables:

### PostgreSQL Configuration
**From:** `config/postgresql/postgresql.conf`  
**To:** `POSTGRES_*` environment variables

Key migrations:
- `listen_addresses = '*'` → `POSTGRES_LISTEN_ADDRESSES=*`
- `max_connections = 100` → `POSTGRES_MAX_CONNECTIONS=100`
- `shared_buffers = 128MB` → `POSTGRES_SHARED_BUFFERS=128MB`

### Nessie Configuration
**From:** `config/nessie/application.properties.template`  
**To:** `NESSIE_*` and `QUARKUS_*` environment variables

Key migrations:
- `quarkus.http.port=19120` → `NESSIE_PORT=19120`
- `nessie.version.store.type=JDBC2` → `NESSIE_VERSION_STORE_TYPE=JDBC2`
- `quarkus.http.cors=true` → `NESSIE_CORS_ENABLED=true`

### Trino Configuration
**From:** `config/trino/config.properties` and `config/trino/catalog/iceberg.properties`  
**To:** `TRINO_*` environment variables

Key migrations:
- `coordinator=true` → `TRINO_COORDINATOR=true`
- `query.max-memory=2GB` → `TRINO_QUERY_MAX_MEMORY=2GB`
- `iceberg.catalog.type=rest` → `TRINO_ICEBERG_CATALOG_TYPE=rest`

### Spark Configuration
**From:** `config/spark/spark-defaults.conf`  
**To:** `SPARK_*` environment variables

Key migrations:
- `spark.driver.memory=2g` → `SPARK_DRIVER_MEMORY=2g`
- `spark.sql.catalog.iceberg.uri=http://nessie:19120/api/v2` → `SPARK_ICEBERG_URI=http://nessie:19120/api/v2`
- `spark.serializer=org.apache.spark.serializer.KryoSerializer` → `SPARK_SERIALIZER=org.apache.spark.serializer.KryoSerializer`

## Environment Variables

### Core Service Configuration

| Service | Key Variables | Description |
|---------|---------------|-------------|
| **PostgreSQL** | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Database credentials |
| | `POSTGRES_SHARED_BUFFERS`, `POSTGRES_WORK_MEM` | Memory settings |
| **MinIO** | `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | Admin credentials |
| | `MINIO_API_PORT`, `MINIO_CONSOLE_PORT` | Service ports |
| **Nessie** | `NESSIE_PORT`, `NESSIE_VERSION_STORE_TYPE` | Server config |
| | `NESSIE_WAREHOUSE_LOCATION` | Catalog warehouse |
| **Trino** | `TRINO_QUERY_MAX_MEMORY`, `TRINO_ICEBERG_REST_URI` | Query engine config |
| **Spark** | `SPARK_DRIVER_MEMORY`, `SPARK_EXECUTOR_MEMORY` | Resource allocation |
| | `SPARK_ICEBERG_URI`, `SPARK_ICEBERG_WAREHOUSE` | Catalog integration |

### Shared Configuration

| Category | Variables | Description |
|----------|-----------|-------------|
| **S3/Storage** | `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` | Object storage access |
| **Health Checks** | `HEALTHCHECK_INTERVAL`, `HEALTHCHECK_RETRIES` | Service monitoring |
| **Network** | `COMPOSE_PROJECT_NAME`, `NETWORK_NAME` | Docker networking |

## Environment Management

### Using the Environment Manager

```bash
# Setup specific environments
./env-manager.sh setup dev     # Development (lower resources, dev passwords)
./env-manager.sh setup prod    # Production (higher resources, secure passwords)
./env-manager.sh setup custom  # Interactive custom setup

# Manage configuration
./env-manager.sh validate      # Validate current configuration
./env-manager.sh show          # Show settings (hides sensitive values)
./env-manager.sh backup        # Backup current .env
./env-manager.sh restore       # Restore from backup
```

### Environment Templates

#### Development (`.env.dev`)
- Development-friendly passwords (insecure)
- Lower resource allocation
- Debug logging enabled
- Faster health checks

#### Production (`.env.prod`)
- Placeholder values requiring secure passwords
- Production resource allocation
- Conservative health check timings
- Restricted CORS settings

## Configuration Validation

```bash
# Validate entire configuration
./test-config.sh

# Test specific components
./test-config.sh env          # Environment file validation
./test-config.sh compose      # Docker Compose validation
./test-config.sh connectivity # Service connectivity
./test-config.sh ports        # Port conflict detection
./test-config.sh summary      # Configuration summary
```

## Service Integration

### Service Dependencies
1. **PostgreSQL** starts first (foundational metadata store)
2. **MinIO** starts in parallel (object storage)
3. **Nessie** waits for PostgreSQL and MinIO
4. **Trino** and **Spark** wait for Nessie and MinIO

### Configuration Flow
1. Environment variables loaded from `.env`
2. Docker Compose substitutes variables
3. Services start with environment-based configuration
4. No external config file mounting required

## Development Workflow

### Local Development
```bash
cd docker/
./env-manager.sh setup dev
docker-compose up -d
```

### Testing Configuration Changes
```bash
# Backup current config
./env-manager.sh backup

# Make changes to .env
vim .env

# Validate changes
./test-config.sh

# Test with services
docker-compose up -d
```

### Switching Environments
```bash
# Development
./env-manager.sh setup dev
docker-compose up -d

# Production
./env-manager.sh setup prod
# Edit .env with secure passwords
vim .env
docker-compose up -d
```

## Service Access

After starting with `docker-compose up -d`:

| Service | URL | Description |
|---------|-----|-------------|
| MinIO Console | http://localhost:9001 | Object storage management |
| Nessie API | http://localhost:19120/api/v2 | Catalog REST API |
| Trino UI | http://localhost:8080 | Query engine interface |
| Spark Master UI | http://localhost:4040 | Spark cluster management |
| Spark Worker UI | http://localhost:4041 | Worker node status |

## Troubleshooting

### Configuration Issues
```bash
# Check for syntax errors
docker-compose config

# Validate environment
./test-config.sh

# Show resolved configuration
./env-manager.sh show
```

### Service Issues
```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs <service-name>

# Check environment variables inside container
docker-compose exec <service-name> env | grep POSTGRES
```

### Reset to Defaults
```bash
# Reset to development
./env-manager.sh backup
./env-manager.sh setup dev
docker-compose down -v
docker-compose up -d
```

## Migration from Legacy Configuration

If you were using the previous config file-based approach:

1. **Backup existing configuration:**
   ```bash
   cp .env .env.backup-$(date +%Y%m%d)
   ```

2. **Setup new environment:**
   ```bash
   ./env-manager.sh setup dev  # or prod
   ```

3. **Compare and adjust:**
   - Review your old config files in `config/` directories
   - Adjust environment variables in `.env` as needed
   - Validate with `./test-config.sh`

4. **Test and deploy:**
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

## Best Practices

1. **Never commit production credentials** to version control
2. **Use environment-specific .env files** for different deployments
3. **Validate configuration** before deploying
4. **Backup configurations** before making changes
5. **Use override files** for temporary development changes
6. **Monitor resource usage** and adjust memory settings accordingly

This approach provides a much cleaner, more maintainable configuration system while preserving all the functionality of the previous file-based configuration approach.
