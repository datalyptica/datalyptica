# Docker Compose Setup Guide

## Overview

The Datalyptica platform provides two Docker Compose configurations:

1. **`docker-compose.yml`** - Simplified development setup (22 services)
2. **`docker-compose.ha.yml`** - High Availability setup with failover testing (25 services)

## Quick Start (Development)

```bash
# Use the default simplified setup for daily development
cd docker
docker compose up -d

# Check status
docker compose ps

# Stop
docker compose down
```

**Services**: 22 total
**Startup Time**: ~2 minutes
**RAM Usage**: ~8GB
**Use Case**: Local development, integration testing, debugging

## High Availability Setup (Testing/Learning)

```bash
# Use the HA setup for failover testing
cd docker
docker compose -f docker-compose.ha.yml up -d

# Check HA cluster status
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml list

# View HAProxy stats
open http://localhost:8404/stats

# Test failover
docker exec docker-postgresql-patroni-1 patronictl -c /etc/patroni/patroni.yml switchover \
  --leader postgresql-patroni-1 \
  --candidate postgresql-patroni-2 \
  --force

# Stop
docker compose -f docker-compose.ha.yml down
```

**Services**: 25 total (includes etcd, Patroni, HAProxy)
**Startup Time**: ~5 minutes
**RAM Usage**: ~16GB
**Use Case**: Failover testing, HA learning, pre-production validation

## Key Differences

| Feature | Development (docker-compose.yml) | HA (docker-compose.ha.yml) |
|---------|----------------------------------|----------------------------|
| PostgreSQL | Single instance | 2-node Patroni cluster |
| Failover | Manual restart | Automatic (~15 seconds) |
| Load Balancer | None | HAProxy with health checks |
| Consensus | None | 3-node etcd cluster |
| Services | 22 | 25 |
| RAM Usage | ~8GB | ~16GB |
| Startup Time | ~2 min | ~5 min |
| Best For | Daily dev | HA testing |

## Database Connection Differences

### Development Setup (docker-compose.yml)

```yaml
# Direct connection to PostgreSQL
QUARKUS_DATASOURCE_JDBC_URL: jdbc:postgresql://postgresql:5432/nessie
POSTGRES_HOST: postgresql
POSTGRES_PORT: 5432
```

### HA Setup (docker-compose.ha.yml)

```yaml
# Connection via HAProxy load balancer
QUARKUS_DATASOURCE_JDBC_URL: jdbc:postgresql://haproxy:5000/nessie
POSTGRES_HOST: haproxy
POSTGRES_PORT: 5000  # Write endpoint
# Read endpoint available on port 5001
```

## What's Identical (85% of platform)

Both setups share:

- ✅ All container images
- ✅ All service configurations
- ✅ Monitoring stack (Prometheus, Grafana, Loki, Alertmanager)
- ✅ Security (SSL/TLS, Docker Secrets, network segmentation)
- ✅ Data pipeline (Kafka, Flink, Spark, Trino, Nessie, Iceberg)
- ✅ CDC pipeline (Debezium, Schema Registry)
- ✅ OLAP (ClickHouse)
- ✅ Transformation (dbt)
- ✅ Authentication (Keycloak)

## Kubernetes Production

For production Kubernetes deployment, neither Docker Compose setup is used directly.
Instead, K8s provides HA natively through:

- **StatefulSets** for stateful services (PostgreSQL, Kafka, etc.)
- **Operators** for automated management:
  - CloudNativePG or Zalando PostgreSQL Operator (instead of Patroni)
  - Strimzi Kafka Operator (instead of standalone Kafka)
  - MinIO Operator (for distributed object storage)
- **K8s Services** for load balancing (instead of HAProxy)
- **etcd** is built into K8s control plane

**Migration Value**: 85% of configs, images, and knowledge transfers to K8s!

## Switching Between Setups

### From Dev to HA

```bash
cd docker

# Stop dev setup
docker compose down

# Start HA setup
docker compose -f docker-compose.ha.yml up -d
```

### From HA to Dev

```bash
cd docker

# Stop HA setup
docker compose -f docker-compose.ha.yml down

# Start dev setup
docker compose up -d
```

## Troubleshooting

### Development Setup Issues

**Problem**: PostgreSQL connection refused  
**Solution**: Check `docker compose ps` - postgresql should be healthy

**Problem**: Services can't connect to database  
**Solution**: Verify `POSTGRES_HOST=postgresql` in service config

### HA Setup Issues

**Problem**: Patroni cluster won't start  
**Solution**: Check etcd cluster first: `docker compose -f docker-compose.ha.yml logs etcd-1`

**Problem**: HAProxy shows all backends DOWN  
**Solution**: Check Patroni REST API: `curl http://localhost:8008/patroni`

See `../TROUBLESHOOTING.md` and `../docs/POSTGRESQL_HA.md` for detailed guides.

## Recommended Workflow

1. **Daily Development**: Use `docker-compose.yml`
   - Fast startup
   - Lower resource usage
   - Easy debugging

2. **Before PR/Deployment**: Test with `docker-compose.ha.yml`
   - Validate failover scenarios
   - Test under load
   - Verify HA configurations

3. **Production**: Deploy to Kubernetes
   - Use Helm charts
   - Use operators for HA
   - Scale horizontally

## Files Structure

```
docker/
├── docker-compose.yml          # Development (22 services)
├── docker-compose.ha.yml       # HA Testing (25 services)
├── .env.example                # All environment variables
├── .env.patroni                # Patroni-specific vars (HA only)
├── services/                   # Custom Dockerfiles
│   ├── patroni/                # HA PostgreSQL (HA only)
│   └── ...
└── configs/
    ├── haproxy/                # HAProxy config (HA only)
    └── ...
```

## Next Steps

- **For Development**: Start with `docker-compose.yml`
- **For HA Learning**: Explore `docker-compose.ha.yml`
- **For Production**: Migrate to Kubernetes with Helm charts

See `.github/copilot-instructions.md` for comprehensive platform documentation.

