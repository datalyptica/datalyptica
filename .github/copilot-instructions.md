# ShuDL (Shugur Data Lakehouse Platform) - Copilot Instructions

## 🎯 **Project Overview**

**ShuDL (Shugur Data Lakehouse)** is a **production-ready, comprehensive data lakehouse platform** designed to replace legacy data infrastructure with a modern, scalable solution. The platform combines the economics of data lakes with the performance and governance of data warehouses, built on proven open-source components.

**Current Status**: ✅ **Production Ready** - Complete data lakehouse solution with CDC pipelines, stream processing, ACID transactions, and comprehensive testing (47 E2E scenarios covering all use cases).

**Core Capabilities**:

- ✅ **ACID Transactions**: Full transactional support via Apache Iceberg
- ✅ **Schema Evolution**: Flexible schema management without data migration
- ✅ **Time Travel**: Query historical data at any point in time
- ✅ **Unified Processing**: Batch (Spark) and streaming (Kafka/Flink) in one platform
- ✅ **Metadata Management**: Git-like versioning with Project Nessie
- ✅ **CDC Pipelines**: Real-time change data capture from operational databases
- ✅ **Security & Governance**: Fine-grained access control, audit logging, data lineage

**Architecture Philosophy**: Modern, cloud-native design with Docker Compose for simplicity and Kubernetes readiness for enterprise scale. Every component is production-tested and integration-verified.

## 🏗️ **Architecture & Technology Stack**

### **Core Components** (All Production-Ready)

**Data Lakehouse Foundation**:

- **Apache Iceberg 1.9.1**: ACID transactions, schema evolution, time travel
- **Project Nessie 0.104.2**: Git-like catalog with multi-table transactions
- **MinIO**: S3-compatible object storage (on-premises or cloud)
- **PostgreSQL 16**: Transactional metadata store with HA support

**Query & Compute Engines**:

- **Trino 448**: Distributed SQL for interactive analytics (< 1s queries)
- **Apache Spark 3.5**: Batch processing and ML workloads
- **DBT**: SQL transformations and semantic modeling

**Stream Processing**:

- **Apache Kafka 3.6**: Event streaming backbone (100K+ msg/sec)
- **Apache Flink 1.18**: Real-time stream processing
- **Debezium**: Change data capture from operational databases
- **Schema Registry**: Avro schema management (50-80% space savings)

**Analytics & Visualization**:

- **ClickHouse**: Real-time OLAP for dashboards (sub-second queries)
- **Kafka UI**: Visual stream monitoring
- **Apache Superset**: Self-service BI (planned)

**Operations & Governance**:

- **Prometheus/Grafana**: Metrics, dashboards, alerting
- **Loki/Alloy**: Centralized logging
- **Keycloak**: Identity and access management
- **Apache Airflow**: Workflow orchestration (planned)
- **Apache Ranger**: Fine-grained access control (planned)

### **Platform Architecture (Complete Stack)**

**CDC Pipeline Flow** (Real-world use case):

```
PostgreSQL → Debezium/Kafka Connect → Kafka → Flink → Iceberg/S3
   → Trino/DBT → ClickHouse → Power BI/Superset
```

**Layer Architecture**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Query/Semantic Layer                         │
│  Trino (8080) | DBT (8580) | ClickHouse (8123)                  │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│                     Storage/Catalog Layer                        │
│  MinIO (9000) | PostgreSQL (5432) | Nessie (19120)              │
│  Apache Iceberg (ACID Lakehouse)                                │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│                  Processing/Streaming Layer                      │
│  Spark (4040) | Kafka (9092) | Flink (8081)                     │
│  Kafka Connect (8083) | Schema Registry (8085)                  │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring/Security                           │
│  Prometheus (9090) | Grafana (3000) | Keycloak (8180)           │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 **Production Implementation Status**

### **✅ Core Data Lakehouse Features (Production Ready)**

#### **Data Storage & Catalog**

- ✅ **ACID Transactions**: Full transactional support via Iceberg table format
- ✅ **Schema Evolution**: Add/modify columns without data rewrite
- ✅ **Time Travel**: Query data as of any timestamp or snapshot
- ✅ **Partitioning**: Automatic partition pruning for query optimization
- ✅ **Compaction**: Background file optimization for performance
- ✅ **Versioning**: Git-like branching and tagging with Nessie
- ✅ **Multi-table Transactions**: Atomic commits across multiple tables

#### **Unified Data Processing**

- ✅ **Batch Processing**: Spark for large-scale data transformations
- ✅ **Stream Processing**: Kafka + Flink for real-time pipelines
- ✅ **CDC Pipelines**: Debezium for database change capture
- ✅ **SQL Transformations**: DBT for business logic and modeling
- ✅ **Interactive Queries**: Trino for sub-second analytics
- ✅ **Cross-Engine Access**: Data written by Spark readable by Trino (and vice versa)

#### **Security & Governance**

- ✅ **Access Control**: Keycloak IAM with OAuth2/OIDC
- ✅ **Audit Logging**: Comprehensive activity tracking
- ✅ **Data Lineage**: Track data flow from source to consumption
- ✅ **Encryption**: At-rest (MinIO) and in-transit (TLS)
- ✅ **Service Authentication**: Inter-service security
- 🔧 **Fine-grained Policies**: Apache Ranger integration (planned)

#### **Operations & Reliability**

- ✅ **Health Monitoring**: All 21 services with health checks
- ✅ **Metrics Collection**: Prometheus with 50+ service metrics
- ✅ **Dashboards**: Pre-configured Grafana visualizations
- ✅ **Log Aggregation**: Centralized logging with Loki
- ✅ **Alerting**: Configurable alerts via Alertmanager
- ✅ **Backup/Recovery**: Data persistence with volume management

#### **Scalability & Performance**

- ✅ **Horizontal Scaling**: Add workers for Spark, Kafka, Flink
- ✅ **Storage Optimization**: Avro compression (50-80% space savings)
- ✅ **Query Performance**: < 1s for interactive queries, 10K+ events/sec CDC
- ✅ **Resource Management**: Configurable CPU/memory limits per service
- ✅ **High Availability**: PostgreSQL with Patroni, MinIO erasure coding

#### **Comprehensive Testing & Validation**

- ✅ **47 E2E Scenarios**: Complete coverage of all data flows
- ✅ **CDC Pipeline Test**: Real-world change capture (12 scenarios)
- ✅ **Integration Tests**: Cross-engine data access validation
- ✅ **Performance Tests**: Throughput and latency benchmarks
- ✅ **Health Checks**: Automated service validation
- ✅ **Documented Guides**: Complete testing and troubleshooting docs

### **🔧 Technical Architecture**

#### **Deployment Models**

- **Docker Compose**: Production-ready single-node or multi-node deployment
- **Kubernetes**: Enterprise scale with Helm charts (Phase 3)
- **Container Registry**: `ghcr.io/shugur-network/shudl/*` (all services)
- **Configuration**: Environment-based with 160+ parameters
- **Networking**: Isolated networks (data, control, storage, monitoring)

#### **Data Flow Architecture**

```
Operational DB → CDC (Debezium) → Streaming (Kafka) → Processing (Flink/Spark)
    → Lakehouse (Iceberg/S3) → Semantic (Trino/DBT) → OLAP (ClickHouse)
    → Visualization (Power BI/Superset) | Orchestration (Airflow)
```

#### **Storage Architecture**

- **Object Storage**: MinIO S3-compatible (on-prem or cloud)
- **Table Format**: Apache Iceberg with Parquet/Avro files
- **Metadata Catalog**: Nessie with PostgreSQL backend
- **Schema Registry**: Confluent Schema Registry for Avro schemas
- **Persistence**: Docker volumes with backup strategies

#### **Management Tools**

- **Docker Compose**: Orchestration and lifecycle management
- **Monitoring**: Grafana dashboards for all services
- **Service Discovery**: DNS-based with predictable hostnames
- **Health Checks**: Automated validation of all components
- **Testing Suite**: Comprehensive E2E and integration tests

## 📁 **Project Structure**

```
shudl/
├── docker/                     # Docker service definitions
│   ├── docker-compose.yml     # Main orchestration file
│   ├── services/              # Service-specific configurations
│   └── config/                # Service configuration files
├── tests/                      # Comprehensive test suite
│   ├── e2e/                   # End-to-end tests (47 scenarios)
│   ├── integration/           # Cross-component tests
│   ├── unit/                  # Component tests
│   ├── health/                # Service health checks
│   └── helpers/               # Reusable test utilities
├── scripts/                    # Utility scripts
│   └── deployment/            # Deployment automation
├── configs/                    # Configuration management
│   ├── monitoring/            # Prometheus, Grafana, Loki
│   └── environment.example    # Environment variables template
└── docs/                       # Documentation
    ├── deployment/            # Deployment guides
    ├── reference/             # Architecture and API docs
    └── getting-started/       # Quick start guides
```

## 🎯 **Strategic Roadmap (5-Phase Enhancement Plan)**

### **Phase 1: Data Lakehouse Foundation - ✅ COMPLETE**

_Goal: Build production-ready data lakehouse with ACID transactions, schema evolution, and unified processing_

#### **1.1 ACID Transactions & Table Format - ✅ COMPLETE**

- ✅ **Apache Iceberg Integration**: Full ACID transaction support
- ✅ **Schema Evolution**: Add/modify columns without data migration
- ✅ **Time Travel**: Query historical data at any point in time
- ✅ **Partitioning**: Automatic partition pruning for optimization
- ✅ **Compaction**: Background file optimization

#### **1.2 Metadata Management & Versioning - ✅ COMPLETE**

- ✅ **Project Nessie Catalog**: Git-like versioning for data
- ✅ **Multi-table Transactions**: Atomic commits across tables
- ✅ **Branching & Tagging**: Isolate development and production data
- ✅ **Catalog API**: RESTful access to metadata
- ✅ **PostgreSQL Backend**: Transactional metadata store

#### **1.3 Unified Batch & Stream Processing - ✅ COMPLETE**

- ✅ **Apache Spark**: Batch processing and ML workloads
- ✅ **Apache Flink**: Real-time stream processing
- ✅ **Apache Kafka**: Event streaming backbone
- ✅ **Cross-Engine Access**: Trino ↔ Spark data interoperability
- ✅ **CDC Pipelines**: Database change capture with Debezium

#### **1.4 Security, Governance & Operations - ✅ COMPLETE**

- ✅ **Access Control**: Keycloak IAM with OAuth2/OIDC
- ✅ **Monitoring**: Prometheus + Grafana with 50+ metrics
- ✅ **Audit Logging**: Comprehensive activity tracking
- ✅ **Health Checks**: Automated service validation
- ✅ **Testing Framework**: 47 E2E scenarios covering all flows

### **Phase 2: Advanced Lakehouse Features (6-8 weeks) - PLANNED**

_Goal: Enhance lakehouse with advanced data management and optimization_

#### **2.1 Advanced Data Management**

- 🔧 **Table Maintenance**: Automated compaction and optimization
- 🔧 **Data Clustering**: Z-ordering for query performance
- 🔧 **Snapshot Management**: Retention policies and cleanup
- 🔧 **Incremental Processing**: Efficient incremental loads
- 🔧 **Merge Operations**: MERGE INTO for upserts/deletes

#### **2.2 Workflow Orchestration**

- 🔧 **Apache Airflow**: Production workflow orchestration
- 🔧 **Pre-built DAGs**: CDC, ETL, and maintenance workflows
- 🔧 **Spark Job Scheduling**: Automated batch processing
- 🔧 **Data Quality Checks**: Great Expectations integration
- 🔧 **Pipeline Monitoring**: End-to-end observability

#### **2.3 Analytics & Self-Service BI**

- 🔧 **Apache Superset**: Self-service data visualization
- 🔧 **Pre-configured Dashboards**: Business metrics templates
- 🔧 **SQL Lab**: Interactive query interface
- 🔧 **Semantic Layer**: Business-friendly data models
- 🔧 **Row-Level Security**: User-specific data access

#### **2.4 Enhanced Governance**

- 🔧 **Apache Ranger**: Fine-grained access policies
- 🔧 **Data Lineage**: Automated tracking with OpenLineage
- 🔧 **Data Quality**: Automated validation and profiling
- 🔧 **Compliance**: GDPR/CCPA support with data masking
- 🔧 **Audit Reports**: Comprehensive compliance reporting

### **Phase 3: Enterprise Scale & Cloud Native (8-10 weeks) - PLANNED**

_Goal: Enable enterprise-scale deployments with Kubernetes and multi-cloud support_

#### **3.1 Kubernetes Native Deployment**

- 🔧 **Helm Charts**: Complete Kubernetes deployment
- 🔧 **Kubernetes Operator**: Automated lifecycle management
- 🔧 **StatefulSets**: Distributed storage and compute
- 🔧 **Horizontal Pod Autoscaling**: Dynamic scaling based on load
- 🔧 **Service Mesh**: Istio integration for security and observability

#### **3.2 High Availability & Disaster Recovery**

- 🔧 **Multi-Zone Deployment**: Fault-tolerant across AZs
- 🔧 **Automated Backups**: Continuous backup to S3/GCS/Azure
- 🔧 **Point-in-Time Recovery**: Restore data to any timestamp
- 🔧 **Replication**: Multi-region data replication
- 🔧 **Failover**: Automated failover for critical services

#### **3.3 Multi-Cloud & Hybrid Deployment**

- ✅ **Docker Compose**: Simple development/testing
- 🔧 **AWS**: EKS, S3, RDS integration
- 🔧 **Azure**: AKS, Blob Storage, PostgreSQL integration
- 🔧 **GCP**: GKE, Cloud Storage, Cloud SQL integration
- 🔧 **Hybrid**: On-premises + cloud unified lakehouse

### **Phase 4: Data Mesh & Advanced Analytics (10-12 weeks) - PLANNED**

_Goal: Enable decentralized data ownership with federated governance_

#### **4.1 Data Mesh Architecture**

- 🔧 **Domain-Oriented Ownership**: Distributed data ownership model
- 🔧 **Data Products**: Discoverable, versioned data assets
- 🔧 **Self-Serve Platform**: Low-code data product creation
- 🔧 **Federated Governance**: Automated policy enforcement
- 🔧 **Data Contracts**: API-like interfaces for data products

#### **4.2 Advanced Analytics & ML**

- 🔧 **Feature Store**: Centralized feature management for ML
- 🔧 **Model Registry**: MLflow for model versioning
- 🔧 **Real-time Inference**: Online feature serving
- 🔧 **AutoML**: Automated model training and tuning
- 🔧 **Model Monitoring**: Track model performance and drift

#### **4.3 Data Product Catalog**

- 🔧 **Unified Catalog**: Discover all data assets
- 🔧 **Metadata Search**: Full-text search across schemas, tables, columns
- 🔧 **Data Preview**: Sample data and statistics
- 🔧 **Usage Analytics**: Track data product consumption
- 🔧 **Recommendations**: Suggest related datasets

### **Phase 5: Real-Time & AI-Powered Lakehouse (12+ weeks) - PLANNED**

_Goal: Real-time data processing with AI-powered insights and optimization_

#### **5.1 Real-Time Lakehouse**

- 🔧 **Real-time Upserts**: Sub-second CDC to lakehouse
- 🔧 **Streaming SQL**: Real-time analytics on streaming data
- 🔧 **Materialized Views**: Automatically updated aggregations
- 🔧 **Change Streams**: Subscribe to table changes
- 🔧 **Real-time OLAP**: Sub-second queries on fresh data

#### **5.2 AI-Powered Operations**

- 🔧 **Auto-Optimization**: ML-based query and storage optimization
- 🔧 **Anomaly Detection**: Automatic data quality monitoring
- 🔧 **Intelligent Partitioning**: ML-recommended partition strategies
- 🔧 **Cost Optimization**: AI-driven resource allocation
- 🔧 **Predictive Scaling**: Anticipate workload changes

#### **5.3 Advanced Integration & Developer Experience**

- 🔧 **Multi-Language SDK**: Python, Java, Go, Rust clients
- 🔧 **GraphQL API**: Flexible data access layer
- 🔧 **WebSocket Streaming**: Real-time data push to applications
- 🔧 **Local Development**: Lightweight Docker dev environment
- 🔧 **CI/CD Integration**: Automated testing and deployment

## 🎯 **Development Guidelines**

### **Code Style & Standards**

#### **Docker & Infrastructure**

- **Container Design**: Non-root containers, minimal base images
- **Security**: Proper credential management, network isolation
- **Monitoring**: Health checks, logging, metrics collection
- **Configuration**: Environment variables over hardcoded values
- **Networking**: Proper hostname resolution, service discovery

### **Key Development Principles**

1. **ACID First**: All data operations must maintain ACID guarantees through Iceberg
2. **Schema Evolution**: Support backward-compatible schema changes without data rewrite
3. **Cross-Engine Compatibility**: Data written by one engine must be readable by all others
4. **Environment Variables**: Always use environment variables for configuration, never hardcode
5. **Simple Container Names**: Use simple service names (e.g., `nessie`) without project prefixes
6. **Comprehensive Testing**: Test data flows end-to-end, not just individual components
7. **Security by Default**: Enable authentication, encryption, and audit logging
8. **Performance Targets**: < 1s queries, > 10K events/sec CDC, 50-80% compression

### **Configuration Management**

#### **Environment Variables**

- **Database**: `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- **Object Storage**: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `MINIO_BUCKET`
- **Catalog**: `NESSIE_URI`, `NESSIE_REF`, `NESSIE_AUTH_TYPE`
- **Compute**: `TRINO_PORT`, `SPARK_MASTER_URL`, `SPARK_WORKER_CORES`
- **Security**: `KEYCLOAK_URL`, `RANGER_ADMIN_PASSWORD`
- **Monitoring**: `PROMETHEUS_PORT`, `GRAFANA_PORT`, `LOKI_PORT`

#### **Dynamic Configuration Generation**

- **Docker Compose**: Generated from service selections and configuration
- **Environment Files**: Dynamic `.env` file generation with proper variable substitution
- **Service Dependencies**: Automatic dependency resolution and ordering
- **Network Configuration**: Dynamic network creation and service attachment

## 🚀 **Deployment & Operations**

### **Deployment Models**

#### **Docker Compose (Current)**

- **Single Node**: All services on one host
- **Multi-Node**: Distributed across multiple hosts
- **HA Setup**: High availability with Patroni, MinIO erasure coding

#### **Kubernetes (Planned - Phase 3)**

- **Helm Charts**: Complete Kubernetes deployment
- **Operator Pattern**: Custom controllers for lifecycle management
- **Multi-Cluster**: Cross-cluster replication and management


### **Monitoring & Observability**

#### **Health Checks**

- **Service Health**: Individual service health monitoring
- **Dependency Checks**: Service dependency validation
- **Resource Monitoring**: CPU, memory, disk usage
- **Network Connectivity**: Inter-service communication validation

#### **Logging**

- **Structured Logging**: JSON format with correlation IDs
- **Log Levels**: DEBUG, INFO, WARN, ERROR
- **Log Aggregation**: Centralized log collection and analysis
- **Audit Trail**: Security and compliance logging

## 🔑 **Critical Integration Patterns**

### **1. Iceberg + Nessie + S3 (MinIO) Integration**

This is the **core data lakehouse pattern** - all data flows through this:

```python
# Spark Integration Pattern
spark.sql.catalog.iceberg = org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.iceberg.catalog-impl = org.apache.iceberg.nessie.NessieCatalog
spark.sql.catalog.iceberg.uri = http://nessie:19120/api/v2  # Nessie for versioning
spark.sql.catalog.iceberg.warehouse = s3://lakehouse/      # MinIO S3 storage
spark.sql.catalog.iceberg.io-impl = org.apache.iceberg.aws.s3.S3FileIO

# Trino Integration Pattern (note: uses v1 API)
iceberg.catalog.type = nessie
iceberg.nessie-catalog.uri = http://nessie:19120/api/v1
iceberg.nessie-catalog.default-warehouse-dir = s3://lakehouse/
s3.endpoint = http://minio:9000
s3.path-style-access = true
```

**Why this matters**:

- Nessie provides Git-like branching for data
- Iceberg provides ACID transactions and time travel
- MinIO (S3) stores actual Parquet/Avro files
- Trino and Spark both query the same tables through Iceberg

### **2. CDC Pipeline Pattern** (Real-world use case)

**Complete flow**: PostgreSQL → Debezium → Kafka → Flink → Iceberg → Trino → ClickHouse

```bash
# 1. Source: PostgreSQL operational database
# 2. Debezium: Captures INSERT/UPDATE/DELETE as CDC events
# 3. Kafka: Streams CDC events (topic: dbserver1.public.table_name)
# 4. Flink: Processes events, enriches data, writes to Iceberg
# 5. Iceberg: Stores with ACID guarantees in S3/MinIO
# 6. Trino/DBT: Semantic layer and transformations
# 7. ClickHouse: Real-time OLAP for dashboards

# Test this flow:
./tests/e2e/cdc-pipeline.e2e.test.sh
```

**Event Format** (Debezium CDC):

```json
{
  "op": "c", // c=INSERT, u=UPDATE, d=DELETE
  "before": null, // Previous values (null for INSERT)
  "after": {
    // New values
    "id": 1,
    "customer_id": 101,
    "status": "pending"
  },
  "source": {
    "connector": "postgresql",
    "table": "orders",
    "ts_ms": 1732618800000
  }
}
```

### **3. Cross-Engine Data Access Pattern**

**Key insight**: Data written by one engine MUST be readable by others.

```bash
# Trino writes data
CREATE TABLE iceberg.analytics.daily_metrics (...);
INSERT INTO iceberg.analytics.daily_metrics VALUES (...);

# Spark reads the same data (no data copy!)
spark.sql("SELECT * FROM iceberg.analytics.daily_metrics")

# This works because:
# - Both use Iceberg table format
# - Both connect to same Nessie catalog
# - Both access same S3/MinIO storage
# - Iceberg provides schema evolution
```

**Test pattern**: `tests/integration/test_cross_engine.sh`

### **4. Service Discovery Pattern**

**Container Names vs. Hostnames**:

```bash
# Container names (external access):
docker-trino, docker-spark-master, docker-nessie

# Network hostnames (internal communication):
trino, spark-master, nessie, minio, kafka

# Example connection strings:
# - Spark master: spark://spark-master:7077
# - Nessie API: http://nessie:19120/api/v2
# - MinIO S3: http://minio:9000
# - Kafka: kafka:9092
```

### **5. Avro + Schema Registry Pattern**

**For efficient storage and schema evolution**:

```bash
# Kafka messages with Avro serialization
# - Schema Registry stores schemas (http://schema-registry:8081)
# - Producers register schemas automatically
# - Consumers fetch schemas by ID
# - Backward/forward compatibility enforced

# Debezium → Kafka → Flink pipeline uses Avro:
# - 50-80% space savings vs JSON
# - Schema evolution without data migration
# - Type safety across pipeline
```

### **6. Resource Configuration Pattern**

**Docker Compose service limits** (critical for production):

```yaml
deploy:
  resources:
    limits:
      cpus: "4.0"
      memory: 8G
    reservations:
      cpus: "2.0"
      memory: 4G
```

**Adjust based on workload**:

- **Development**: Min resources (2 CPU, 4GB RAM)
- **Testing**: Med resources (4 CPU, 8GB RAM)
- **Production**: Max resources (16 CPU, 32GB RAM)

## 🎯 **Current Focus Areas**

### **Production Readiness (Phase 1 Complete ✅)**

1. ✅ **ACID Transactions**: Full Iceberg support with time travel
2. ✅ **Schema Evolution**: Add/modify columns without data migration
3. ✅ **Unified Processing**: Batch (Spark) and streaming (Kafka/Flink) integration
4. ✅ **CDC Pipelines**: Real-world database change capture
5. ✅ **Cross-Engine Access**: Trino ↔ Spark data interoperability
6. ✅ **Comprehensive Testing**: 47 E2E scenarios validating all flows
7. ✅ **Security & Governance**: Keycloak IAM, audit logging, encryption

### **Next Phase (Phase 2 - Advanced Lakehouse Features)**

1. **Table Maintenance**: Automated compaction, snapshot management
2. **Workflow Orchestration**: Apache Airflow with pre-built DAGs
3. **Data Quality**: Great Expectations integration
4. **Self-Service BI**: Apache Superset with semantic layer
5. **Enhanced Governance**: Apache Ranger for fine-grained policies
6. **Data Lineage**: OpenLineage integration for automated tracking

### **Long-term Roadmap (Phase 3-5)**

1. **Enterprise Scale**: Kubernetes, multi-cloud, high availability
2. **Data Mesh**: Decentralized ownership with federated governance
3. **Advanced Analytics**: Feature store, MLflow, AutoML
4. **Real-Time Lakehouse**: Sub-second CDC, streaming SQL, real-time OLAP
5. **AI-Powered Operations**: Auto-optimization, anomaly detection, cost optimization

## 🔧 **Development Workflow**

### **Local Development**

```bash
# Start all services
cd docker && docker compose up -d

# Build the CLI tool
go build -o bin/shudlctl cmd/shudlctl/main.go

# Deploy specific services
./bin/shudlctl deploy --services postgresql,minio,nessie --yes

# Check service status
./bin/shudlctl status
docker compose ps

# View service logs
docker logs docker-trino  # Note: container names are docker-*, not shudl-*

# Run tests
cd tests && ./run-e2e-suite.sh
```

### **Testing Strategy & Conventions**

#### **Container Naming**

- **Actual containers**: `docker-*` prefix (e.g., `docker-trino`, `docker-spark-master`)
- **NOT**: `shudl-*` prefix (legacy, no longer used)
- **Network hostnames**: Simple names without prefix (e.g., `nessie`, `minio`)

#### **Test Structure** (`tests/` directory)

```
tests/
├── e2e/                          # End-to-end tests (47 scenarios)
│   ├── cdc-pipeline.e2e.test.sh           # Real-world CDC flow (12 scenarios)
│   ├── complete-pipeline.e2e.test.sh      # Full data pipeline (8 scenarios)
│   ├── streaming-pipeline.e2e.test.sh     # Kafka streaming (9 scenarios)
│   ├── security-auth.e2e.test.sh          # Keycloak auth (8 scenarios)
│   └── monitoring-observability.e2e.test.sh # Monitoring (8 scenarios)
├── integration/                   # Cross-component tests
│   ├── test_cross_engine.sh              # Trino ↔ Spark data access
│   └── test_spark_iceberg.sh             # Spark-Iceberg integration
├── unit/                         # Component tests
│   ├── storage/                  # MinIO, PostgreSQL, Nessie
│   ├── compute/                  # Trino, Spark
│   ├── streaming/                # Kafka, Flink
│   └── monitoring/               # Prometheus, Grafana
├── health/                       # Service health checks
└── helpers/
    └── test_helpers.sh           # Reusable test utilities
```

#### **Test Execution Commands**

```bash
# Run all E2E tests (5 suites, 47 scenarios, ~125 seconds)
cd tests && ./run-e2e-suite.sh

# Run specific E2E test
./e2e/cdc-pipeline.e2e.test.sh              # CDC use case
./e2e/complete-pipeline.e2e.test.sh         # Data pipeline
./e2e/streaming-pipeline.e2e.test.sh        # Kafka streaming
./e2e/security-auth.e2e.test.sh             # Keycloak
./e2e/monitoring-observability.e2e.test.sh  # Monitoring

# Run all tests (health, unit, integration, e2e)
./run-tests.sh

# Run specific category
./run-tests.sh --category health
./run-tests.sh --category integration
```

#### **Test Helpers Usage**

```bash
# Execute Trino query (from test_helpers.sh)
execute_trino_query "SELECT * FROM iceberg.schema.table" 60

# Execute Spark SQL (from test_helpers.sh)
execute_spark_sql "CREATE SCHEMA iceberg.test" 30

# Generate test data (from test_helpers.sh)
generate_test_data "test_table" "test_schema" 1000

# Service health checks
wait_for_service "http://localhost:8080" "Trino" 60
check_http_endpoint "http://localhost:19120/api/v2/config" "Nessie"
```

### **Critical Testing Patterns**

#### **1. CDC Pipeline Testing** (Real-world use case)

```bash
# Test complete data flow: PostgreSQL → Debezium → Kafka → Flink → Iceberg → Trino → ClickHouse
./tests/e2e/cdc-pipeline.e2e.test.sh

# Validates:
# - Database change capture (INSERT/UPDATE/DELETE)
# - Kafka event streaming
# - Flink stream processing
# - Iceberg lakehouse storage with ACID
# - Trino semantic queries
# - ClickHouse real-time OLAP
```

#### **2. Cross-Engine Integration**

```bash
# Test data created by Trino can be read by Spark (and vice versa)
./tests/integration/test_cross_engine.sh

# Pattern: Always test both directions
# - Trino writes → Spark reads
# - Spark writes → Trino reads
```

#### **3. Spark Configuration** (Critical for Iceberg integration)

```python
# Always use these configs for Spark-Iceberg-Nessie:
SparkSession.builder \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.iceberg.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \
    .config("spark.sql.catalog.iceberg.uri", "http://nessie:19120/api/v2") \
    .config("spark.sql.catalog.iceberg.ref", "main") \
    .config("spark.sql.catalog.iceberg.warehouse", "s3://lakehouse/") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "admin") \
    .config("spark.hadoop.fs.s3a.secret.key", "password123") \
    .config("spark.hadoop.fs.s3a.path.style.access", "true") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.sql.catalog.iceberg.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
    .getOrCreate()
```

#### **4. Trino Configuration** (Critical for Nessie catalog)

```properties
# Trino Iceberg catalog configuration (docker/services/trino/scripts/entrypoint.sh)
connector.name=iceberg
iceberg.catalog.type=nessie
iceberg.nessie-catalog.uri=http://nessie:19120/api/v1  # Note: v1 for Trino
iceberg.nessie-catalog.default-warehouse-dir=s3://lakehouse/
iceberg.nessie-catalog.ref=main
fs.native-s3.enabled=true
s3.endpoint=http://minio:9000
s3.path-style-access=true
```

### **Quality Assurance Checklist**

#### **Before Committing Code**

1. ✅ **Container Names**: Use `docker-*` prefix in all test scripts
2. ✅ **Environment Variables**: Never hardcode, always use env vars
3. ✅ **Service Hostnames**: Use simple names (nessie, minio, trino) not prefixed
4. ✅ **Test Cleanup**: Always cleanup test resources in trap/finally blocks
5. ✅ **Error Handling**: Use `set -euo pipefail` in bash scripts
6. ✅ **Health Checks**: Wait for service availability before running tests

#### **Testing Requirements**

1. ✅ **Unit Tests**: All new components must have unit tests
2. ✅ **Integration Tests**: Cross-component interactions must be tested
3. ✅ **E2E Tests**: Major workflows must have end-to-end tests
4. ✅ **Health Checks**: All services must have health check tests
5. ✅ **Documentation**: Update test docs for new scenarios

#### **Performance Targets**

- **Query Latency**: < 1s for simple queries
- **Data Ingestion**: > 10 rows/second
- **Message Throughput**: > 20 messages/second
- **API Response**: < 300ms for REST calls
- **Test Suite Duration**: < 2 minutes for complete E2E suite

## 🎯 **Success Metrics**

### **Data Lakehouse Capabilities**

- **ACID Compliance**: 100% transactional consistency across all operations
- **Schema Evolution**: Zero downtime for schema changes
- **Time Travel**: Query any historical snapshot in < 2s
- **Query Performance**: < 1s for interactive queries, < 30s for complex analytics
- **CDC Throughput**: > 10,000 events/second end-to-end latency < 2s
- **Storage Efficiency**: 50-80% compression with Avro/Parquet

### **Reliability & Operations**

- **Service Uptime**: > 99.9% availability for production workloads
- **Data Durability**: 99.999999999% (11 nines) with erasure coding
- **Recovery Time**: < 5 minutes for automated failover
- **Monitoring Coverage**: 100% of services with health checks and metrics
- **Test Coverage**: 47 E2E scenarios covering all critical data flows

### **Scalability & Performance**

- **Horizontal Scaling**: Linear performance with worker nodes
- **Data Volume**: Support petabyte-scale data warehouses
- **Concurrent Users**: 100+ concurrent query users
- **Resource Efficiency**: < 50% CPU/memory for typical workloads
- **Cost Optimization**: 70% cost reduction vs. cloud data warehouses

### **Business Value**

- **Time to Value**: < 1 day to production-ready lakehouse
- **Legacy Replacement**: Complete replacement for traditional data warehouses
- **Compliance**: GDPR, CCPA, SOC2 ready with audit logging
- **Vendor Lock-in**: Zero - all open-source components
- **Total Cost of Ownership**: 80% lower than commercial alternatives

## 🚀 **Getting Started**

### **Quick Start (Production Deployment)**

1. **Clone Repository**: `git clone https://github.com/Shugur-Network/shudl.git`
2. **Deploy Lakehouse**: `cd docker && docker compose up -d`
3. **Verify Services**: `docker compose ps` (all services should be healthy)
4. **Create First Table**: Connect to Trino at http://localhost:8080
5. **Run CDC Pipeline**: Follow CDC_PIPELINE_GUIDE.md for real-world use case

### **For Production Workloads**

1. **Configure Resources**: Edit `docker-compose.yml` for CPU/memory limits
2. **Setup Security**: Configure Keycloak authentication
3. **Enable Monitoring**: Access Grafana at http://localhost:3000
4. **Setup Backups**: Configure automated backups to S3/Azure/GCS
5. **Test Data Flows**: Run comprehensive E2E tests with `cd tests && ./run-e2e-suite.sh`

### **For Development**

1. **Start Core Services**: `cd docker && docker compose up -d postgresql minio nessie trino`
2. **Verify Health**: `docker compose ps` and check health status
3. **Run Tests**: `cd tests && ./run-tests.sh`
4. **View Logs**: `docker logs docker-trino -f`
5. **Access Services**: See service port reference in Quick Reference section
6. **Stop Services**: `docker compose down` (keeps data) or `docker compose down -v` (removes data)

## 📚 **Quick Reference for AI Agents**

### **Essential Files to Understand**

1. **`docker/docker-compose.yml`** - Complete service definitions, networking, dependencies (21 services)
2. **`docker/services/*/`** - Service-specific configurations and entrypoint scripts
3. **`tests/e2e/cdc-pipeline.e2e.test.sh`** - Real-world CDC use case implementation (12 scenarios)
4. **`tests/helpers/test_helpers.sh`** - Reusable test utilities (Trino, Spark, data generation)
5. **`tests/integration/test_cross_engine.sh`** - Cross-engine data access patterns
6. **`CDC_PIPELINE_GUIDE.md`** - Complete architecture and implementation guide (500+ lines)
7. **`E2E_EXECUTION_GUIDE.md`** - Test execution and troubleshooting
8. **`configs/monitoring/`** - Prometheus, Grafana, Loki, Alertmanager configurations

### **Common Operations**

#### **Deploy & Test**

```bash
# Full deployment
cd docker && docker compose up -d && docker compose ps

# Run complete test suite
cd tests && ./run-e2e-suite.sh

# Test specific flow
./e2e/cdc-pipeline.e2e.test.sh           # CDC pipeline
./e2e/complete-pipeline.e2e.test.sh      # Data pipeline
./integration/test_cross_engine.sh       # Trino ↔ Spark
```

#### **Debug Services**

```bash
# Check service health
docker ps --filter health=healthy

# View logs
docker logs docker-trino -f
docker logs docker-spark-master --tail 100

# Execute queries
docker exec docker-trino /opt/trino/bin/trino --execute "SHOW CATALOGS"
```

#### **Test Data Operations**

```bash
# Trino: Create and query Iceberg tables
execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.test" 60
execute_trino_query "SELECT * FROM iceberg.schema.table LIMIT 10" 30

# Spark: Generate test data
generate_test_data "test_table" "test_schema" 1000

# Verify cross-engine access
./tests/integration/test_cross_engine.sh
```

### **Critical Environment Variables**

```bash
# Storage Layer
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=password123
S3_ENDPOINT=http://minio:9000

# Catalog Layer
NESSIE_URI=http://nessie:19120/api/v2
POSTGRES_HOST=postgresql
POSTGRES_USER=postgres

# Compute Layer
TRINO_PORT=8080
SPARK_MASTER_URL=spark://spark-master:7077

# Streaming Layer
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
SCHEMA_REGISTRY_URL=http://schema-registry:8081
```

### **Service Port Reference**

| Service      | Internal | External  | Purpose      |
| ------------ | -------- | --------- | ------------ |
| Trino        | 8080     | 8080      | SQL queries  |
| Spark Master | 7077     | 4040 (UI) | Spark jobs   |
| Nessie       | 19120    | 19120     | Catalog API  |
| MinIO        | 9000     | 9000      | S3 storage   |
| Kafka        | 9092     | 9092      | Streaming    |
| ClickHouse   | 8123     | 8123      | OLAP queries |
| Keycloak     | 8080     | 8180      | Auth/IAM     |
| Grafana      | 3000     | 3000      | Dashboards   |

### **Troubleshooting Patterns**

```bash
# Issue: Service not healthy
docker ps --format "table {{.Names}}\t{{.Status}}"
docker logs <service> --tail 50

# Issue: Container name mismatch
# Use: docker-* prefix (docker-trino, docker-spark-master)
# Not: shudl-* prefix (legacy)

# Issue: Trino can't access Iceberg
# Check: Nessie connection, S3 credentials, catalog config
docker exec docker-trino cat /opt/trino/etc/catalog/iceberg.properties

# Issue: Spark can't write to Iceberg
# Check: S3 config, Nessie URI (must be /api/v2), warehouse location

# Issue: Test failures
# Check: tests/logs/ directory for detailed output
tail -50 tests/logs/e2e-*.log
```

### **Documentation Index**

- **Architecture**: `docs/reference/architecture.md`
- **CDC Pipeline**: `CDC_PIPELINE_GUIDE.md` (500+ lines, complete guide)
- **E2E Testing**: `E2E_EXECUTION_GUIDE.md` (comprehensive test guide)
- **Quick Reference**: `E2E_QUICK_REFERENCE.md` (daily operations)
- **Container Registry**: `docs/reference/container-registry.md`
- **Environment Vars**: `docker/.env.example` (all configuration options)

### **Key Architectural Decisions**

1. **Iceberg as Table Format**: ACID transactions, time travel, schema evolution
2. **Nessie as Catalog**: Git-like branching for data, multi-table transactions
3. **MinIO for Storage**: S3-compatible, on-premises object storage
4. **Docker Compose First**: Simple deployment, then scale to Kubernetes
5. **Avro with Schema Registry**: Efficient serialization, schema evolution
6. **Test-Driven**: 47 E2E scenarios before production deployment
7. **Container Naming**: `docker-*` prefix for external, simple names for internal

### **Testing Philosophy**

- **Always test cross-engine**: Data written by Trino must be readable by Spark
- **Real-world flows first**: CDC pipeline > isolated component tests
- **Cleanup after tests**: Use trap/finally to ensure resource cleanup
- **Wait for health**: Never run tests before services are healthy
- **Retry on timing**: Some operations need retries (Prometheus startup)
- **Log everything**: Comprehensive logging for debugging failures

---

**Remember**: ShuDL is a **comprehensive data lakehouse solution** designed to replace legacy data infrastructure with modern, scalable architecture. This is a living document that evolves with the platform.

**Core Mission**:

1. **ACID Transactions**: Full transactional support for data warehouse workloads
2. **Schema Evolution**: Flexible schema management without downtime
3. **Unified Processing**: Batch and streaming in a single platform
4. **Security & Governance**: Enterprise-grade access control and audit logging
5. **Scalability**: From development to petabyte-scale production

**For AI Agents**: Focus on understanding the **CDC pipeline flow** (PostgreSQL → Debezium → Kafka → Flink → Iceberg → Trino → ClickHouse), **Iceberg+Nessie+S3 integration** (ACID transactions with Git-like versioning), and **cross-engine data access patterns** (Trino ↔ Spark interoperability) - these are the core architectural patterns that drive all data operations in ShuDL.

**Development Priorities**:

- **Data Quality**: ACID guarantees, schema validation, automated testing
- **Performance**: < 1s queries, > 10K events/sec CDC, 50-80% compression
- **Reliability**: 99.9% uptime, automated failover, comprehensive monitoring
- **Security**: Encryption at rest and in transit, fine-grained access control
- **Documentation**: Complete guides for all features and use cases
