#!/usr/bin/env bash

#############################################################################
# ShuDL Quick Use Cases Test - Simplified Version
# Tests core lakehouse functionality without complex CDC setup
#############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

TEST_NAME="quick-use-cases"
LOG_FILE="${SCRIPT_DIR}/../logs/${TEST_NAME}-$(date +%Y%m%d-%H%M%S).log"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $*" | tee -a "$LOG_FILE"
    ((PASSED_TESTS++))
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $*" | tee -a "$LOG_FILE"
    ((FAILED_TESTS++))
}

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $*" | tee -a "$LOG_FILE"
}

run_test() {
    local test_name=$1
    local test_function=$2
    
    ((TOTAL_TESTS++))
    log_info "Running test ${TOTAL_TESTS}: ${test_name}"
    
    if $test_function; then
        log_success "Test ${TOTAL_TESTS}: ${test_name}"
    else
        log_error "Test ${TOTAL_TESTS}: ${test_name}"
    fi
}

#############################################################################
# Core Lakehouse Tests
#############################################################################

test_create_ecommerce_schema() {
    log_info "Creating e-commerce schema in Iceberg"
    execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.ecommerce WITH (location = 's3://lakehouse/ecommerce')" 60 >> "$LOG_FILE" 2>&1
}

test_create_orders_table() {
    log_info "Creating orders table"
    execute_trino_query "
        CREATE TABLE IF NOT EXISTS iceberg.ecommerce.orders (
            order_id BIGINT,
            customer_id BIGINT,
            product_name VARCHAR,
            quantity INTEGER,
            price DOUBLE,
            order_status VARCHAR,
            created_at TIMESTAMP
        )
        WITH (format = 'PARQUET', partitioning = ARRAY['day(created_at)'])
    " 60 >> "$LOG_FILE" 2>&1
}

test_insert_order_data() {
    log_info "Inserting sample order data"
    execute_trino_query "
        INSERT INTO iceberg.ecommerce.orders VALUES
        (1, 101, 'Laptop Pro', 1, 1299.99, 'pending', TIMESTAMP '2024-11-26 10:00:00'),
        (2, 102, 'Wireless Mouse', 2, 29.99, 'pending', TIMESTAMP '2024-11-26 11:00:00'),
        (3, 103, 'USB-C Cable', 3, 15.99, 'confirmed', TIMESTAMP '2024-11-26 12:00:00'),
        (4, 101, 'Monitor 27inch', 1, 399.99, 'pending', TIMESTAMP '2024-11-26 13:00:00')
    " 90 >> "$LOG_FILE" 2>&1
}

test_query_orders() {
    log_info "Querying orders table"
    execute_trino_query "SELECT COUNT(*) FROM iceberg.ecommerce.orders" 30 >> "$LOG_FILE" 2>&1
}

test_create_finance_schema() {
    log_info "Creating finance schema"
    execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.finance WITH (location = 's3://lakehouse/finance')" 60 >> "$LOG_FILE" 2>&1
}

test_create_transactions_table() {
    log_info "Creating transactions table"
    execute_trino_query "
        CREATE TABLE IF NOT EXISTS iceberg.finance.transactions (
            transaction_id BIGINT,
            account_id INTEGER,
            transaction_type VARCHAR,
            amount DOUBLE,
            currency VARCHAR,
            transaction_date DATE,
            description VARCHAR
        )
        WITH (format = 'PARQUET', partitioning = ARRAY['month(transaction_date)'])
    " 60 >> "$LOG_FILE" 2>&1
}

test_insert_financial_data() {
    log_info "Inserting financial transaction data"
    execute_trino_query "
        INSERT INTO iceberg.finance.transactions VALUES
        (1001, 2001, 'DEPOSIT', 5000.00, 'USD', DATE '2024-11-01', 'Salary deposit'),
        (1002, 2001, 'WITHDRAWAL', -150.00, 'USD', DATE '2024-11-05', 'ATM withdrawal'),
        (1003, 2002, 'DEPOSIT', 3500.00, 'USD', DATE '2024-11-10', 'Client payment'),
        (1004, 2003, 'TRANSFER', -2000.00, 'USD', DATE '2024-11-15', 'Transfer to savings'),
        (1005, 2003, 'DEPOSIT', 10000.00, 'USD', DATE '2024-11-20', 'Investment return')
    " 90 >> "$LOG_FILE" 2>&1
}

test_create_daily_summary() {
    log_info "Creating aggregated daily summary"
    execute_trino_query "
        CREATE TABLE IF NOT EXISTS iceberg.finance.daily_summary AS
        SELECT 
            transaction_date,
            COUNT(*) as transaction_count,
            SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_deposits,
            SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_withdrawals,
            SUM(amount) as net_amount
        FROM iceberg.finance.transactions
        GROUP BY transaction_date
    " 90 >> "$LOG_FILE" 2>&1
}

test_query_summary() {
    log_info "Querying daily summary"
    execute_trino_query "SELECT * FROM iceberg.finance.daily_summary ORDER BY transaction_date" 30 >> "$LOG_FILE" 2>&1
}

test_time_travel() {
    log_info "Testing Time Travel feature"
    execute_trino_query "
        SELECT snapshot_id, committed_at 
        FROM iceberg.finance.\"transactions\$snapshots\" 
        ORDER BY committed_at DESC 
        LIMIT 1
    " 30 >> "$LOG_FILE" 2>&1
}

test_create_analytics_schema() {
    log_info "Creating analytics schema"
    execute_trino_query "CREATE SCHEMA IF NOT EXISTS iceberg.analytics WITH (location = 's3://lakehouse/analytics')" 60 >> "$LOG_FILE" 2>&1
}

test_create_business_view() {
    log_info "Creating business view"
    execute_trino_query "
        CREATE OR REPLACE VIEW iceberg.analytics.customer_orders_summary AS
        SELECT 
            customer_id,
            COUNT(*) as total_orders,
            SUM(price * quantity) as total_spent,
            AVG(price * quantity) as avg_order_value
        FROM iceberg.ecommerce.orders
        GROUP BY customer_id
    " 60 >> "$LOG_FILE" 2>&1
}

test_query_business_view() {
    log_info "Querying business metrics"
    execute_trino_query "
        SELECT customer_id, total_orders, total_spent 
        FROM iceberg.analytics.customer_orders_summary 
        ORDER BY total_spent DESC
    " 30 >> "$LOG_FILE" 2>&1
}

test_nessie_branches() {
    log_info "Listing Nessie branches"
    BRANCHES=$(curl -s "http://localhost:19120/api/v2/trees" 2>&1)
    if echo "$BRANCHES" | grep -q "main"; then
        log_info "Nessie catalog accessible"
        return 0
    else
        log_error "Failed to access Nessie"
        return 1
    fi
}

test_prometheus_metrics() {
    log_info "Checking Prometheus metrics"
    METRICS=$(curl -s "http://localhost:9090/api/v1/query?query=up" 2>&1 | grep -c "success" || echo "0")
    if [ "$METRICS" -gt 0 ]; then
        log_info "Prometheus collecting metrics"
        return 0
    else
        log_error "Prometheus not collecting metrics"
        return 1
    fi
}

test_grafana_health() {
    log_info "Checking Grafana"
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>&1)
    if [ "$STATUS" = "200" ]; then
        log_info "Grafana healthy"
        return 0
    else
        log_error "Grafana not healthy"
        return 1
    fi
}

test_service_health() {
    log_info "Checking service health"
    HEALTHY=$(docker ps --filter "health=healthy" 2>&1 | wc -l)
    if [ "$HEALTHY" -gt 15 ]; then
        log_info "Services healthy: $HEALTHY"
        return 0
    else
        log_error "Insufficient healthy services: $HEALTHY"
        return 1
    fi
}

#############################################################################
# Main Test Execution
#############################################################################

main() {
    log "=========================================="
    log "ShuDL Quick Use Cases Test"
    log "=========================================="
    log "Testing core lakehouse functionality"
    log ""
    
    # Use Case 1: E-commerce Analytics
    log "=========================================="
    log "Use Case 1: E-commerce Data Pipeline"
    log "=========================================="
    run_test "Create e-commerce schema" test_create_ecommerce_schema
    run_test "Create orders table" test_create_orders_table
    run_test "Insert order data" test_insert_order_data
    run_test "Query orders" test_query_orders
    
    # Use Case 2: Financial Reporting
    log ""
    log "=========================================="
    log "Use Case 2: Financial Reporting"
    log "=========================================="
    run_test "Create finance schema" test_create_finance_schema
    run_test "Create transactions table" test_create_transactions_table
    run_test "Insert financial data" test_insert_financial_data
    run_test "Create daily summary" test_create_daily_summary
    run_test "Query summary" test_query_summary
    run_test "Time travel query" test_time_travel
    
    # Use Case 3: BI Analytics
    log ""
    log "=========================================="
    log "Use Case 3: Business Intelligence"
    log "=========================================="
    run_test "Create analytics schema" test_create_analytics_schema
    run_test "Create business view" test_create_business_view
    run_test "Query business view" test_query_business_view
    
    # Use Case 4: Data Versioning
    log ""
    log "=========================================="
    log "Use Case 4: Data Versioning"
    log "=========================================="
    run_test "List Nessie branches" test_nessie_branches
    
    # Use Case 5: Monitoring
    log ""
    log "=========================================="
    log "Use Case 5: Platform Monitoring"
    log "=========================================="
    run_test "Prometheus metrics" test_prometheus_metrics
    run_test "Grafana health" test_grafana_health
    run_test "Service health" test_service_health
    
    # Summary
    log ""
    log "=========================================="
    log "Test Summary"
    log "=========================================="
    log "Total tests: $TOTAL_TESTS"
    log "Passed: $PASSED_TESTS"
    log "Failed: $FAILED_TESTS"
    log "Success rate: $(awk "BEGIN {printf \"%.2f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")%"
    log ""
    log "Full log: $LOG_FILE"
    log "=========================================="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed."
        exit 1
    fi
}

main "$@"
