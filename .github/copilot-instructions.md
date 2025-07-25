# GitHub Copilot Instructions for ShuDL

> **Project**: Shugur Data Lakehouse Platform (ShuDL)  
> **Purpose**: Comprehensive on-premises data lakehouse with Apache Iceberg, Nessie, MinIO, PostgreSQL, Trino, and Spark  
> **Architecture**: Multi-deployment platform with Docker Compose, Go-based installer, and Kubernetes support
> **Strategic Vision**: Transform ShuDL into a comprehensive, enterprise-grade Data Platform that combines the simplicity of Docker deployment with the scalability of Kubernetes-native solutions, positioning it as the "Stackable alternative" that's easier to get started with but scales to enterprise needs.

## 📋 Project Overview

ShuDL is a production-ready data lakehouse platform that combines:
- **Apache Iceberg 1.9.1**: Table format with ACID transactions and time travel
- **Project Nessie 0.104.2**: Git-like data catalog with versioning
- **MinIO**: S3-compatible object storage
- **PostgreSQL 16**: Metadata storage with optional Patroni HA
- **Trino 448**: Distributed SQL query engine
- **Apache Spark 3.5**: Big data processing framework
- **Go-based Installer**: Web interface for deployment management
- **Prometheus/Grafana**: Monitoring and observability

**Current Status**: Phase 1B Complete ✅ - Enhanced Data Platform Configurator with visual component selection, dependency mapping, real-time validation, and configuration export/import.

## 🎯 **Strategic Roadmap (5-Phase Enhancement Plan)**

### **Phase 1: Foundation Enhancement (4-6 weeks) - IN PROGRESS**
*Goal: Strengthen core platform with Stackable-inspired improvements*

#### **1.1 CLI Tool Development (`shudlctl`) - ✅ PARTIALLY COMPLETE**
- ✅ **Core Commands**: `deploy`, `status`, `logs` (basic implementation)
- 🔧 **Enhanced Commands**: `install`, `upgrade`, `backup`, `config`, `validate`, `template`
- 🔧 **Service Management**: `start`, `stop`, `restart`, `scale`
- 🔧 **Advanced Features**: Configuration management, template system

#### **1.2 Enhanced Web Configurator - ✅ COMPLETE**
- ✅ **Visual Component Selection**: Drag-and-drop interface
- ✅ **Dependency Mapping**: SVG-based service relationships
- ✅ **Real-time Validation**: Live configuration checks
- ✅ **Export/Import**: Configuration templates
- 🔧 **Deployment Wizard**: Step-by-step guidance

#### **1.3 Monitoring & Observability Stack - 🔧 IN PROGRESS**
- 🔧 **Prometheus**: Metrics collection
- 🔧 **Grafana**: Dashboards and visualization
- 🔧 **Alertmanager**: System alerts
- 🔧 **Structured Logging**: Centralized log management
- ✅ **Health Checks**: Comprehensive service monitoring

#### **1.4 Enhanced Documentation Hub - 🔧 PLANNED**
- 🔧 **Getting Started**: Quick deployment guides
- 🔧 **API Documentation**: Comprehensive API reference
- 🔧 **Best Practices**: Production deployment guides
- 🔧 **Migration Guides**: Version upgrade paths

### **Phase 2: Ecosystem Expansion (6-8 weeks) - PLANNED**
*Goal: Broaden supported tools to match Stackable's ecosystem*

#### **2.1 Stream Processing Layer**
- 🔧 **Apache Kafka**: Message streaming platform
- 🔧 **Apache NiFi**: Data ingestion and routing
- 🔧 **Kafka Connect**: External system integration
- 🔧 **Real-time Pipelines**: Stream processing templates

#### **2.2 Orchestration & Workflow**
- 🔧 **Apache Airflow**: Workflow orchestration
- 🔧 **Pre-built DAGs**: Common data operations
- 🔧 **Spark Integration**: Seamless job orchestration
- 🔧 **Pipeline Monitoring**: Workflow observability

#### **2.3 Analytics & Visualization**
- 🔧 **Apache Superset**: Data visualization platform
- 🔧 **JupyterHub**: Data science workflows
- 🔧 **Pre-configured Dashboards**: Ready-to-use analytics
- 🔧 **Notebook Templates**: Data exploration guides

#### **2.4 Data Quality & Governance**
- 🔧 **Data Validation**: Automated quality checks
- 🔧 **Schema Registry**: Data contract management
- 🔧 **Access Controls**: Role-based permissions
- 🔧 **Data Lineage**: Track data flow and transformations

### **Phase 3: Kubernetes Native (8-10 weeks) - PLANNED**
*Goal: Add Kubernetes deployment alongside Docker*

#### **3.1 ShuDL Kubernetes Operator**
- 🔧 **Custom Resources**: ShuDL-specific CRDs
- 🔧 **Automated Operations**: Deployment, scaling, updates
- 🔧 **Self-Healing**: Automatic recovery and maintenance
- 🔧 **Resource Management**: Optimal resource allocation

#### **3.2 Helm Charts Collection**
- 🔧 **Complete Chart Library**: All ShuDL components
- 🔧 **Configurable Values**: Environment-specific settings
- 🔧 **Multi-Cloud Support**: AWS, GCP, Azure deployment guides
- 🔧 **Upgrade Strategies**: Zero-downtime updates

#### **3.3 Multi-Environment Support**
- ✅ **Docker Compose**: Simple development/testing
- 🔧 **Kubernetes**: Enterprise scalable deployment
- 🔧 **Bare Metal**: On-premises direct installation
- 🔧 **Cloud Native**: Optimized cloud deployments

### **Phase 4: Data Mesh & Enterprise Features (10-12 weeks) - PLANNED**
*Goal: Position ShuDL as enterprise Data Mesh platform*

#### **4.1 Data Mesh Architecture**
- 🔧 **Domain-Oriented**: Data ownership patterns
- 🔧 **Self-Serve Platform**: Developer-friendly tools
- 🔧 **Federated Governance**: Distributed data management
- 🔧 **Data Products**: Catalog and discovery

#### **4.2 Security & Governance**
- 🔧 **Apache Ranger**: Fine-grained access control
- 🔧 **Keycloak**: Identity and access management
- 🔧 **Policy as Code**: Automated governance
- 🔧 **Audit Trails**: Comprehensive activity logging

#### **4.3 Commercial Service Models**
- ✅ **ShuDL Community**: Free, self-hosted version
- 🔧 **ShuDL Enterprise**: Paid with enterprise features
- 🔧 **ShuDL Managed**: Fully managed cloud service
- 🔧 **Professional Services**: Implementation and consulting

### **Phase 5: Advanced Platform Features (12+ weeks) - PLANNED**
*Goal: Differentiate from Stackable with unique innovations*

#### **5.1 AI/ML Integration**
- 🔧 **MLflow**: Complete ML lifecycle management
- 🔧 **Model Serving**: Production ML model deployment
- 🔧 **Feature Store**: Centralized feature management
- 🔧 **AutoML Pipelines**: Automated model training

#### **5.2 Advanced Data Lake Features**
- 🔧 **Real-time Ingestion**: High-throughput data pipelines
- 🔧 **Change Data Capture**: Live database replication
- 🔧 **Multi-table Transactions**: Complex data operations
- 🔧 **Automatic Optimization**: Self-tuning performance

#### **5.3 Developer Experience**
- 🔧 **ShuDL SDK**: Multi-language client libraries
- 🔧 **Interactive Playground**: Browser-based tutorials
- 🔧 **Local Development**: Lightweight dev environment
- 🔧 **Testing Framework**: Data pipeline testing tools

## 🏗️ Architecture Patterns

### **Platform Architecture**
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

### Deployment Options
1. **Go-based Web Installer**: Interactive deployment with REST API
2. **Docker Compose**: Traditional orchestration
3. **Docker Run Script**: Alternative with individual docker commands
4. **Kubernetes**: Production Helm chart deployment (Phase 3)

### Service Dependencies
1. **PostgreSQL** (foundational metadata store)
2. **MinIO** (object storage, parallel to PostgreSQL)
3. **Nessie** (depends on PostgreSQL + MinIO)
4. **Trino & Spark** (depend on Nessie + MinIO)

### Health Check System
- All services use standardized health checks
- Dependency management via Docker Compose `depends_on` with conditions
- Configurable timeouts, retries, and grace periods

## 🚀 Go-based Installer & Web Interface

### Installer Architecture
```
cmd/installer/main.go           # Application entry point
internal/
├── api/                       # REST API handlers
├── compose/                   # Dynamic compose generation
├── config/                    # Configuration management
└── docker/                    # Docker service management
```

### Key Features
- **REST API**: Full CRUD operations for Docker services
- **Dynamic Compose Generation**: Create docker-compose files based on user preferences
- **Service Selection**: Enable/disable individual services
- **Configuration Templates**: Development, production, and minimal presets
- **Swagger Documentation**: Auto-generated API docs at `/swagger/index.html`
- **Visual Component Selection**: Drag-and-drop service builder (Phase 1B)
- **Dependency Mapping**: SVG-based service relationships (Phase 1B)
- **Real-time Validation**: Live configuration validation (Phase 1B)

### API Endpoints
- `POST /api/v1/docker/start` - Start Docker services
- `POST /api/v1/docker/stop` - Stop Docker services
- `GET /api/v1/docker/status` - Service status
- `POST /api/v1/compose/generate` - Generate compose files
- `GET /api/v1/compose/services` - Available services
- `POST /api/v1/compose/validate` - Validate configuration

### Configuration Management
```go
type ComposeRequest struct {
    ProjectName string                    `json:"project_name"`
    Environment string                    `json:"environment"`
    Services    map[string]ServiceConfig  `json:"services"`
}
```

## 🔧 Configuration Management System

### Environment-Driven Configuration
- **Central Configuration**: All settings in `docker/.env` file
- **No Config File Mounting**: Dynamic generation from environment variables
- **Template-Based**: Development (`.env.dev`) and production (`.env.prod`) templates
- **160+ Environment Variables**: Comprehensive configuration coverage

### Key Development Principles
1. **Environment Variables First**: Always use environment variables for configuration, never hardcode values
2. **Dynamic Hostnames**: Services should use configurable hostnames, not hardcoded ones
3. **Simple Container Names**: Use simple service names (e.g., `nessie`) without project prefixes
4. **Comprehensive Validation**: Real-time validation with detailed feedback
5. **User Experience**: Intuitive interfaces with clear visual feedback
6. **Error Handling**: Graceful error handling with helpful error messages
7. **Testing**: Comprehensive testing at all levels (unit, integration, e2e)
8. **Stackable-Inspired**: Learn from Stackable's approach while maintaining ShuDL's simplicity

### Key Configuration Files
- `docker/.env` - Active environment configuration
- `docker/docker-compose.yml` - Service orchestration with env var substitution
- `docker/run-docker.sh` - Alternative Docker deployment script
- `configs/config.yaml` - Go installer configuration

### Configuration Templates
```bash
# Development template (lower resources)
cp docker/.env.dev docker/.env

# Production template (secure passwords required)
cp docker/.env.prod docker/.env
```

## 🐳 Docker Development Patterns

### Multi-Deployment Support
The platform supports multiple deployment methods:

#### 1. Web Installer (Recommended)
```bash
go build -o bin/installer cmd/installer/main.go
./bin/installer
# Navigate to http://localhost:8080
```

#### 2. Docker Compose (Traditional)
```bash
cd docker
cp .env.dev .env
docker compose up -d
```

#### 3. Docker Run Script (Alternative)
```bash
cd docker
./run-docker.sh start
```

### Image Architecture
- **Base Images**: `base-alpine`, `base-java`, `base-postgresql`
- **Service Images**: `minio`, `postgresql`, `patroni`, `nessie`, `trino`, `spark`
- **User Standardization**: All services use `shusr` user (UID 1000)
- **Container Images**: Custom `ghcr.io/shugur-network/shudl/*` images

### Build Scripts
```bash
# Build all images (root directory)
./build-all-images.sh

# Build local development images
cd docker && ./build-local.sh

# Build specific platform images
cd docker && ./build.sh
```

### Configuration Patterns
```yaml
# Environment variable substitution in docker-compose.yml
services:
  nessie:
    environment:
      QUARKUS_DATASOURCE_USERNAME: ${POSTGRES_USER:-nessie}
      QUARKUS_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:-nessie123}
```

### Service Configuration Examples
- **Nessie**: `NESSIE_CATALOG_NAME=lakehouse`
- **Trino**: `TRINO_COORDINATOR=true`, `TRINO_DISCOVERY_URI=http://trino:8080`
- **Spark**: `SPARK_MODE=master`, `SPARK_MASTER_URL=spark://spark:7077`
- **MinIO**: `MINIO_ROOT_USER=admin`, `S3_ENDPOINT=http://minio:9000`

### Container Lifecycle Management
- **Startup Order**: PostgreSQL → MinIO → Nessie → Trino/Spark
- **Health Dependencies**: `depends_on` with `condition: service_healthy`
- **Graceful Shutdown**: SIGTERM handling with configurable timeouts

### Volume Management
```yaml
volumes:
  minio_data:          # Object storage persistence
  postgresql_data:     # Database persistence
  logs:               # Application logs
```

### Networking Patterns
```yaml
networks:
  shunetwork:
    driver: bridge
    name: shunetwork
```

## 📁 Project Structure Understanding

```
shudl/
├── cmd/                          # Go applications
│   ├── installer/               # Web installer backend
│   └── shudlctl/               # CLI tool
├── internal/                    # Internal Go packages
│   ├── api/                    # API handlers and models
│   ├── cli/                    # CLI command implementations
│   ├── pkg/                    # Shared utilities
│   └── services/               # Business logic services
├── web/                        # Frontend assets
│   ├── src/                    # JavaScript source files
│   ├── static/                 # Static assets
│   └── templates/              # HTML templates
├── docker/                     # Docker service definitions
├── generated/                  # Generated configuration files
├── bin/                        # Built executables
├── scripts/                    # Utility scripts
└── docs/                       # Documentation
```

### Key Directories
- **`cmd/installer/`**: Go application entry point
- **`internal/`**: Private Go modules (API, compose generation, config management)
- **`docker/`**: All Docker-related files and configurations
- **`tests/`**: Automated testing infrastructure
- **`docs/`**: Technical documentation and guides

## 🔧 Development Workflows

### Local Development Setup
```bash
# 1. Clone and build installer
git clone https://github.com/Shugur-Network/shudl.git
cd shudl
go build -o bin/installer cmd/installer/main.go

# 2. Start web interface
./bin/installer

# 3. Or use direct Docker deployment
cd docker
cp .env.dev .env
docker compose up -d
```

### Environment Variable Patterns
- Prefix: Service-specific (e.g., `POSTGRES_`, `MINIO_`, `TRINO_`)
- Defaults: Sensible development defaults in `.env.dev`
- Overrides: Production values in `.env.prod`
- Validation: Built-in validation via Go installer

### Service Health Patterns
```bash
# MinIO Health Check
curl -f http://localhost:9000/minio/health/live

# Nessie Health Check  
curl -f http://localhost:19120/api/v2/config

# PostgreSQL Health Check
pg_isready -h localhost -p 5432 -U nessie
```

### Testing Patterns
```bash
# Run all tests
cd tests && ./run-tests.sh

# Health checks only
cd tests/health && ./test_all_services.sh

# Configuration validation
cd tests/config && ./test_env_vars.sh
```

## 🔄 Service Integration Patterns

### Nessie Catalog Integration
```yaml
# Trino catalog configuration
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest.uri=http://nessie:19120/iceberg/
```

### MinIO S3 Integration
```yaml
# S3 configuration for Iceberg
aws.endpoint=http://minio:9000
aws.path-style-access=true
aws.access-key-id=${S3_ACCESS_KEY}
aws.secret-access-key=${S3_SECRET_KEY}
```

### Container Initialization Patterns
- **Entrypoint Scripts**: Located in `docker/services/*/scripts/`
- **Environment Setup**: Service-specific environment variable processing
- **Health Checks**: HTTP endpoints or command-based validation
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
- **Web installer status**: Real-time service status via REST API

### Logging Patterns
- **Structured logging**: Consistent format across services
- **Service logs**: `docker compose logs <service>`
- **Debug logging**: Configurable log levels via environment variables
- **Go installer logs**: JSON and console logging with zerolog

## 🎯 Current Focus Areas

### **Immediate Priorities (Phase 1 Completion)**
1. **Fix CLI Issues**: Resolve `shudlctl deploy` and `shudlctl status` 500 errors
2. **Complete Service Integration**: Ensure all services start and communicate properly
3. **Enhanced Validation**: Improve real-time validation with better error messages
4. **Documentation**: Complete API documentation and user guides
5. **Monitoring Stack**: Add Prometheus/Grafana to Docker Compose
6. **CLI Enhancement**: Complete `shudlctl` command set

### **Next Phase (Phase 2 - Ecosystem Expansion)**
1. **Stream Processing**: Add Kafka, NiFi, Kafka Connect
2. **Orchestration**: Integrate Apache Airflow
3. **Analytics**: Add Apache Superset and JupyterHub
4. **Data Quality**: Implement validation and governance features

### **Long-term Roadmap (Phase 3-5)**
1. **Kubernetes Support**: Complete K8s deployment and management
2. **Data Mesh**: Enterprise Data Mesh platform features
3. **AI/ML Integration**: Advanced analytics capabilities
4. **Commercial Services**: Enterprise and managed service offerings

## 🎯 Common Tasks for AI Agents

### Configuration Tasks
- Environment variable management and validation
- Service dependency configuration
- Performance tuning (memory, connections, etc.)
- Security credential rotation
- Go installer configuration management

### Development Tasks  
- Service troubleshooting and debugging
- Integration testing between services
- Performance optimization
- Documentation updates
- API endpoint development and testing

### Infrastructure Tasks
- Docker image building and optimization
- Service orchestration improvements
- Health check refinements
- Resource allocation tuning
- Go application deployment and scaling

### Web Interface Development
- REST API endpoint development
- Swagger documentation updates
- Frontend interface enhancements
- Configuration validation logic

## 🎯 Success Metrics

### **Technical Metrics**
- **Deployment Time**: < 5 minutes for basic stack (Stackable-inspired target)
- **Service Uptime**: > 99.9% availability
- **Query Performance**: < 5 seconds for typical queries
- **Resource Usage**: Efficient resource utilization

### **User Experience Metrics**
- **Ease of Use**: Intuitive web interface (simpler than Stackable)
- **Configuration Time**: < 10 minutes for basic setup
- **Error Resolution**: Clear error messages and guidance
- **Documentation**: Comprehensive and up-to-date guides
- **CLI Adoption**: 80% of users prefer CLI over web (Stackable target)

### **Business Metrics**
- **Community Growth**: 1000+ GitHub stars
- **Enterprise Adoption**: 10+ paying customers
- **Market Position**: Top 3 in "Data Lakehouse Platforms"
- **Competitive Advantage**: Easier than Stackable, more comprehensive than alternatives

## 📚 Key Resources

- **Main README**: `/README.md` - Project overview and quick start
- **Installer Guide**: `/README-installer.md` - Go installer and API documentation
- **Migration Guide**: `/MIGRATION-GUIDE.md` - Upgrading from previous versions
- **Docker Guide**: `/docker/README.md` - Docker image building and management
- **Docker Run Guide**: `/docker/run-docker-README.md` - Alternative deployment method
- **Architecture Guide**: `/docs/image-architecture.md` - Container structure
- **Container Registry**: `/docs/container-registry.md` - Available images and versions

---

**Note**: This is a production-ready data lakehouse platform with multiple deployment options. Always test configuration changes in development environment first and follow the established patterns for consistency and maintainability. The goal is to position ShuDL as the "Stackable alternative" that's easier to get started with but scales to enterprise needs.
