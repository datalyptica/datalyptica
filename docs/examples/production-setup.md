# Production Setup Example

This guide shows how to deploy ShuDL for production use with security, performance, and reliability best practices.

## 🏭 Production Deployment Overview

**Recommended for**: Production workloads, multi-user environments, high availability requirements

### Key Differences from Development
- ✅ **Secure passwords and credentials**
- ✅ **TLS/SSL encryption for external endpoints**
- ✅ **Resource allocation for production workloads**
- ✅ **High availability configuration**
- ✅ **Monitoring and alerting**
- ✅ **Regular backup strategies**

## 🔧 Step 1: Environment Configuration

### Production Environment Setup
```bash
cd docker

# Use production template
cp .env.prod .env

# ⚠️ CRITICAL: Update all passwords and secrets
nano .env
```

### Key Production Settings
```bash
# Database - Use strong passwords
POSTGRES_PASSWORD=your_secure_db_password_here
POSTGRES_USER=nessie
POSTGRES_DB=shudl

# Object Storage - Use strong credentials
MINIO_ROOT_USER=admin
S3_SECRET_KEY=your_secure_s3_key_here
S3_ACCESS_KEY=your_secure_access_key

# Performance Settings
TRINO_QUERY_MAX_MEMORY=8GB
TRINO_MEMORY_HEAP_HEADROOM_PER_NODE=2GB
SPARK_DRIVER_MEMORY=4g
SPARK_EXECUTOR_MEMORY=4g
SPARK_EXECUTOR_CORES=4

# Security
COMPOSE_PROJECT_NAME=shudl-prod
```

## 🚀 Step 2: Deploy Services

### Option A: Docker Compose (Recommended for single-node)
```bash
# Deploy with production configuration
docker compose -f docker-compose.yml up -d

# Verify all services are healthy
docker compose ps
docker compose logs
```

### Option B: Kubernetes (Recommended for multi-node)
```bash
# Create production values file
cat > production-values.yaml << EOF
global:
  environment: production
  
postgresql:
  auth:
    password: "your_secure_db_password"
  persistence:
    size: 100Gi
    storageClass: "fast-ssd"

minio:
  auth:
    rootUser: "admin"
    rootPassword: "your_secure_s3_password"
  persistence:
    size: 500Gi
    storageClass: "fast-ssd"
  
trino:
  coordinator:
    resources:
      limits:
        memory: 8Gi
        cpu: 4
    replicas: 1
  worker:
    resources:
      limits:
        memory: 8Gi
        cpu: 4
    replicas: 3

spark:
  master:
    resources:
      limits:
        memory: 4Gi
        cpu: 2
  worker:
    resources:
      limits:
        memory: 8Gi
        cpu: 4
    replicas: 3
EOF

# Deploy to Kubernetes
helm install shudl-prod charts/lakehouse/ -f production-values.yaml
```

## 🔒 Step 3: Security Configuration

### TLS/SSL Setup
```bash
# Generate SSL certificates (or use existing ones)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=your-domain.com"

# Configure reverse proxy (nginx example)
cat > nginx.conf << EOF
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /etc/ssl/certs/tls.crt;
    ssl_certificate_key /etc/ssl/private/tls.key;
    
    # MinIO Console
    location /minio/ {
        proxy_pass http://localhost:9001/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Trino
    location /trino/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Spark UI
    location /spark/ {
        proxy_pass http://localhost:4040/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
```

### Firewall Configuration
```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 80/tcp    # HTTP (redirect to HTTPS)

# Block direct access to service ports
sudo ufw deny 9000/tcp   # MinIO API
sudo ufw deny 9001/tcp   # MinIO Console
sudo ufw deny 8080/tcp   # Trino
sudo ufw deny 4040/tcp   # Spark
sudo ufw deny 5432/tcp   # PostgreSQL
sudo ufw deny 19120/tcp  # Nessie

sudo ufw enable
```

## 📊 Step 4: Monitoring Setup

### Health Check Script
```bash
#!/bin/bash
# health-check.sh

echo "=== ShuDL Production Health Check ==="

# Check service health
services=("minio:9000/minio/health/live" "nessie:19120/api/v2/config" "trino:8080/v1/info")

for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    endpoint="http://localhost:$(echo $service | cut -d: -f2-)"
    
    if curl -f -s $endpoint > /dev/null; then
        echo "✅ $name is healthy"
    else
        echo "❌ $name is unhealthy"
        exit 1
    fi
done

# Check disk space
df -h | grep -E "(minio_data|postgresql_data)" || echo "⚠️ Volume check needed"

# Check memory usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10

echo "=== Health Check Complete ==="
```

### Monitoring with Prometheus (Optional)
```yaml
# prometheus.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

## 💾 Step 5: Backup Strategy

### Automated Backup Script
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/shudl/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

echo "Starting ShuDL backup to $BACKUP_DIR"

# Backup PostgreSQL
docker exec shudl-postgresql pg_dump -U nessie nessie | gzip > $BACKUP_DIR/nessie-db.sql.gz

# Backup MinIO data
docker run --rm -v minio_data:/data -v $BACKUP_DIR:/backup alpine \
  tar czf /backup/minio-data.tar.gz /data

# Backup configuration
cp docker/.env $BACKUP_DIR/
cp docker/docker-compose.yml $BACKUP_DIR/

# Cleanup old backups (keep last 7 days)
find /backups/shudl -type d -mtime +7 -exec rm -rf {} +

echo "Backup completed: $BACKUP_DIR"
```

### Schedule Backups
```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /path/to/backup.sh >> /var/log/shudl-backup.log 2>&1
```

## 🔍 Step 6: Performance Tuning

### Resource Allocation
```bash
# Monitor resource usage
docker stats --no-stream

# Adjust memory settings in .env based on usage
TRINO_QUERY_MAX_MEMORY=12GB          # Increase for large queries
SPARK_DRIVER_MEMORY=6g               # Increase for complex jobs
SPARK_EXECUTOR_MEMORY=6g             # Increase for data processing

# PostgreSQL tuning
POSTGRES_SHARED_BUFFERS=2GB          # 25% of available RAM
POSTGRES_EFFECTIVE_CACHE_SIZE=6GB     # 75% of available RAM
POSTGRES_MAX_CONNECTIONS=200         # Adjust based on concurrent users
```

### Storage Optimization
```bash
# Use SSD storage for better performance
# Mount points should use SSD/NVMe drives:
# /var/lib/docker/volumes/minio_data
# /var/lib/docker/volumes/postgresql_data

# Configure log rotation
cat > /etc/logrotate.d/docker-shudl << EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF
```

## 🚨 Step 7: Alerting

### Basic Email Alerts
```bash
#!/bin/bash
# alert.sh

if ! ./health-check.sh; then
    echo "ShuDL services are unhealthy on $(hostname)" | \
    mail -s "ShuDL Alert: Service Health Issue" admin@yourcompany.com
fi
```

### Integration with External Monitoring
```bash
# Send metrics to external monitoring service
curl -X POST "https://your-monitoring-service.com/metrics" \
  -H "Content-Type: application/json" \
  -d '{"service": "shudl", "status": "healthy", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

## ✅ Production Checklist

Before going live, verify:

- [ ] **Security**: All passwords changed, TLS enabled, firewall configured
- [ ] **Performance**: Resource allocation appropriate for workload
- [ ] **Monitoring**: Health checks and alerting configured
- [ ] **Backup**: Automated backup strategy implemented
- [ ] **Documentation**: Runbooks for common operations
- [ ] **Testing**: End-to-end functionality verified
- [ ] **Access Control**: User authentication and authorization configured
- [ ] **Compliance**: Data governance and retention policies implemented

## 🆘 Production Support

### Emergency Contacts
- **Primary**: admin@yourcompany.com
- **Secondary**: devops@yourcompany.com
- **Escalation**: ShuDL GitHub Issues

### Common Production Operations
```bash
# Restart services
docker compose restart

# View service logs
docker compose logs -f [service-name]

# Scale workers
docker compose up -d --scale spark-worker=5

# Update services
docker compose pull && docker compose up -d

# Backup on-demand
./backup.sh
```

## 📚 Related Documentation

- **[Deployment Guide](../deployment/deployment-guide.md)** - All deployment options
- **[Monitoring Guide](../operations/monitoring.md)** - Detailed monitoring setup
- **[Troubleshooting](../operations/troubleshooting.md)** - Common issues and solutions
- **[Security Guide](../operations/configuration.md)** - Security best practices 