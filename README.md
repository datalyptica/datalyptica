# Shugur Data Lakehouse Platform (ShuDL)

A comprehensive on-premises Data Lakehouse Platform with Apache Iceberg, Project Nessie, MinIO, PostgreSQL with Patroni HA, Trino, Spark, and more.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MinIO S3      │    │   PostgreSQL    │    │   Nessie        │
│   Object Store  │    │   + Patroni     │    │   Catalog       │
│   (Port 9000)   │    │   (Port 5432)   │    │   (Port 19120)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Trino         │    │   Spark         │    │   Lakehouse     │
│   Query Engine  │    │   Compute       │    │   Manager       │
│   (Port 8080)   │    │   (Port 4040)   │    │   Portal        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
shudl/
├── docker/                         # Docker-based deployment
│   ├── .env                        # Environment configuration
│   ├── docker-compose.yml          # Main Docker Compose file
│   ├── env-manager.sh              # Environment management script
│   ├── test-config.sh              # Configuration validation
│   ├── README-config.md            # Configuration documentation
│   ├── services/                   # Service Docker images
│   │   ├── minio/
│   │   │   ├── Dockerfile
│   │   │   └── scripts/
│   │   │       └── entrypoint.sh
│   │   ├── postgresql/
│   │   │   ├── Dockerfile
│   │   │   └── scripts/
│   │   │       └── init-db.sh
│   │   ├── patroni/
│   │   │   ├── Dockerfile
│   │   │   ├── config/
│   │   │   │   └── patroni.yml
│   │   │   └── scripts/
│   │   │       └── entrypoint.sh
│   │   ├── nessie/
│   │   │   └── Dockerfile
│   │   ├── trino/
│   │   │   ├── Dockerfile
│   │   │   └── scripts/
│   │   │       └── start-trino.sh
│   │   └── spark/
│   │       ├── Dockerfile
│   │       └── scripts/
│   │           └── start-spark.sh
│   └── config/                     # External configurations
│       ├── minio/
│       │   └── minio.conf
│       ├── postgresql/
│       │   ├── postgresql.conf
│       │   └── pg_hba.conf
│       ├── nessie/
│       │   └── application.properties
│       ├── trino/
│       │   ├── config.properties
│       │   ├── node.properties
│       │   └── log.properties
│       └── spark/
│           ├── spark-defaults.conf
│           └── spark-env.sh
```

## 🐳 Docker Image Standards

### Base Images
- **Alpine Base**: Lightweight base with common utilities
- **Java Base**: OpenJDK 17 with common Java tools

### Service Images
All service images follow these standards:
- Inherit from appropriate base image
- Use non-root user (`app`)
- Include health checks
- Proper metadata labels
- Optimized layer caching
- Security best practices

### Configuration Standards
- All configurations externalized to `docker/config/<service>/`
- Mounted via Docker Compose volumes
- Environment-specific overrides
- No hardcoded secrets

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- At least 8GB RAM
- 20GB disk space

### Start the Platform
```bash
# Clone the repository
git clone https://github.com/Shugur-Network/shudl.git
cd shudl

# Navigate to docker directory
cd docker

# Configure environment (recommended)
./env-manager.sh setup dev

# Start all services
docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs -f
```

### Access Services
- **MinIO Console**: http://localhost:9001 (admin/password123)
- **Trino**: http://localhost:8080
- **Spark UI**: http://localhost:4040
- **Nessie API**: http://localhost:19120/api/v2

> 💡 **Tip**: Use `./env-manager.sh show` to see current credentials

## 🔧 Configuration

### Configuration Management

ShuDL uses an environment-based configuration system managed through Docker Compose:

```bash
# Navigate to docker directory
cd docker

# Setup development environment
./env-manager.sh setup dev

# Setup production environment (requires password updates)
./env-manager.sh setup prod

# Validate current configuration
./env-manager.sh validate

# Show current configuration (secrets hidden)
./env-manager.sh show

# Test configuration
./test-config.sh
```

### Environment Variables
All services use environment variables for configuration. These are managed through the `.env` file:

```bash
# Core Configuration
COMPOSE_PROJECT_NAME=shudl
POSTGRES_PASSWORD=nessie123
S3_SECRET_KEY=password123

# Performance Settings
TRINO_QUERY_MAX_MEMORY=2GB
SPARK_DRIVER_MEMORY=2g
```

For detailed configuration documentation, see [`docker/README-config.md`](docker/README-config.md).

### Environment Templates

ShuDL provides environment templates for different deployment scenarios:

- **Development** (`.env.dev`): Lower resources, development passwords
- **Production** (`.env.prod`): Production resources, secure password placeholders

```bash
# Use development template
cd docker
./env-manager.sh setup dev

# Use production template (remember to update passwords!)
./env-manager.sh setup prod
```

**Configuration Features:**
- ✅ Environment-based configuration (no config file mounting)
- ✅ 160+ configurable parameters
- ✅ Security-focused (credentials via environment variables)
- ✅ Easy environment switching (dev/staging/prod)
- ✅ Comprehensive validation and testing
- ✅ Template-based configuration
- ✅ Runtime environment validation

### Volume Mounts
- **Data Volumes**: Persistent storage for databases
- **Config Volumes**: External configuration files
- **Log Volumes**: Application logs

## 🛠️ Development

### Building Images

#### Option 1: Use the build script (Recommended)
```bash
# Build all images locally in correct dependency order
./build-all-images.sh

# Push all images to registry (requires authentication)
./push-all-images.sh
```

#### Option 2: Use the original build script
```bash
# Build all images
./docker/build.sh
```

#### Option 3: Build individual images
```bash
# Build specific service
docker build -t ghcr.io/shugur-network/shudl/minio:latest docker/services/minio/

# Build base image
docker build -t ghcr.io/shugur-network/shudl/base-alpine:latest docker/base/alpine/
```

### CI/CD Pipeline

The GitHub Actions workflow automatically:
- **Builds all images** on `main` branch pushes
- **Builds changed images** on pull requests and feature branches  
- **Performs security scans** with Trivy on all images
- **Supports manual triggers** via workflow dispatch

**Manual CI Trigger:**
1. Go to Actions tab in GitHub
2. Select "Build and Push Images" workflow
3. Click "Run workflow" 
4. Check "Force build all images" to rebuild everything

### Testing
```bash
# Run integration tests
./scripts/test-integration.sh

# Run unit tests
./scripts/test-unit.sh
```

## 📊 Monitoring

### Health Checks
All services include health checks:
- **MinIO**: HTTP health endpoint
- **PostgreSQL**: `pg_isready` command
- **Nessie**: API health check
- **Trino**: HTTP info endpoint
- **Spark**: Web UI health check

### Logging
- Structured logging with consistent format
- Log rotation and retention policies
- Centralized log collection

## 🔒 Security

### Best Practices
- Non-root containers
- Minimal attack surface
- Regular security updates
- Secrets management
- Network isolation

### Authentication
- MinIO: Access key/secret key
- PostgreSQL: Username/password
- Nessie: JWT tokens (configurable)
- Trino: Password authentication
- Spark: Kerberos (optional)

## 📈 Scaling

### Horizontal Scaling
- **MinIO**: Multi-node cluster
- **PostgreSQL**: Read replicas
- **Trino**: Multiple workers
- **Spark**: Multiple executors

### Vertical Scaling
- Adjust memory and CPU limits
- Optimize JVM settings
- Configure connection pools

## 🐛 Troubleshooting

### Common Issues
1. **Port conflicts**: Check if ports are already in use
2. **Memory issues**: Increase Docker memory limits
3. **Network issues**: Verify Docker network connectivity
4. **Permission issues**: Check file permissions

### Debug Commands
```bash
# Check service logs
docker-compose logs <service>

# Access container shell
docker-compose exec <service> sh

# Check service health
docker-compose ps

# View resource usage
docker stats
```

## 📚 Documentation

- [Architecture Guide](docs/architecture.md)
- [API Reference](docs/api.md)
- [Deployment Guide](docs/deployment.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/Shugur-Network/shudl/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Shugur-Network/shudl/discussions)
- **Email**: devops@shugur.com
# Test workflow trigger