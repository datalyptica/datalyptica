# Shugur Data Lakehouse Platform (ShuDL)

A comprehensive on-premises Data Lakehouse Platform with Apache Iceberg, Project Nessie, MinIO, PostgreSQL, Trino, and Spark.

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

## 🚀 Quick Start

**Get running in 5 minutes**:

### Web Installer (Recommended)
```bash
git clone https://github.com/Shugur-Network/shudl.git
cd shudl
go build -o bin/installer cmd/installer/main.go
./bin/installer
# Open http://localhost:8080
```

### Docker Compose (Traditional)
```bash
cd docker
cp .env.dev .env
docker compose up -d
```

**👉 [Complete Quick Start Guide](docs/getting-started/quick-start.md)**

## 🎯 Service Endpoints

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| **Web Installer** | http://localhost:8080 | - |
| **MinIO Console** | http://localhost:9001 | admin / password123 |
| **Trino** | http://localhost:8080 | - |
| **Spark UI** | http://localhost:4040 | - |
| **Nessie API** | http://localhost:19120 | - |

## 📚 Documentation

### 🏁 Getting Started
- **[Quick Start](docs/getting-started/quick-start.md)** - Get running in 5 minutes
- **[Migration Guide](docs/getting-started/migration-guide.md)** - Upgrading from previous versions

### 🚀 Deployment
- **[Deployment Guide](docs/deployment/deployment-guide.md)** - Complete deployment overview
- **[Web Installer](docs/deployment/web-installer.md)** - Interactive deployment with REST API
- **[Docker Compose](docs/deployment/deployment-guide.md#docker-compose)** - Standard orchestration
- **[Docker Commands](docs/deployment/docker-commands.md)** - Individual container control
- **[Kubernetes](docs/deployment/deployment-guide.md#kubernetes)** - Production clusters

### 💻 Development
- **[Building Images](docker/README.md)** - Docker image development
- **[Contributing](docs/development/contributing.md)** - How to contribute
- **[Testing](docs/development/testing.md)** - Test infrastructure
- **[API Reference](docs/development/api-reference.md)** - REST API documentation

### 🔧 Operations
- **[Configuration](docs/operations/configuration.md)** - Environment management
- **[Monitoring](docs/operations/monitoring.md)** - Health checks and observability
- **[Troubleshooting](docs/operations/troubleshooting.md)** - Common issues
- **[Backup & Recovery](docs/operations/backup-recovery.md)** - Data management

### 📖 Reference
- **[Architecture](docs/reference/architecture.md)** - System architecture details
- **[Container Registry](docs/reference/container-registry.md)** - Available images
- **[Environment Variables](docs/reference/environment-variables.md)** - Configuration reference
- **[Service Endpoints](docs/reference/service-endpoints.md)** - URLs and ports

### 📝 Examples
- **[Basic Setup](docs/examples/basic-setup.md)** - Simple deployment
- **[Production Setup](docs/examples/production-setup.md)** - Production configuration
- **[Development Setup](docs/examples/development-setup.md)** - Development environment

## 🛠️ Key Features

- **🌐 Web-based Installer** - Interactive deployment and management
- **🐳 Multiple Deployment Options** - Docker Compose, Commands, Kubernetes
- **⚙️ Environment-based Configuration** - 160+ configurable parameters
- **🔒 Security-focused** - Non-root containers, credential management
- **📊 Built-in Monitoring** - Health checks and status reporting
- **🧪 Comprehensive Testing** - Automated validation and integration tests
- **📚 Complete Documentation** - Guides for all user types

## 🏗️ Platform Components

| Component | Version | Purpose |
|-----------|---------|---------|
| **Apache Iceberg** | 1.9.1 | Table format with ACID transactions |
| **Project Nessie** | 0.104.2 | Git-like data catalog with versioning |
| **MinIO** | Latest | S3-compatible object storage |
| **PostgreSQL** | 16 | Metadata store with optional Patroni HA |
| **Trino** | 448 | Distributed SQL query engine |
| **Apache Spark** | 3.5 | Big data processing framework |

## 🔧 Prerequisites

- **Docker & Docker Compose** (for containerized deployment)
- **Go 1.24+** (for web installer)
- **Kubernetes 1.21+** (for K8s deployment)
- **8GB+ RAM** (minimum for all services)
- **20GB+ disk space** (for data and images)

## 🆙 Upgrading

If upgrading from a previous version of ShuDL:

👉 **[Migration Guide](docs/getting-started/migration-guide.md)**

## 🐛 Troubleshooting

**Common issues**:
- **Port conflicts**: Check ports 8080, 9000, 9001, 5432, 19120, 4040
- **Memory issues**: Ensure Docker has 8GB+ RAM allocated
- **Service startup**: Check logs with `docker logs shudl-[service]`

👉 **[Complete Troubleshooting Guide](docs/operations/troubleshooting.md)**

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](docs/development/contributing.md) for details.

## 🆘 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/Shugur-Network/shudl/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Shugur-Network/shudl/discussions)
- 📧 **Email**: devops@shugur.com

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Ready to get started?** 👉 [Quick Start Guide](docs/getting-started/quick-start.md)