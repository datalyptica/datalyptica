# Datalyptica - Datalyptica Data Lakehouse Platform

**Version:** v1.0.0  
**Status:** Development  
**License:** Proprietary

---

## 🌟 Overview

Datalyptica (Datalyptica Data Lakehouse) is a comprehensive on-premises data lakehouse platform built on **Apache Iceberg** table format with **Project Nessie** catalog. The platform provides ACID transactions, schema evolution, time-travel queries, and git-like data versioning across a complete data engineering stack.

### Key Features

✅ **Lakehouse Architecture** - Best of data lakes and data warehouses  
✅ **ACID Transactions** - Full transactional support via Apache Iceberg  
✅ **Time Travel** - Query data as it existed at any point in time  
✅ **Data Versioning** - Git-like branching and tagging with Nessie  
✅ **Multi-Engine Access** - Query same data with Trino, Spark, ClickHouse  
✅ **Real-time Streaming** - Kafka + Flink for stream processing  
✅ **Complete Observability** - Prometheus, Grafana, Loki, Alertmanager  
✅ **Enterprise Security** - Keycloak IAM, network segmentation

---

## 🏗️ Architecture

### Complete Platform Stack (21 Components)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Consumers & BI Tools                          │
│                   (Power BI, Tableau, etc.)                      │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│              Semantic & Modeling Layer                          │
│         Trino (SQL) │ dbt (Transformations)                     │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│                     OLAP Layer                                   │
│                   ClickHouse (Analytics)                         │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│               Storage Layer (Lakehouse)                          │
│  Apache Iceberg │ Nessie Catalog │ MinIO │ PostgreSQL          │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│          Processing & Transformation Layer                       │
│         Spark (Batch) │ Flink (Stream Processing)               │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│                   Streaming Layer                                │
│  Kafka │ Zookeeper │ Schema Registry │ Kafka Connect (CDC)      │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│                  Integration Layer                               │
│            Airbyte (ELT) │ Debezium (CDC)                       │
└─────────────────────────────────────────────────────────────────┘
                              ▲
┌─────────────────────────────────────────────────────────────────┐
│                     Data Sources                                 │
│         Databases │ APIs │ Files │ Streams                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  Observability Stack                             │
│  Prometheus │ Grafana │ Loki │ Alloy │ Alertmanager │ Keycloak │
└─────────────────────────────────────────────────────────────────┘
```

### Component List

#### Storage Layer (3)

- **MinIO** (9000, 9001) - S3-compatible object storage
- **PostgreSQL** (5432) - Metadata and catalog backend
- **Nessie** (19120) - Data catalog with git-like versioning

#### Streaming Layer (4)

- **Zookeeper** (2181) - Coordination service
- **Kafka** (9092) - Message broker
- **Schema Registry** (8085) - Avro schema management
- **Kafka UI** (8090) - Management console

#### Processing Layer (4)

- **Spark Master** (4040, 7077) - Batch processing coordinator
- **Spark Worker** (4041) - Batch execution engine
- **Flink JobManager** (8081) - Stream processing coordinator
- **Flink TaskManager** - Stream processing executor

#### Query/Analytics Layer (4)

- **Trino** (8080) - Distributed SQL query engine
- **ClickHouse** (8123, 9009) - OLAP database
- **dbt** (8580) - Data transformation tool
- **Kafka Connect** (8083) - CDC and integration

#### Observability Layer (6)

- **Prometheus** (9090) - Metrics collection
- **Grafana** (3000) - Visualization and dashboards
- **Loki** (3100) - Log aggregation
- **Alloy** (12345) - Log collection agent
- **Alertmanager** (9095) - Alert routing
- **Keycloak** (8180) - Identity and access management

---

## 🚀 Quick Start

### Prerequisites

- **Docker** 20.10+ with Docker Compose V2
- **RAM:** 16GB+ allocated to Docker
- **Disk:** 50GB+ free space
- **OS:** macOS, Linux, or Windows with WSL2
- **coreutils:** For macOS: `brew install coreutils`

### Installation

1. **Clone the repository**

```bash
git clone <repository-url>
cd datalyptica
```

2. **Set up environment**

```bash
cd docker
cp .env.template .env
# Edit .env and change default passwords
```

3. **Start all services**

```bash
docker compose up -d
```

4. **Verify deployment**

```bash
# Check all services are running
docker compose ps

# Run health checks
cd ../tests
./run-tests.sh health
```

5. **Access web interfaces**

```bash
# MinIO Console
open http://localhost:9001

# Grafana
open http://localhost:3000  # admin/admin

# Nessie API
open http://localhost:19120/q/swagger-ui

# Kafka UI
open http://localhost:8090
```

### First Steps

```bash
# 1. Create a test table in Iceberg via Trino
docker exec datalyptica-trino trino --execute "
CREATE SCHEMA IF NOT EXISTS iceberg.demo;
CREATE TABLE iceberg.demo.users (
    id BIGINT,
    name VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP
) WITH (format = 'PARQUET');"

# 2. Insert some data
docker exec datalyptica-trino trino --execute "
INSERT INTO iceberg.demo.users VALUES
(1, 'Alice', 'alice@example.com', CURRENT_TIMESTAMP),
(2, 'Bob', 'bob@example.com', CURRENT_TIMESTAMP);"

# 3. Query the data
docker exec datalyptica-trino trino --execute "
SELECT * FROM iceberg.demo.users;"

# 4. Check Nessie versioning
curl http://localhost:19120/api/v2/trees/tree/main | jq
```

---

## 📚 Documentation

### Core Documentation

- **[Deployment Guide](DEPLOYMENT.md)** - Production deployment procedures
- **[Environment Variables](ENVIRONMENT_VARIABLES.md)** - Complete configuration reference
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions
- **[Architecture Guide](.github/copilot-instructions.md)** - Detailed architecture and patterns

### Component-Specific

- **[Docker Images](docker/README.md)** - Building and managing Docker images
- **[Testing Framework](tests/README.md)** - Running and developing tests
- **[Monitoring Configuration](configs/monitoring/)** - Prometheus, Grafana, Loki setup

### Review & Status

- **[Platform Review](COMPREHENSIVE_PLATFORM_REVIEW.md)** - Complete platform assessment
- **[Action Plan](PRIORITIZED_ACTION_PLAN.md)** - Implementation roadmap
- **[Status Checklist](REVIEW_CHECKLIST.md)** - Current progress tracking

---

## 🧪 Testing

### Run All Tests

```bash
cd tests

# Quick health checks only (1-2 minutes)
./run-tests.sh quick

# Full test suite (5-10 minutes)
./run-tests.sh full

# Specific test categories
./run-tests.sh health        # Health checks
./run-tests.sh integration   # Integration tests
./run-tests.sh e2e           # End-to-end tests
```

### Individual Component Tests

```bash
# Test MinIO
curl http://localhost:9000/minio/health/live

# Test PostgreSQL
docker exec datalyptica-postgresql pg_isready -U postgres

# Test Nessie
curl http://localhost:19120/api/v2/config

# Test Trino
docker exec datalyptica-trino trino --execute "SHOW CATALOGS"

# Test Kafka
docker exec datalyptica-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

---

## 📊 Monitoring & Observability

### Accessing Monitoring Tools

```bash
# Grafana (Dashboards)
open http://localhost:3000
# Username: admin, Password: admin

# Prometheus (Metrics)
open http://localhost:9090

# Loki (Logs)
open http://localhost:3100

# Alertmanager (Alerts)
open http://localhost:9095
```

### Pre-configured Dashboards

1. **Datalyptica Overview** - Platform-wide metrics and health
2. **Datalyptica Logs** - Centralized log analysis

### Adding Custom Dashboards

```bash
# Add dashboard JSON to:
configs/monitoring/grafana/dashboards/

# Restart Grafana
docker compose restart grafana
```

---

## 💻 System Requirements

### Minimum Specifications

- **CPU:** 4 cores (8+ cores recommended)
- **RAM:** 8GB (16GB+ recommended for full platform)
- **Disk:** 50GB free space (SSD recommended)
- **Docker:** 20.10+ with Compose V2
- **OS:** Linux, macOS 10.15+, Windows 10+ with WSL2

### Docker Resource Allocation

**Docker Desktop Settings:**

```yaml
Resources:
  CPUs: 8 cores minimum
  Memory: 16GB minimum
  Swap: 2GB minimum
  Disk image size: 100GB recommended
```

**Note:** Kafka (KRaft mode) and Spark require significant resources during initialization. Insufficient resources may cause restart loops or slow startup times.

### Resource Monitoring

```bash
# Monitor real-time resource usage
docker stats

# Check platform resource consumption
make stats

# View service health
make health
```

---

## 🔧 Configuration

### Environment Variables

All services are configured via environment variables in `docker/.env`. Key variables:

```bash
# Storage Credentials
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=<change-me>
POSTGRES_PASSWORD=<change-me>

# S3 Configuration
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=${MINIO_ROOT_USER}
S3_SECRET_KEY=${MINIO_ROOT_PASSWORD}

# Nessie Configuration
NESSIE_URI=http://nessie:19120/api/v2
WAREHOUSE_LOCATION=s3://lakehouse/warehouse

# Trino Configuration
TRINO_QUERY_MAX_MEMORY=4GB
```

See **[ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md)** for complete reference.

### Resource Tuning

Edit resource limits in `docker/docker-compose.yml`:

```yaml
services:
  trino:
    deploy:
      resources:
        limits:
          cpus: "4.0"
          memory: 8G
```

---

## 🔒 Security

⚠️ **IMPORTANT:** Default configuration is for **development only**

### Production Security Checklist

- [ ] Change all default passwords in `.env`
- [ ] Enable SSL/TLS for all services
- [ ] Migrate secrets to Docker secrets
- [ ] Configure Keycloak for authentication
- [ ] Enable Trino authentication
- [ ] Enable Nessie authentication
- [ ] Configure network firewalls
- [ ] Set up regular security scans
- [ ] Enable audit logging

See **Production Deployment** section for details.

---

## 🚢 Production Deployment

### Prerequisites

1. **Complete Phase 1** (Critical Fixes) - See [PRIORITIZED_ACTION_PLAN.md](PRIORITIZED_ACTION_PLAN.md)

   - ✅ Environment configuration
   - ✅ Documentation restored
   - ✅ Tests passing

2. **Complete Phase 2** (Security & HA)

   - ✅ SSL/TLS enabled
   - ✅ Docker secrets configured
   - ✅ Authentication enabled
   - ✅ High availability configured

3. **Complete Phase 3** (Production Ready)
   - ✅ Monitoring enhanced
   - ✅ Backup/recovery implemented
   - ✅ Performance optimized

### Production Readiness

**Current Status:** 41% Ready (Development Only)  
**Target:** 95%+ Ready  
**Timeline:** 8-12 weeks

See **[COMPREHENSIVE_PLATFORM_REVIEW.md](COMPREHENSIVE_PLATFORM_REVIEW.md)** for detailed assessment.

---

## 🛠️ Common Operations

### Starting/Stopping Services

```bash
cd docker

# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart trino

# View logs
docker compose logs -f trino

# Check status
docker compose ps
```

### Scaling Services

```bash
# Scale Spark workers
docker compose up -d --scale spark-worker=3

# Scale Flink TaskManagers
docker compose up -d --scale flink-taskmanager=3
```

### Backup and Recovery

```bash
# Backup PostgreSQL
docker exec datalyptica-postgresql pg_dump -U postgres > backup.sql

# Backup MinIO buckets
docker exec datalyptica-minio mc mirror local/lakehouse /backup/lakehouse

# Restore PostgreSQL
docker exec -i datalyptica-postgresql psql -U postgres < backup.sql
```

---

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check Docker resources
docker system df

# Verify environment file
cat docker/.env | grep -v "^#" | grep -v "^$"

# Check service logs
docker compose logs <service-name>

# Restart from clean state
docker compose down -v
docker compose up -d
```

### Connection Issues

```bash
# Test network connectivity
docker network inspect datalyptica_data

# Test service health
docker compose ps

# Check port conflicts
netstat -an | grep LISTEN | grep <port>
```

See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for complete guide.

---

## 🤝 Contributing

### Development Setup

```bash
# Install development tools
brew install coreutils jq yq

# Build custom images locally
cd scripts/build
./build-all-images.sh

# Run tests
cd tests
./run-tests.sh full
```

### Code Style

- **Go:** Follow standard Go conventions
- **Shell:** Use shellcheck for validation
- **YAML:** 2-space indentation
- **Documentation:** Markdown with proper formatting

---

## 📝 Release Notes

### v1.0.0 (Current)

**Features:**

- ✅ Complete 21-component data lakehouse platform
- ✅ Apache Iceberg + Nessie integration
- ✅ Dual query engines (Trino + Spark)
- ✅ Real-time streaming (Kafka + Flink)
- ✅ OLAP analytics (ClickHouse)
- ✅ Complete observability stack
- ✅ Comprehensive test suite

**Known Issues:**

- SSL/TLS not enabled by default
- High availability requires manual configuration
- Documentation partially restored

**Next Release:** v1.1.0 (Q1 2026)

- SSL/TLS enabled by default
- High availability for critical services
- Enhanced monitoring dashboards
- Performance optimizations

---

## 📞 Support

### Getting Help

1. **Check Documentation** - Start with relevant docs above
2. **Search Issues** - GitHub Issues for known problems
3. **Run Diagnostics** - Use test suite to identify issues
4. **Review Logs** - Check service logs for errors

### Contact

- **Technical Support:** support@datalyptica.com
- **GitHub Issues:** [Project Issues](https://github.com/datalyptica/datalyptica/issues)
- **Documentation:** This repository

---

## 📜 License

Proprietary - All Rights Reserved  
Copyright © 2025 Datalyptica

---

## 🙏 Acknowledgments

Built with:

- **Apache Iceberg** - Open table format
- **Project Nessie** - Data catalog
- **Apache Kafka** - Stream processing
- **Apache Spark** - Batch processing
- **Trino** - SQL query engine
- **ClickHouse** - OLAP database
- **MinIO** - Object storage
- **Prometheus** - Monitoring
- **Grafana** - Visualization

---

**Made with ❤️ by the Datalyptica Team**
