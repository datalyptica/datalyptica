#!/bin/bash

# Script to set up Loki log aggregation for ShuDL with Grafana Alloy
# Grafana Alloy is the successor to Promtail and offers better performance
# and more features for log collection and processing.

set -e

echo "📊 Setting up Loki Log Aggregation with Grafana Alloy"
echo ""

# Create Loki config directory
mkdir -p configs/monitoring/loki

echo "✅ Creating Loki configuration..."

# Create Loki configuration
cat > configs/monitoring/loki/loki-config.yml << 'EOF'
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

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  retention_period: 336h  # 14 days
  max_query_lookback: 720h  # 30 days
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  per_stream_rate_limit: 4MB
  per_stream_rate_limit_burst: 8MB
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 336h

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
EOF

echo "✅ Loki configuration created at: configs/monitoring/loki/loki-config.yml"
echo ""

# Note about Alloy configuration
echo "📝 Grafana Alloy Configuration"
echo ""
echo "Alloy configuration is already provided at:"
echo "  configs/monitoring/loki/alloy-config.alloy"
echo ""
echo "This configuration includes:"
echo "  • Docker container log collection via Docker API"
echo "  • Automatic service discovery and labeling"
echo "  • JSON log parsing with level extraction"
echo "  • PostgreSQL and ShuDL application log file collection"
echo "  • Metrics export to Prometheus for Alloy monitoring"
echo "  • Advanced log processing pipelines"
echo ""

echo "✅ Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Deploy Loki and Alloy:"
echo "   cd docker"
echo "   docker compose up -d loki alloy"
echo ""
echo "2. Verify Loki is running:"
echo "   curl http://localhost:3100/ready"
echo ""
echo "3. Check Alloy status:"
echo "   curl http://localhost:12345/-/ready"
echo "   open http://localhost:12345  # Alloy UI"
echo ""
echo "4. View Alloy configuration in UI:"
echo "   open http://localhost:12345/graph"
echo ""
echo "5. Access logs in Grafana:"
echo "   • Navigate to Grafana (http://localhost:3000)"
echo "   • Go to Explore"
echo "   • Select 'Loki' datasource"
echo "   • Try queries like:"
echo "     - {container=\"docker-postgresql\"}"
echo "     - {project=\"shudl\"} |= \"error\""
echo "     - {service=\"trino\"} | json"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Useful LogQL Queries:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "# All logs from a specific container"
echo '{container="docker-postgresql"}'
echo ""
echo "# Error logs across all services"
echo '{project="shudl"} |= "error"'
echo ""
echo "# JSON parsing with filtering"
echo '{service="nessie"} | json | level="ERROR"'
echo ""
echo "# Rate of log entries"
echo 'rate({project="shudl"}[5m])'
echo ""
echo "# Pattern matching"
echo '{container=~"docker-spark.*"} |~ "Exception.*"'
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Why Grafana Alloy?"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Alloy is the successor to Promtail and offers:"
echo "  ✓ Better performance and lower resource usage"
echo "  ✓ Built-in web UI for configuration visualization"
echo "  ✓ Native Prometheus integration for metrics"
echo "  ✓ Advanced processing pipelines"
echo "  ✓ Dynamic configuration reloading"
echo "  ✓ Better error handling and debugging"
echo ""
echo "For more information:"
echo "  https://grafana.com/docs/alloy/latest/"
echo ""
