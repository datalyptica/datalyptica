# Deployment Guide

Complete guide for deploying ShuDL in different environments and scenarios.

## 🚀 Deployment Options Overview

| Method | Best For | Complexity | Production Ready |
|--------|----------|------------|------------------|
| [Web Installer](#web-installer) | First-time users, development | ⭐ Easy | ✅ Yes |
| [Docker Compose](#docker-compose) | Traditional Docker users | ⭐⭐ Medium | ✅ Yes |
| [Docker Commands](#docker-commands) | Fine-grained control | ⭐⭐⭐ Advanced | ✅ Yes |
| [Kubernetes](#kubernetes) | Production clusters | ⭐⭐⭐⭐ Expert | ✅ Yes |

## 1. Web Installer

**Interactive deployment with web interface and REST API**

### Features
- 🌐 Web-based configuration interface
- 📊 Real-time service status monitoring
- 🔧 Dynamic compose file generation
- ✅ Built-in validation and testing
- 📚 Auto-generated API documentation

### Quick Start
```bash
# Build and start installer
go build -o bin/installer cmd/installer/main.go
./bin/installer

# Access web interface
open http://localhost:8080
```

### Configuration
```bash
# Custom configuration
SHUDL_SERVER_PORT=8081 ./bin/installer

# Production mode
SHUDL_LOGGER_ENVIRONMENT=production ./bin/installer
```

**Complete Documentation**: [Web Installer Guide](web-installer.md)

## 2. Docker Compose

**Standard Docker orchestration**

### Environment Setup
```bash
cd docker

# Development (lower resources)
cp .env.dev .env

# Production (update passwords!)
cp .env.prod .env
```

### Deployment Commands
```bash
# Start all services
docker compose up -d

# Start specific services
docker compose up -d minio postgresql nessie

# Scale services
docker compose up -d --scale spark-worker=3

# Check status
docker compose ps

# View logs
docker compose logs -f trino

# Stop services
docker compose down

# Complete cleanup (removes data!)
docker compose down -v
```

### Environment Configuration
The system uses 160+ environment variables for comprehensive configuration:

**Core Services**:
```bash
# PostgreSQL
POSTGRES_DB=shudl
POSTGRES_USER=nessie
POSTGRES_PASSWORD=secure_password

# MinIO
MINIO_ROOT_USER=admin
S3_SECRET_KEY=secure_key

# Nessie
NESSIE_CATALOG_NAME=lakehouse

# Trino
TRINO_COORDINATOR=true
TRINO_QUERY_MAX_MEMORY=4GB

# Spark
SPARK_DRIVER_MEMORY=2g
SPARK_EXECUTOR_MEMORY=2g
```

## 3. Docker Commands

**Individual Docker run commands for maximum control**

### Quick Start
```bash
cd docker
./run-docker.sh start
```

### Available Commands
```bash
# Start all services
./run-docker.sh start

# Check detailed status
./run-docker.sh status

# Stop services gracefully
./run-docker.sh stop

# Restart services
./run-docker.sh restart

# Complete cleanup (removes containers, networks, volumes)
./run-docker.sh cleanup

# Show help
./run-docker.sh help
```

### Features
- ✅ Complete container lifecycle management
- ✅ Proper dependency handling and startup order
- ✅ Detailed health monitoring and status reporting
- ✅ Graceful shutdown and cleanup options
- ✅ Individual container control

**Complete Documentation**: [Docker Commands Guide](docker-commands.md)

## 4. Kubernetes

**Production-ready Kubernetes deployment**

### Prerequisites
- Kubernetes cluster (1.21+)
- Helm 3.0+
- kubectl configured

### Deployment
```bash
# Add Helm repository (if available)
helm repo add shudl https://shugur-network.github.io/shudl

# Deploy with default values
helm install shudl charts/lakehouse/

# Custom values
helm install shudl charts/lakehouse/ -f my-values.yaml

# Check deployment
kubectl get pods -n shudl

# Access services
kubectl port-forward svc/trino 8080:8080
```

### High Availability Configuration
```yaml
# values.yaml
postgresql:
  enabled: false  # Use external managed database
  
patroni:
  enabled: true
  replicas: 3

minio:
  replicas: 4
  distributed: true

nessie:
  replicas: 2

trino:
  coordinator:
    replicas: 1
  worker:
    replicas: 3
```

## 🔧 Configuration Management

### Environment Templates

Choose the appropriate template for your use case:

```bash
# Development (local testing)
cp docker/.env.dev docker/.env

# Production (update passwords!)
cp docker/.env.prod docker/.env

# Custom configuration
cp docker/.env.example docker/.env
# Edit as needed
```

### Key Configuration Categories

1. **Database Settings**
   - PostgreSQL connection parameters
   - Connection pooling and timeouts
   - High availability configuration

2. **Object Storage**
   - MinIO access credentials
   - Bucket configuration
   - S3 compatibility settings

3. **Query Engine**
   - Trino memory allocation
   - Worker node configuration
   - Catalog connections

4. **Compute Engine**
   - Spark driver and executor resources
   - Dynamic allocation settings
   - Iceberg integration

5. **Security**
   - Authentication credentials
   - Network security settings
   - TLS/SSL configuration

## 📊 Monitoring & Health Checks

All deployment methods include comprehensive monitoring:

### Health Endpoints
```bash
# MinIO
curl http://localhost:9000/minio/health/live

# Nessie  
curl http://localhost:19120/api/v2/config

# Trino
curl http://localhost:8080/v1/info

# PostgreSQL
pg_isready -h localhost -p 5432 -U nessie
```

### Monitoring Commands
```bash
# Docker Compose
docker compose ps
docker compose logs service-name

# Docker Commands
./run-docker.sh status

# Kubernetes
kubectl get pods -n shudl
kubectl logs -f deployment/trino
```

## 🔒 Security Considerations

### Development vs Production

**Development**:
- Default passwords are acceptable
- HTTP connections are fine
- Minimal security configuration

**Production**:
- ❗ **Change all default passwords**
- ❗ **Enable TLS/SSL for external endpoints**
- ❗ **Configure firewall rules**
- ❗ **Use managed databases for HA**
- ❗ **Regular security updates**

### Production Security Checklist

- [ ] Update all passwords in `.env` file
- [ ] Enable TLS for external services
- [ ] Configure network security (firewalls, VPNs)
- [ ] Set up regular backups
- [ ] Enable audit logging
- [ ] Configure monitoring and alerting
- [ ] Regular security updates
- [ ] Access control and authentication

## 🗃️ Data Persistence

### Volume Management

All deployment methods provide data persistence:

**Docker Volumes**:
- `minio_data`: Object storage
- `postgresql_data`: Metadata and catalog
- `logs`: Application logs

**Backup Strategies**:
```bash
# Backup MinIO data
docker run --rm -v minio_data:/data -v $(pwd):/backup alpine tar czf /backup/minio-backup.tar.gz /data

# Backup PostgreSQL
docker exec shudl-postgresql pg_dump -U nessie nessie > nessie-backup.sql

# Kubernetes persistent volumes
kubectl get pv
```

## 🐛 Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check port usage
   netstat -tlnp | grep -E "9000|9001|5432|19120|8080|4040"
   
   # Solution: Change ports in .env file
   ```

2. **Memory Issues**
   ```bash
   # Check Docker memory allocation
   docker system info | grep -i memory
   
   # Solution: Increase Docker memory to 8GB+
   ```

3. **Service Dependencies**
   ```bash
   # Check startup order
   docker compose logs postgres
   docker compose logs nessie
   
   # Solution: Ensure PostgreSQL starts before Nessie
   ```

4. **Configuration Errors**
   ```bash
   # Validate environment
   cd docker && ./test-config.sh  # If available
   
   # Check compose file
   docker compose config
   ```

## 🚀 Scaling & Performance

### Horizontal Scaling

**Docker Compose**:
```bash
# Scale Spark workers
docker compose up -d --scale spark-worker=5

# Scale Trino workers  
docker compose up -d --scale trino-worker=3
```

**Kubernetes**:
```bash
# Scale deployment
kubectl scale deployment trino-worker --replicas=5

# Auto-scaling
kubectl autoscale deployment trino-worker --min=2 --max=10 --cpu-percent=80
```

### Performance Tuning

**Memory Allocation**:
```bash
# Trino (adjust in .env)
TRINO_QUERY_MAX_MEMORY=8GB
TRINO_MEMORY_HEAP_HEADROOM_PER_NODE=2GB

# Spark (adjust in .env)  
SPARK_DRIVER_MEMORY=4g
SPARK_EXECUTOR_MEMORY=4g
SPARK_EXECUTOR_CORES=4
```

## 📚 Additional Resources

- **Quick Start**: [Getting Started Guide](../getting-started/quick-start.md)
- **Configuration**: [Environment Variables Reference](../reference/environment-variables.md)
- **Operations**: [Monitoring Guide](../operations/monitoring.md)
- **Examples**: [Production Setup](../examples/production-setup.md)

## 🆘 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/Shugur-Network/shudl/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Shugur-Network/shudl/discussions)
- 📧 **Email**: devops@shugur.com 