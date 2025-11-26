# ShuDL Platform Monitoring & Observability

## Table of Contents

- [Overview](#overview)
- [Monitoring Stack](#monitoring-stack)
- [Prometheus Configuration](#prometheus-configuration)
- [Grafana Dashboards](#grafana-dashboards)
- [Metrics Reference](#metrics-reference)
- [Alerting](#alerting)
- [Logging](#logging)
- [Performance Monitoring](#performance-monitoring)
- [Best Practices](#best-practices)

---

## Overview

ShuDL includes a comprehensive monitoring solution using **Prometheus** for metrics collection and **Grafana** for visualization. This document covers setup, usage, and best practices for monitoring your data lakehouse platform.

### Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Grafana (Port 3000)                     │
│                  Dashboards & Visualization                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Query Metrics
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   Prometheus (Port 9090)                    │
│                  Metrics Storage & Queries                  │
└───┬─────────┬──────────┬──────────┬─────────┬─────────────┘
    │         │          │          │         │
    │ Scrape  │ Scrape   │ Scrape   │ Scrape  │ Scrape
    │         │          │          │         │
┌───▼───┐ ┌──▼────┐ ┌───▼────┐ ┌───▼───┐ ┌──▼────┐
│ MinIO │ │Nessie │ │ Trino  │ │ Spark │ │ Kafka │
│       │ │       │ │        │ │       │ │       │
└───────┘ └───────┘ └────────┘ └───────┘ └───────┘
```

### Key Features

- **Real-time Metrics**: 15-second scrape intervals for all services
- **Service Health Monitoring**: Automatic health check tracking
- **Resource Monitoring**: CPU, memory, disk, and network metrics
- **Custom Dashboards**: Pre-configured Grafana dashboards
- **Alert Rules**: Configurable alerts for critical conditions
- **Historical Data**: 15-day metric retention (configurable)

---

## Monitoring Stack

### Accessing Monitoring Services

| Service        | URL                   | Default Credentials                   |
| -------------- | --------------------- | ------------------------------------- |
| **Prometheus** | http://localhost:9090 | None                                  |
| **Grafana**    | http://localhost:3000 | admin / admin (change on first login) |

### Quick Start

```bash
cd /path/to/shudl/docker

# Start monitoring stack (if not already running)
docker compose up -d

# Access Prometheus
open http://localhost:9090

# Access Grafana
open http://localhost:3000
```

---

## Prometheus Configuration

### Configuration File

Location: `configs/monitoring/prometheus/prometheus.yml`

**Current Scrape Jobs:**

1. **prometheus** - Prometheus self-monitoring
2. **minio** - Object storage metrics
3. **nessie** - Catalog service metrics
4. **trino** - Query engine metrics
5. **spark-master** - Spark master metrics
6. **spark-worker** - Spark worker metrics

### Viewing Prometheus Targets

1. Navigate to http://localhost:9090
2. Click **Status → Targets**
3. Check all targets show "UP" status

**Expected Targets:**

```
prometheus (1/1 up)
minio (1/1 up)
nessie (1/1 up)
trino (1/1 up)
spark-master (1/1 up)
spark-worker (1/1 up)
```

### Querying Prometheus

**Prometheus UI: http://localhost:9090/graph**

Common queries:

```promql
# CPU usage per container
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes / 1024 / 1024 / 1024

# Disk usage
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100

# Trino query rate
rate(trino_execution_QueryManager_StartedQueries_TotalCount[5m])

# Spark active jobs
spark_driver_LiveListenerBus_numEventsPosted

# Kafka messages per second
rate(kafka_server_BrokerTopicMetrics_MessagesInPerSec[1m])
```

### Configuration Examples

#### Add New Scrape Target

Edit `configs/monitoring/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  # Add custom application
  - job_name: "my-app"
    static_configs:
      - targets: ["my-app:8080"]
    metrics_path: "/metrics"
    scrape_interval: 30s
```

Then reload Prometheus:

```bash
docker compose restart prometheus
```

#### Adjust Scrape Intervals

```yaml
global:
  scrape_interval: 15s # Default scrape frequency
  evaluation_interval: 15s # How often to evaluate rules
```

---

## Grafana Dashboards

### Accessing Grafana

1. Navigate to http://localhost:3000
2. Login with: **admin** / **admin**
3. Change password on first login

### Pre-configured Dashboards

#### ShuDL Overview Dashboard

**Location:** `configs/monitoring/grafana/dashboards/shudl-overview.json`

**Includes:**

- Service health status
- Resource usage (CPU, Memory, Disk)
- Query performance metrics
- Data ingestion rates
- Network traffic

**To Access:**

1. Go to Grafana → Dashboards
2. Select "ShuDL Overview"

### Creating Custom Dashboards

#### Example: MinIO Dashboard

1. **Click "+" → "Dashboard"**
2. **Add Panel**
3. **Select Data Source: Prometheus**
4. **Add Queries:**

**MinIO Bandwidth Usage:**

```promql
rate(minio_s3_traffic_sent_bytes[5m])
```

**MinIO Request Rate:**

```promql
rate(minio_s3_requests_total[5m])
```

**MinIO Error Rate:**

```promql
rate(minio_s3_requests_errors_total[5m])
```

#### Example: Trino Query Dashboard

**Active Queries:**

```promql
trino_execution_QueryManager_RunningQueries
```

**Query Success Rate:**

```promql
rate(trino_execution_QueryManager_CompletedQueries_TotalCount[5m])
/
rate(trino_execution_QueryManager_StartedQueries_TotalCount[5m])
```

**Query Duration (P95):**

```promql
histogram_quantile(0.95,
  rate(trino_execution_QueryExecution_ExecutionTime_bucket[5m])
)
```

### Dashboard Best Practices

1. **Use Templating** - Add variables for dynamic filtering:

   ```
   Variable: $service
   Query: label_values(up, job)
   ```

2. **Set Time Ranges** - Use appropriate time windows:

   - Real-time: Last 5 minutes
   - Operational: Last 1 hour
   - Analytical: Last 24 hours

3. **Use Annotations** - Mark deployments and incidents

4. **Set Refresh Rate** - Auto-refresh for live monitoring (e.g., 30s)

---

## Metrics Reference

### System Metrics

#### Container Resources

```promql
# CPU usage percentage
100 * rate(container_cpu_usage_seconds_total[5m])

# Memory usage (GB)
container_memory_usage_bytes / 1024 / 1024 / 1024

# Memory usage percentage
100 * (container_memory_usage_bytes / container_spec_memory_limit_bytes)

# Network I/O
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])

# Disk I/O
rate(container_fs_reads_bytes_total[5m])
rate(container_fs_writes_bytes_total[5m])
```

### Service-Specific Metrics

#### PostgreSQL

```promql
# Active connections
pg_stat_activity_count

# Transaction rate
rate(pg_stat_database_xact_commit[5m])

# Buffer cache hit ratio
pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)

# Database size
pg_database_size_bytes
```

#### MinIO

```promql
# Total objects
minio_bucket_objects_count

# Bucket size (bytes)
minio_bucket_usage_total_bytes

# Request rate
rate(minio_s3_requests_total[5m])

# Upload throughput
rate(minio_s3_traffic_received_bytes[5m])

# Download throughput
rate(minio_s3_traffic_sent_bytes[5m])
```

#### Nessie

```promql
# Catalog operations
rate(nessie_operations_total[5m])

# Commit rate
rate(nessie_commits_total[5m])

# Reference operations
rate(nessie_reference_operations_total[5m])
```

#### Trino

```promql
# Running queries
trino_execution_QueryManager_RunningQueries

# Queued queries
trino_execution_QueryManager_QueuedQueries

# Query completion rate
rate(trino_execution_QueryManager_CompletedQueries_TotalCount[5m])

# Failed queries
rate(trino_execution_QueryManager_FailedQueries_TotalCount[5m])

# Memory usage
trino_memory_ClusterMemoryManager_TotalDistributedBytes

# Data processed
rate(trino_execution_QueryExecution_InputDataSize[5m])
```

#### Spark

```promql
# Active jobs
spark_driver_LiveListenerBus_queue_appStatus_size

# Executor count
spark_driver_executor_count

# Memory used
spark_driver_appStatus_app_1_stages_completedStages

# Task completion rate
rate(spark_driver_appStatus_completedTasks[5m])

# Failed tasks
rate(spark_driver_appStatus_failedTasks[5m])
```

#### Kafka

```promql
# Messages in per second
rate(kafka_server_BrokerTopicMetrics_MessagesInPerSec[1m])

# Bytes in per second
rate(kafka_server_BrokerTopicMetrics_BytesInPerSec[1m])

# Under-replicated partitions
kafka_server_ReplicaManager_UnderReplicatedPartitions

# Active controller count
kafka_controller_KafkaController_ActiveControllerCount

# Request rate
rate(kafka_network_RequestMetrics_RequestsPerSec[1m])
```

---

## Alerting

### Alert Rules

Create alert rules in `configs/monitoring/prometheus/alerts.yml`:

```yaml
groups:
  - name: shudl_critical
    interval: 30s
    rules:
      # Service down alert
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} has been down for more than 2 minutes"

      # High memory usage
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.container }}"
          description: "Container {{ $labels.container }} is using {{ $value }}% memory"

      # High CPU usage
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.container }}"
          description: "Container {{ $labels.container }} CPU usage is {{ $value }}"

      # Disk space low
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.device }}"
          description: "Only {{ $value }}% disk space remaining"

      # Trino query failures
      - alert: HighQueryFailureRate
        expr: rate(trino_execution_QueryManager_FailedQueries_TotalCount[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High Trino query failure rate"
          description: "Trino failing {{ $value }} queries per second"

      # PostgreSQL connection saturation
      - alert: PostgreSQLConnectionsHigh
        expr: pg_stat_activity_count > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High PostgreSQL connection count"
          description: "PostgreSQL has {{ $value }} active connections"
```

### Configure Alertmanager

Create `configs/monitoring/alertmanager/config.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ["alertname", "cluster"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: "default"

receivers:
  - name: "default"
    email_configs:
      - to: "devops@shugur.com"
        from: "alertmanager@shugur.com"
        smarthost: "smtp.gmail.com:587"
        auth_username: "alertmanager@shugur.com"
        auth_password: "${SMTP_PASSWORD}"

  - name: "slack"
    slack_configs:
      - api_url: "${SLACK_WEBHOOK_URL}"
        channel: "#shudl-alerts"
        title: "ShuDL Alert"
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'

inhibit_rules:
  - source_match:
      severity: "critical"
    target_match:
      severity: "warning"
    equal: ["alertname", "cluster"]
```

---

## Logging

### Viewing Logs

#### Real-time Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f nessie

# Multiple services
docker compose logs -f trino spark-master

# With timestamp
docker compose logs -f --timestamps nessie

# Last N lines
docker compose logs --tail=100 trino
```

#### Filtering Logs

```bash
# Errors only
docker compose logs | grep -i error

# Specific time range (requires jq)
docker compose logs --since 2025-11-26T10:00:00 --until 2025-11-26T11:00:00

# By log level
docker logs docker-trino 2>&1 | grep "WARN\|ERROR"
```

### Log Aggregation

For production, consider centralized logging with:

#### Option 1: Loki + Promtail (Recommended)

Add to `docker-compose.yml`:

```yaml
services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - shunetwork

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log
      - ./configs/promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - shunetwork
```

Configure Loki as Grafana data source and query logs with LogQL.

#### Option 2: ELK Stack

Use Elasticsearch, Logstash, and Kibana for advanced log analysis.

### Log Rotation

Configure Docker log rotation in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

---

## Performance Monitoring

### Query Performance

#### Trino Query Analysis

1. **Access Trino UI**: http://localhost:8080
2. **Navigate to "Queries"**
3. **Click on query to see:**
   - Query plan
   - Stage execution
   - Data distribution
   - Resource usage

**Identify Slow Queries:**

```promql
topk(10,
  trino_execution_QueryExecution_ExecutionTime
)
```

#### Spark Job Analysis

1. **Access Spark UI**: http://localhost:4040
2. **Navigate to "Jobs"**
3. **Review:**
   - Stage timing
   - Task distribution
   - Data shuffle
   - Executor metrics

### Resource Bottlenecks

#### CPU Bottlenecks

```promql
# Containers using > 80% CPU
(rate(container_cpu_usage_seconds_total[5m]) > 0.8) * 100
```

**Resolution:**

- Scale out workers
- Optimize query plans
- Increase CPU limits

#### Memory Bottlenecks

```promql
# Containers using > 90% memory
(container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9) * 100
```

**Resolution:**

- Increase memory limits
- Tune JVM heap sizes
- Reduce concurrent operations

#### I/O Bottlenecks

```promql
# High disk I/O
rate(container_fs_writes_bytes_total[5m]) > 100000000  # > 100 MB/s
```

**Resolution:**

- Use faster storage (SSD)
- Optimize write patterns
- Enable compression

### Network Performance

```promql
# Network throughput
rate(container_network_transmit_bytes_total[5m]) / 1024 / 1024  # MB/s
```

**Monitor for:**

- Network saturation
- Connection errors
- DNS resolution delays

---

## Best Practices

### Monitoring Strategy

1. **Set Baselines** - Understand normal behavior:

   - CPU: 20-40% average
   - Memory: 60-70% average
   - Query duration: P50, P95, P99

2. **Monitor Trends** - Look for patterns:

   - Daily/weekly cycles
   - Growth trends
   - Seasonal variations

3. **Alert Thoughtfully** - Avoid alert fatigue:

   - Use appropriate thresholds
   - Set proper evaluation periods
   - Route alerts by severity

4. **Regular Review** - Weekly monitoring review:
   - Check dashboard for anomalies
   - Review alert history
   - Analyze slow queries

### Capacity Planning

Track these metrics for capacity planning:

```promql
# Storage growth rate
deriv(minio_bucket_usage_total_bytes[7d])

# Query volume trend
increase(trino_execution_QueryManager_StartedQueries_TotalCount[7d])

# Data ingestion rate
rate(kafka_server_BrokerTopicMetrics_BytesInPerSec[1h])
```

### Performance Tuning

Based on monitoring data:

1. **High Memory Usage**:

   - Increase `TRINO_JVM_XMX`
   - Increase `SPARK_EXECUTOR_MEMORY`
   - Add more workers

2. **Slow Queries**:

   - Optimize table partitioning
   - Add indexes/sorting
   - Increase parallelism

3. **High Latency**:
   - Check network connectivity
   - Review service dependencies
   - Scale bottlenecked services

### Security Monitoring

Monitor for security events:

```promql
# Failed authentication attempts
rate(authentication_failures_total[5m])

# Unusual access patterns
rate(minio_s3_requests_4xx_errors_total[5m]) > 10
```

---

## Troubleshooting Monitoring

### Prometheus Not Scraping

**Check Targets:**

```bash
# View Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# Check specific target
curl -v http://docker-nessie:19120/q/metrics
```

**Common Issues:**

- Service not exposing metrics endpoint
- Wrong metrics_path configured
- Network connectivity issues
- Service not healthy

### Grafana Not Showing Data

**Verify Data Source:**

1. Go to Grafana → Configuration → Data Sources
2. Click "Prometheus"
3. Click "Test" - should show "Data source is working"

**Check Query:**

```promql
# Test simple query
up
```

If no data, check Prometheus is collecting metrics.

### Missing Metrics

**Verify service exposes metrics:**

```bash
# Check service metrics endpoint
docker exec docker-trino curl http://localhost:8080/v1/info
docker exec docker-nessie curl http://localhost:19120/q/metrics
```

---

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)

For troubleshooting, see [`troubleshooting.md`](./troubleshooting.md).
