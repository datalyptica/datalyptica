#!/bin/bash
# setup-loki.sh
# Deploy Loki log aggregation stack

set -e

LOKI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/monitoring/loki" && pwd)"

echo "📊 Setting up Loki Log Aggregation"
echo "=================================="
echo ""

# Create Loki configuration directory
mkdir -p "$LOKI_DIR"

# Create Loki configuration
cat > "$LOKI_DIR/loki-config.yml" <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://prometheus:9090

limits_config:
  retention_period: 336h  # 14 days
  max_query_lookback: 720h  # 30 days
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32

chunk_store_config:
  max_look_back_period: 720h  # 30 days

table_manager:
  retention_deletes_enabled: true
  retention_period: 336h  # 14 days
EOF

# Create Promtail configuration
cat > "$LOKI_DIR/promtail-config.yml" <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker container logs
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'service'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_project']
        target_label: 'project'
    pipeline_stages:
      - docker: {}
      - json:
          expressions:
            level: level
            msg: message
      - labels:
          level:
          
  # PostgreSQL logs
  - job_name: postgresql
    static_configs:
      - targets:
          - localhost
        labels:
          job: postgresql
          __path__: /var/log/postgresql/*.log

  # Application logs
  - job_name: shudl
    static_configs:
      - targets:
          - localhost
        labels:
          job: shudl
          __path__: /var/log/shudl/*.log
EOF

echo "✅ Loki configuration files created"
echo ""
echo "📁 Configuration files:"
echo "  Loki: $LOKI_DIR/loki-config.yml"
echo "  Promtail: $LOKI_DIR/promtail-config.yml"
echo ""
echo "📝 Next steps:"
echo "  1. Add Loki and Promtail services to docker-compose.yml"
echo "  2. Start services: docker compose up -d loki promtail"
echo "  3. Add Loki datasource to Grafana"
echo "  4. Create log dashboards in Grafana"
echo "  5. Access Loki: http://localhost:3100/metrics"
echo ""
echo "🔍 Useful queries:"
echo '  {container="docker-postgresql"}'
echo '  {service="trino"} |= "error"'
echo '  {project="shudl"} | json | level="ERROR"'
echo '  rate({job="postgresql"}[5m])'
