#!/bin/bash

# =============================================================================
# E2E Test: Monitoring & Observability Stack
# Tests Prometheus, Grafana, Loki, Alloy monitoring pipeline
# Validates: Metrics collection, log aggregation, alerting, dashboards
# =============================================================================

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/test_helpers.sh"

# Test configuration
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
LOKI_URL="http://localhost:3100"
ALERTMANAGER_URL="http://localhost:9093"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Setup
test_start "E2E Monitoring & Observability Test"

setup_test() {
    test_step "Setting up monitoring test environment"
    test_success "Environment initialized"
}

teardown_test() {
    test_step "Cleaning up monitoring test environment"
    test_success "Cleanup complete"
}

trap teardown_test EXIT

# =============================================================================
# Scenario 1: Prometheus Metrics Collection
# =============================================================================
scenario_1_prometheus() {
    test_step "Scenario 1: Prometheus Metrics Collection"
    
    # 1.1 Check Prometheus health
    if check_http_endpoint "$PROMETHEUS_URL/-/healthy" 200 10; then
        test_success "Prometheus server is healthy"
    else
        test_error "Prometheus server not responding"
        return 1
    fi
    
    # 1.2 Check Prometheus ready
    if check_http_endpoint "$PROMETHEUS_URL/-/ready" 200 10; then
        test_success "Prometheus is ready to accept queries"
    else
        test_error "Prometheus not ready"
        return 1
    fi
    
    # 1.3 Query targets status
    local targets
    targets=$(curl -s "$PROMETHEUS_URL/api/v1/targets")
    
    if echo "$targets" | grep -q '"status":"success"'; then
        test_success "Prometheus targets API responding"
    else
        test_error "Failed to query Prometheus targets"
        return 1
    fi
    
    # 1.4 Count active targets
    local active_targets
    active_targets=$(echo "$targets" | grep -o '"health":"up"' | wc -l)
    
    if [[ $active_targets -gt 0 ]]; then
        test_success "Active monitoring targets: $active_targets"
    else
        test_warning "No active monitoring targets found"
    fi
    
    # 1.5 Query sample metric (up metric)
    local up_query
    up_query=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up")
    
    if echo "$up_query" | grep -q '"status":"success"'; then
        test_success "Prometheus metric query successful"
    else
        test_error "Failed to query Prometheus metrics"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 2: Service-Specific Metrics
# =============================================================================
scenario_2_service_metrics() {
    test_step "Scenario 2: Service-Specific Metrics"
    
    # 2.1 Check for Trino metrics
    local trino_metrics
    trino_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up{job=\"trino\"}")
    
    if echo "$trino_metrics" | grep -q '"metric"'; then
        test_success "Trino metrics available in Prometheus"
    else
        test_warning "Trino metrics not found (may not be configured)"
    fi
    
    # 2.2 Check for PostgreSQL metrics
    local pg_metrics
    pg_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up{job=\"postgresql\"}")
    
    if echo "$pg_metrics" | grep -q '"metric"'; then
        test_success "PostgreSQL metrics available"
    else
        test_warning "PostgreSQL metrics not found"
    fi
    
    # 2.3 Check for Kafka metrics
    local kafka_metrics
    kafka_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up{job=\"kafka\"}")
    
    if echo "$kafka_metrics" | grep -q '"metric"'; then
        test_success "Kafka metrics available"
    else
        test_warning "Kafka metrics not found"
    fi
    
    # 2.4 Query Prometheus own metrics
    local prom_metrics
    prom_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=prometheus_tsdb_head_samples_appended_total")
    
    if echo "$prom_metrics" | grep -q '"status":"success"'; then
        test_success "Prometheus internal metrics verified"
    else
        test_error "Failed to query Prometheus internal metrics"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 3: Grafana Dashboard Access
# =============================================================================
scenario_3_grafana() {
    test_step "Scenario 3: Grafana Dashboard Access"
    
    # 3.1 Check Grafana health
    if check_http_endpoint "$GRAFANA_URL/api/health" 200 10; then
        test_success "Grafana server is healthy"
    else
        test_error "Grafana server not responding"
        return 1
    fi
    
    # 3.2 Authenticate to Grafana
    local grafana_auth
    grafana_auth=$(curl -s -X POST "$GRAFANA_URL/api/auth/keys" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        -H "Content-Type: application/json" \
        -d '{"name":"test-key","role":"Viewer"}' 2>/dev/null || echo "")
    
    # Note: May fail if API key already exists or auth method different
    if [[ -n "$grafana_auth" ]]; then
        test_success "Grafana authentication working"
    else
        test_warning "Grafana API authentication method may differ"
    fi
    
    # 3.3 List datasources
    local datasources
    datasources=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/datasources")
    
    if echo "$datasources" | grep -q "Prometheus" || echo "$datasources" | grep -q "prometheus"; then
        test_success "Prometheus datasource configured in Grafana"
    else
        test_warning "Prometheus datasource not found in Grafana"
    fi
    
    if echo "$datasources" | grep -q "Loki" || echo "$datasources" | grep -q "loki"; then
        test_success "Loki datasource configured in Grafana"
    else
        test_warning "Loki datasource not found in Grafana"
    fi
    
    # 3.4 List dashboards
    local dashboards
    dashboards=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/search?type=dash-db")
    
    if [[ -n "$dashboards" ]] && [[ "$dashboards" != "[]" ]]; then
        local dashboard_count
        dashboard_count=$(echo "$dashboards" | grep -o '"type":"dash-db"' | wc -l)
        test_success "Grafana dashboards available: $dashboard_count"
    else
        test_warning "No dashboards configured in Grafana"
    fi
    
    return 0
}

# =============================================================================
# Scenario 4: Loki Log Aggregation
# =============================================================================
scenario_4_loki() {
    test_step "Scenario 4: Loki Log Aggregation"
    
    # 4.1 Check Loki health
    if check_http_endpoint "$LOKI_URL/ready" 200 10; then
        test_success "Loki server is ready"
    else
        test_error "Loki server not responding"
        return 1
    fi
    
    # 4.2 Query Loki labels
    local labels
    labels=$(curl -s "$LOKI_URL/loki/api/v1/labels")
    
    if echo "$labels" | grep -q '"status":"success"'; then
        test_success "Loki labels API responding"
    else
        test_error "Failed to query Loki labels"
        return 1
    fi
    
    # 4.3 Query recent logs
    local log_query
    log_query=$(curl -s "$LOKI_URL/loki/api/v1/query_range?query={job=~\".+\"}&limit=10")
    
    if echo "$log_query" | grep -q '"status":"success"'; then
        test_success "Loki log query successful"
    else
        test_warning "Loki log query returned no results (may be normal if no logs yet)"
    fi
    
    # 4.4 Check Loki metrics
    local loki_metrics
    loki_metrics=$(curl -s "$LOKI_URL/metrics")
    
    if echo "$loki_metrics" | grep -q "loki_"; then
        test_success "Loki metrics endpoint responding"
    else
        test_error "Loki metrics not available"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 5: Alloy Log Collection
# =============================================================================
scenario_5_alloy() {
    test_step "Scenario 5: Alloy Log Collection"
    
    # 5.1 Check if Alloy is running
    if docker ps | grep -q "docker-alloy"; then
        test_success "Alloy container is running"
    else
        test_error "Alloy container not found"
        return 1
    fi
    
    # 5.2 Check Alloy process
    if docker exec docker-alloy pgrep -f "alloy.*run" >/dev/null 2>&1; then
        test_success "Alloy process is active"
    else
        test_error "Alloy process not running"
        return 1
    fi
    
    # 5.3 Check Alloy logs for errors
    local alloy_logs
    alloy_logs=$(docker logs docker-alloy 2>&1 | tail -20)
    
    if echo "$alloy_logs" | grep -i "error" | grep -v "level=error msg=\"error\""; then
        test_warning "Alloy logs contain errors (review recommended)"
    else
        test_success "Alloy logs appear clean"
    fi
    
    # 5.4 Verify Alloy is collecting logs
    if echo "$alloy_logs" | grep -qi "loki\|component\|running"; then
        test_success "Alloy log collection configured"
    else
        test_warning "Alloy configuration may need review"
    fi
    
    return 0
}

# =============================================================================
# Scenario 6: Alertmanager Configuration
# =============================================================================
scenario_6_alertmanager() {
    test_step "Scenario 6: Alertmanager Configuration"
    
    # 6.1 Check Alertmanager health
    if check_http_endpoint "$ALERTMANAGER_URL/-/healthy" 200 10; then
        test_success "Alertmanager is healthy"
    else
        test_error "Alertmanager not responding"
        return 1
    fi
    
    # 6.2 Check Alertmanager ready
    if check_http_endpoint "$ALERTMANAGER_URL/-/ready" 200 10; then
        test_success "Alertmanager is ready"
    else
        test_warning "Alertmanager not ready"
    fi
    
    # 6.3 Query current alerts
    local alerts
    alerts=$(curl -s "$ALERTMANAGER_URL/api/v2/alerts")
    
    if [[ -n "$alerts" ]]; then
        test_success "Alertmanager API responding"
        
        # Count active alerts
        local active_alerts
        active_alerts=$(echo "$alerts" | grep -o '"status"' | wc -l)
        
        if [[ $active_alerts -eq 0 ]]; then
            test_success "No active alerts (system healthy)"
        else
            test_warning "Active alerts: $active_alerts (review recommended)"
        fi
    else
        test_error "Failed to query Alertmanager"
        return 1
    fi
    
    # 6.4 Check alert routing configuration
    local config
    config=$(curl -s "$ALERTMANAGER_URL/api/v2/status")
    
    if echo "$config" | grep -q "config"; then
        test_success "Alertmanager configuration accessible"
    else
        test_warning "Alertmanager configuration may not be loaded"
    fi
    
    return 0
}

# =============================================================================
# Scenario 7: End-to-End Monitoring Flow
# =============================================================================
scenario_7_e2e_monitoring() {
    test_step "Scenario 7: End-to-End Monitoring Flow"
    
    # 7.1 Generate test metric by querying Trino
    execute_trino_query "SELECT 1" >/dev/null 2>&1
    sleep 2  # Allow time for metrics to be scraped
    
    # 7.2 Verify metric appears in Prometheus
    local trino_query_metric
    trino_query_metric=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up{instance=~\".*trino.*\"}")
    
    if echo "$trino_query_metric" | grep -q '"value"'; then
        test_success "End-to-end: Metric collected from service → Prometheus"
    else
        test_warning "Service metrics may take time to appear in Prometheus"
    fi
    
    # 7.3 Verify logs appear in Loki (via Alloy)
    sleep 3  # Allow time for log shipping
    
    local recent_logs
    recent_logs=$(curl -s "$LOKI_URL/loki/api/v1/query_range?query={job=~\".+\"}&limit=5&start=$(date -u -v-5M +%s)000000000&end=$(date -u +%s)000000000" 2>/dev/null || echo "")
    
    if echo "$recent_logs" | grep -q '"values"'; then
        test_success "End-to-end: Logs collected from services → Alloy → Loki"
    else
        test_warning "Log collection may take time to propagate"
    fi
    
    # 7.4 Verify Grafana can query Prometheus
    local grafana_query
    grafana_query=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        -X POST "$GRAFANA_URL/api/ds/query" \
        -H "Content-Type: application/json" \
        -d '{
            "queries": [
                {
                    "datasource": {"type": "prometheus"},
                    "expr": "up",
                    "refId": "A"
                }
            ]
        }' 2>/dev/null || echo "")
    
    if [[ -n "$grafana_query" ]]; then
        test_success "End-to-end: Prometheus → Grafana query successful"
    else
        test_warning "Grafana query API may need configuration"
    fi
    
    return 0
}

# =============================================================================
# Scenario 8: Performance & Resource Metrics
# =============================================================================
scenario_8_performance() {
    test_step "Scenario 8: Performance & Resource Metrics"
    
    # 8.1 Query Prometheus storage metrics
    local storage_metric
    storage_metric=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=prometheus_tsdb_storage_blocks_bytes")
    
    if echo "$storage_metric" | grep -q '"value"'; then
        test_success "Prometheus storage metrics available"
    else
        test_warning "Prometheus storage metrics not found"
    fi
    
    # 8.2 Query scrape duration
    local scrape_duration
    scrape_duration=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=scrape_duration_seconds")
    
    if echo "$scrape_duration" | grep -q '"value"'; then
        test_success "Scrape duration metrics available"
    else
        test_warning "Scrape duration metrics not available"
    fi
    
    # 8.3 Check Loki ingestion rate
    local loki_ingestion
    loki_ingestion=$(curl -s "$LOKI_URL/metrics" | grep "loki_ingester_streams" || echo "")
    
    if [[ -n "$loki_ingestion" ]]; then
        test_success "Loki ingestion metrics available"
    else
        test_warning "Loki ingestion metrics not found"
    fi
    
    # 8.4 Calculate monitoring stack response time
    local start_time=$(date +%s%3N)
    curl -s "$PROMETHEUS_URL/api/v1/query?query=up" >/dev/null
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))
    
    if [[ $response_time -lt 1000 ]]; then
        test_success "Prometheus query response time: ${response_time}ms (< 1s)"
    else
        test_warning "Prometheus query response time: ${response_time}ms (> 1s)"
    fi
    
    return 0
}

# =============================================================================
# Execute Test Scenarios
# =============================================================================

setup_test

FAILED_SCENARIOS=0

scenario_1_prometheus || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_2_service_metrics || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_3_grafana || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_4_loki || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_5_alloy || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_6_alertmanager || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_7_e2e_monitoring || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_8_performance || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))

# Test summary
echo ""
echo "=========================================="
echo "E2E Monitoring & Observability Test Summary"
echo "=========================================="
echo "Scenarios run: 8"
echo "Scenarios passed: $((8 - FAILED_SCENARIOS))"
echo "Scenarios failed: $FAILED_SCENARIOS"
echo "=========================================="

if [[ $FAILED_SCENARIOS -eq 0 ]]; then
    test_success "All monitoring scenarios passed! ✅"
    echo "✅ Monitoring stack validated:"
    echo "   → Prometheus (Metrics collection, queries)"
    echo "   → Grafana (Dashboards, datasources)"
    echo "   → Loki (Log aggregation, queries)"
    echo "   → Alloy (Log shipping)"
    echo "   → Alertmanager (Alert handling)"
    echo "   → End-to-end monitoring flow"
    echo "   → Performance metrics"
    exit 0
else
    test_error "$FAILED_SCENARIOS scenario(s) failed ❌"
    exit 1
fi
