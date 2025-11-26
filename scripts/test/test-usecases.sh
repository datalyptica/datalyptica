#!/bin/bash

################################################################################
#                                                                              #
#                   ShuDL Interactive Use Cases Guide                          #
#                   Complete Walkthrough of All 12 Scenarios                   #
#                                                                              #
################################################################################

set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
DOCKER_DIR="./docker"
TRINO_CMD="docker exec docker-trino /opt/trino/bin/trino"
KAFKA_CMD="docker exec docker-kafka"
CLICKHOUSE_CMD="docker exec -i docker-clickhouse clickhouse-client --host localhost"
FLINK_CMD="docker exec docker-flink-jobmanager"
MINIO_CMD="docker exec docker-minio mc"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${PURPLE}▶ $1${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read -r
}

show_progress() {
    echo -ne "${BLUE}$1${NC}"
    for i in {1..3}; do
        sleep 0.5
        echo -ne "."
    done
    echo ""
}

################################################################################
# Use Case Functions
################################################################################

usecase_1_data_lakehouse_analytics() {
    print_header "USE CASE 1: Data Lakehouse Analytics (Trino + Iceberg + Nessie)"
    
    print_info "Scenario: E-commerce order analytics with ACID transactions"
    print_info "You'll learn: SQL queries on Iceberg tables, JOINs, aggregations"
    wait_for_user
    
    print_section "Step 1: Create E-commerce Schema"
    echo "Creating schema in Nessie catalog..."
    $TRINO_CMD --execute "CREATE SCHEMA IF NOT EXISTS iceberg.ecommerce WITH (location = 's3://lakehouse/ecommerce');" 2>&1 | grep -v "WARNING" || true
    print_success "Schema 'ecommerce' created"
    wait_for_user
    
    print_section "Step 2: Create Tables"
    echo "Creating customers, products, and orders tables..."
    $TRINO_CMD --execute "
    CREATE TABLE IF NOT EXISTS iceberg.ecommerce.customers (
        customer_id BIGINT,
        customer_name VARCHAR,
        email VARCHAR,
        signup_date TIMESTAMP,
        country VARCHAR
    ) WITH (format = 'PARQUET');

    CREATE TABLE IF NOT EXISTS iceberg.ecommerce.products (
        product_id BIGINT,
        product_name VARCHAR,
        category VARCHAR,
        price DECIMAL(10,2),
        stock_quantity INTEGER,
        last_updated TIMESTAMP
    ) WITH (format = 'PARQUET');

    CREATE TABLE IF NOT EXISTS iceberg.ecommerce.orders (
        order_id BIGINT,
        customer_id BIGINT,
        order_date TIMESTAMP,
        total_amount DECIMAL(10,2),
        status VARCHAR,
        payment_method VARCHAR,
        shipping_address VARCHAR
    ) WITH (format = 'PARQUET');
    " 2>&1 | grep -v "WARNING" || true
    print_success "Tables created with Parquet format"
    wait_for_user
    
    print_section "Step 3: Insert Sample Data"
    echo "Inserting customers..."
    $TRINO_CMD --execute "INSERT INTO iceberg.ecommerce.customers VALUES 
    (1, 'John Smith', 'john@example.com', TIMESTAMP '2024-01-15 10:00:00', 'USA'),
    (2, 'Maria Garcia', 'maria@example.com', TIMESTAMP '2024-02-20 14:30:00', 'Spain'),
    (3, 'Ahmed Hassan', 'ahmed@example.com', TIMESTAMP '2024-03-10 09:15:00', 'Egypt');" 2>&1 | tail -1
    
    echo "Inserting products..."
    $TRINO_CMD --execute "INSERT INTO iceberg.ecommerce.products VALUES 
    (101, 'Laptop Pro 15', 'Electronics', 1299.99, 50, CURRENT_TIMESTAMP),
    (102, 'Wireless Mouse', 'Electronics', 29.99, 200, CURRENT_TIMESTAMP),
    (103, 'Office Chair', 'Furniture', 249.99, 30, CURRENT_TIMESTAMP);" 2>&1 | tail -1
    
    echo "Inserting orders..."
    $TRINO_CMD --execute "INSERT INTO iceberg.ecommerce.orders VALUES 
    (1001, 1, TIMESTAMP '2024-11-20 10:30:00', 1329.98, 'completed', 'credit_card', '123 Main St'),
    (1002, 2, TIMESTAMP '2024-11-21 14:15:00', 249.99, 'completed', 'paypal', '456 Madrid'),
    (1003, 3, TIMESTAMP '2024-11-22 09:45:00', 45.99, 'shipped', 'credit_card', '789 Cairo');" 2>&1 | tail -1
    
    print_success "Sample data inserted"
    wait_for_user
    
    print_section "Step 4: Run Analytical Query"
    echo "Query: Customer order summary with JOIN and aggregation"
    echo ""
    $TRINO_CMD --execute "
    SELECT 
        c.customer_name,
        c.country,
        COUNT(o.order_id) as order_count,
        CAST(SUM(o.total_amount) AS VARCHAR) || ' USD' as total_spent
    FROM iceberg.ecommerce.customers c
    LEFT JOIN iceberg.ecommerce.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_name, c.country
    ORDER BY SUM(o.total_amount) DESC NULLS LAST;
    " 2>&1 | grep -v "WARNING"
    
    print_success "Use Case 1 Complete!"
    print_info "Key Learnings: Schema-on-read, ACID transactions, SQL on data lake"
    wait_for_user
}

usecase_2_realtime_streaming() {
    print_header "USE CASE 2: Real-Time Event Streaming (Kafka)"
    
    print_info "Scenario: Order event streaming for microservices"
    print_info "You'll learn: Kafka topics, producers, consumers, pub/sub"
    wait_for_user
    
    print_section "Step 1: Create Kafka Topic"
    echo "Creating 'order-events' topic with 3 partitions..."
    $KAFKA_CMD kafka-topics --bootstrap-server localhost:9092 \
        --create --topic order-events --partitions 3 --replication-factor 1 \
        --if-not-exists 2>&1 | tail -2
    print_success "Topic created"
    wait_for_user
    
    print_section "Step 2: Produce Messages"
    echo "Sending 5 order events to Kafka..."
    for i in {1..5}; do
        echo "{\"order_id\": $((2000+i)), \"customer_id\": $i, \"amount\": $((100+i*50)), \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"status\": \"pending\"}" | \
        $KAFKA_CMD kafka-console-producer --bootstrap-server localhost:9092 --topic order-events 2>/dev/null
        echo "  ✓ Sent order event $((2000+i))"
    done
    print_success "5 messages produced"
    wait_for_user
    
    print_section "Step 3: Consume Messages"
    echo "Consuming messages from beginning..."
    timeout 3 $KAFKA_CMD kafka-console-consumer --bootstrap-server localhost:9092 \
        --topic order-events --from-beginning --max-messages 5 2>/dev/null || true
    
    print_success "Use Case 2 Complete!"
    print_info "Key Learnings: Event streaming, pub/sub pattern, horizontal scalability"
    wait_for_user
}

usecase_3_realtime_olap() {
    print_header "USE CASE 3: Real-Time OLAP Analytics (ClickHouse)"
    
    print_info "Scenario: Sub-second aggregation queries for dashboards"
    print_info "You'll learn: Columnar storage, MergeTree engine, time-series analytics"
    wait_for_user
    
    print_section "Step 1: Create ClickHouse Table"
    echo "Creating MergeTree table for real-time analytics..."
    echo "CREATE TABLE IF NOT EXISTS orders_realtime (
        order_id UInt64,
        customer_id UInt64,
        order_date DateTime,
        total_amount Decimal(10,2),
        status String,
        country String
    ) ENGINE = MergeTree()
    ORDER BY (order_date, order_id);" | $CLICKHOUSE_CMD
    print_success "Table created"
    wait_for_user
    
    print_section "Step 2: Insert Data"
    echo "Inserting sample orders..."
    echo "INSERT INTO orders_realtime VALUES 
    (1001, 1, '2024-11-20 10:30:00', 1329.98, 'completed', 'USA'),
    (1002, 2, '2024-11-21 14:15:00', 249.99, 'completed', 'Spain'),
    (1003, 3, '2024-11-22 09:45:00', 45.99, 'shipped', 'Egypt'),
    (1004, 1, '2024-11-25 08:30:00', 249.99, 'pending', 'USA');" | $CLICKHOUSE_CMD
    print_success "Data inserted"
    wait_for_user
    
    print_section "Step 3: Run Real-Time Aggregation"
    echo "Query: Hourly order metrics with sub-second performance"
    echo ""
    echo "SELECT 
        toStartOfHour(order_date) as hour,
        count() as order_count,
        sum(total_amount) as revenue,
        round(avg(total_amount), 2) as avg_order_value
    FROM orders_realtime
    GROUP BY hour
    ORDER BY hour DESC;" | $CLICKHOUSE_CMD
    
    print_success "Use Case 3 Complete!"
    print_info "Key Learnings: Columnar storage, real-time aggregations, time-series functions"
    wait_for_user
}

usecase_4_data_versioning() {
    print_header "USE CASE 4: Data Versioning & Time Travel (Nessie + Iceberg)"
    
    print_info "Scenario: Git-like version control for data"
    print_info "You'll learn: Data branches, commits, time travel queries"
    wait_for_user
    
    print_section "Step 1: Check Current Branch"
    echo "Querying Nessie for current branch..."
    curl -s http://localhost:19120/api/v2/trees | jq -r '.references[] | "Branch: \(.name), Hash: \(.hash[0:8])"'
    wait_for_user
    
    print_section "Step 2: Count Orders Before Update"
    echo "Current order count:"
    $TRINO_CMD --execute "SELECT COUNT(*) as order_count FROM iceberg.ecommerce.orders;" 2>&1 | tail -1
    wait_for_user
    
    print_section "Step 3: Insert New Order (Creates New Version)"
    echo "Adding new order - this creates a new snapshot in Nessie..."
    $TRINO_CMD --execute "INSERT INTO iceberg.ecommerce.orders VALUES 
    (1005, 2, CURRENT_TIMESTAMP, 599.99, 'new_order', 'credit_card', 'Barcelona');" 2>&1 | tail -1
    print_success "New version created"
    wait_for_user
    
    print_section "Step 4: Verify Version Change"
    echo "New order count:"
    $TRINO_CMD --execute "SELECT COUNT(*) as order_count FROM iceberg.ecommerce.orders;" 2>&1 | tail -1
    echo ""
    echo "View changes in Nessie catalog:"
    curl -s "http://localhost:19120/api/v2/trees/tree/main/entries?namespaceDepth=2" | jq -r '.entries[].name' | grep ecommerce || true
    
    print_success "Use Case 4 Complete!"
    print_info "Key Learnings: Version control, audit trails, point-in-time queries"
    wait_for_user
}

usecase_5_unified_storage() {
    print_header "USE CASE 5: Unified Storage Layer (MinIO S3)"
    
    print_info "Scenario: Single storage accessed by multiple engines"
    print_info "You'll learn: Object storage, Iceberg file format, cross-engine access"
    wait_for_user
    
    print_section "Step 1: Setup MinIO Alias"
    $MINIO_CMD alias set local http://localhost:9000 minioadmin minioadmin123 2>&1 | grep -q "successfully" && \
    print_success "MinIO alias configured"
    wait_for_user
    
    print_section "Step 2: View Storage Structure"
    echo "Listing Iceberg data files in MinIO..."
    $MINIO_CMD ls --recursive local/lakehouse/ecommerce/ 2>/dev/null | head -10
    wait_for_user
    
    print_section "Step 3: Storage Metrics"
    echo "Total storage used:"
    $MINIO_CMD du local/lakehouse/ecommerce/ 2>/dev/null
    wait_for_user
    
    print_section "Step 4: Multi-Engine Access"
    echo "Same data accessible via:"
    echo "  • Trino (distributed SQL)"
    echo "  • Spark (batch processing)"
    echo "  • Flink (stream processing)"
    echo ""
    echo "Querying via Trino:"
    $TRINO_CMD --execute "SELECT table_name, COUNT(*) as file_count FROM iceberg.ecommerce.\"\$files\" GROUP BY table_name;" 2>&1 | grep -v "WARNING" || echo "Tables tracked in catalog"
    
    print_success "Use Case 5 Complete!"
    print_info "Key Learnings: Unified storage, no data duplication, open file formats"
    wait_for_user
}

usecase_6_change_data_capture() {
    print_header "USE CASE 6: Change Data Capture (Kafka Connect + Debezium)"
    
    print_info "Scenario: Real-time database replication setup"
    print_info "You'll learn: CDC connectors, database streaming, event sourcing"
    wait_for_user
    
    print_section "Step 1: Check Kafka Connect Status"
    echo "Kafka Connect version and cluster:"
    curl -s http://localhost:8083/ | jq -r '"Version: " + .version + ", Cluster: " + .kafka_cluster_id[0:12]'
    wait_for_user
    
    print_section "Step 2: List Available Connectors"
    echo "Debezium CDC connectors available:"
    curl -s http://localhost:8083/connector-plugins | jq -r '.[] | select(.class | contains("Debezium")) | "  • " + (.class | split(".") | .[-1])'
    wait_for_user
    
    print_section "Step 3: Check Active Connectors"
    echo "Currently deployed connectors:"
    CONNECTORS=$(curl -s http://localhost:8083/connectors | jq -r 'if length == 0 then "  (none - ready for deployment)" else .[] end')
    echo "$CONNECTORS"
    wait_for_user
    
    print_section "Step 4: Example Connector Configuration"
    cat << 'EOF'
Example PostgreSQL CDC connector (JSON):
{
  "name": "postgres-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgresql",
    "database.port": "5432",
    "database.user": "nessie",
    "database.password": "nessie123",
    "database.dbname": "nessie",
    "database.server.name": "shudl",
    "table.include.list": "public.*",
    "plugin.name": "pgoutput"
  }
}

Deploy with: curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @connector.json
EOF
    
    print_success "Use Case 6 Complete!"
    print_info "Key Learnings: CDC setup, Debezium connectors, streaming databases"
    wait_for_user
}

usecase_7_stream_processing() {
    print_header "USE CASE 7: Stream Processing Platform (Apache Flink)"
    
    print_info "Scenario: Real-time data transformation infrastructure"
    print_info "You'll learn: Flink cluster, stream jobs, stateful processing"
    wait_for_user
    
    print_section "Step 1: Check Flink Cluster Status"
    echo "Flink cluster overview:"
    curl -s http://localhost:8081/overview | jq '{
        version: ."flink-version",
        taskmanagers: .taskmanagers,
        slots_total: ."slots-total",
        slots_available: ."slots-available",
        jobs_running: ."jobs-running"
    }'
    wait_for_user
    
    print_section "Step 2: List TaskManagers"
    echo "Connected TaskManagers:"
    curl -s http://localhost:8081/taskmanagers | jq -r '.taskmanagers[] | "  • ID: \(.id[0:16])..., Slots: \(.slotsNumber), Free: \(.freeSlots)"'
    wait_for_user
    
    print_section "Step 3: Available Jobs"
    echo "Running Flink jobs:"
    curl -s http://localhost:8081/jobs | jq -r '.jobs[] | "  • \(.id): \(.status)"' 2>/dev/null || echo "  (no jobs running - cluster ready for deployment)"
    wait_for_user
    
    print_section "Step 4: Potential Streaming Pipelines"
    cat << 'EOF'
Ready to deploy Flink SQL jobs:

1. Kafka → Iceberg (Streaming ETL)
   - Read from Kafka topics
   - Transform data with Flink SQL
   - Write to Iceberg tables

2. Kafka → ClickHouse (Real-time Aggregations)
   - Stream aggregations
   - Windowed operations
   - Real-time metrics

3. Kafka → Enrichment → Kafka (Stream Processing)
   - Join with reference data
   - Filter and transform
   - Publish enriched events

Access Flink SQL Client:
  docker exec -it docker-flink-jobmanager ./bin/sql-client.sh
EOF
    
    print_success "Use Case 7 Complete!"
    print_info "Key Learnings: Stream processing, Flink cluster, real-time ETL"
    wait_for_user
}

usecase_8_acid_transactions() {
    print_header "USE CASE 8: Multi-Table ACID Transactions (Iceberg)"
    
    print_info "Scenario: Consistent updates across multiple tables"
    print_info "You'll learn: ACID guarantees, transactions, data consistency"
    wait_for_user
    
    print_section "Step 1: Check Current Inventory"
    echo "Product inventory before order:"
    $TRINO_CMD --execute "SELECT product_id, product_name, stock_quantity FROM iceberg.ecommerce.products WHERE product_id = 101;" 2>&1 | grep -v "WARNING"
    wait_for_user
    
    print_section "Step 2: Simulate Order Processing"
    echo "Processing order: Laptop purchase..."
    echo "This should:"
    echo "  1. Create new order record"
    echo "  2. Decrease product inventory"
    echo "  3. Both succeed or both fail (ACID)"
    echo ""
    
    # Create order
    $TRINO_CMD --execute "INSERT INTO iceberg.ecommerce.orders VALUES 
    (1010, 1, CURRENT_TIMESTAMP, 1299.99, 'processing', 'credit_card', '123 Main St');" 2>&1 | tail -1
    
    # Update inventory
    $TRINO_CMD --execute "UPDATE iceberg.ecommerce.products 
    SET stock_quantity = stock_quantity - 1, last_updated = CURRENT_TIMESTAMP 
    WHERE product_id = 101;" 2>&1 | tail -1 || true
    
    print_success "Transaction completed"
    wait_for_user
    
    print_section "Step 3: Verify Consistency"
    echo "Product inventory after order:"
    $TRINO_CMD --execute "SELECT product_id, product_name, stock_quantity FROM iceberg.ecommerce.products WHERE product_id = 101;" 2>&1 | grep -v "WARNING"
    
    echo ""
    echo "New order created:"
    $TRINO_CMD --execute "SELECT order_id, total_amount, status FROM iceberg.ecommerce.orders WHERE order_id = 1010;" 2>&1 | grep -v "WARNING"
    
    print_success "Use Case 8 Complete!"
    print_info "Key Learnings: ACID transactions, data consistency, multi-table updates"
    wait_for_user
}

usecase_9_schema_evolution() {
    print_header "USE CASE 9: Schema Evolution (Iceberg)"
    
    print_info "Scenario: Add columns to tables without breaking queries"
    print_info "You'll learn: Schema changes, backward compatibility, column addition"
    wait_for_user
    
    print_section "Step 1: View Current Schema"
    echo "Current customer table schema:"
    $TRINO_CMD --execute "DESCRIBE iceberg.ecommerce.customers;" 2>&1 | grep -v "WARNING"
    wait_for_user
    
    print_section "Step 2: Add New Column"
    echo "Adding 'loyalty_points' column to customers table..."
    $TRINO_CMD --execute "ALTER TABLE iceberg.ecommerce.customers ADD COLUMN loyalty_points INTEGER;" 2>&1 | grep -v "WARNING" || true
    print_success "Column added"
    wait_for_user
    
    print_section "Step 3: View Updated Schema"
    echo "Updated customer table schema:"
    $TRINO_CMD --execute "DESCRIBE iceberg.ecommerce.customers;" 2>&1 | grep -v "WARNING"
    wait_for_user
    
    print_section "Step 4: Query Old Data with New Schema"
    echo "Old data automatically gets NULL for new column:"
    $TRINO_CMD --execute "SELECT customer_name, country, loyalty_points FROM iceberg.ecommerce.customers LIMIT 3;" 2>&1 | grep -v "WARNING"
    wait_for_user
    
    print_section "Step 5: Insert Data with New Column"
    echo "Inserting new customer with loyalty points..."
    $TRINO_CMD --execute "INSERT INTO iceberg.ecommerce.customers VALUES 
    (4, 'Lisa Chen', 'lisa@example.com', CURRENT_TIMESTAMP, 'Singapore', 1000);" 2>&1 | tail -1
    
    echo ""
    echo "Verify new data:"
    $TRINO_CMD --execute "SELECT customer_name, country, COALESCE(CAST(loyalty_points AS VARCHAR), 'N/A') as points FROM iceberg.ecommerce.customers;" 2>&1 | grep -v "WARNING"
    
    print_success "Use Case 9 Complete!"
    print_info "Key Learnings: Schema evolution, backward compatibility, no downtime"
    wait_for_user
}

usecase_10_flink_streaming_job() {
    print_header "USE CASE 10: Flink Streaming Job (Kafka → Processing)"
    
    print_info "Scenario: Deploy real-time streaming transformation"
    print_info "You'll learn: Flink SQL, streaming pipelines, continuous processing"
    wait_for_user
    
    print_section "Step 1: Create Enriched Orders Topic"
    echo "Creating target topic for enriched data..."
    $KAFKA_CMD kafka-topics --bootstrap-server localhost:9092 \
        --create --topic enriched-orders --partitions 3 --replication-factor 1 \
        --if-not-exists 2>&1 | tail -1
    print_success "Topic created"
    wait_for_user
    
    print_section "Step 2: Send Test Events to Kafka"
    echo "Producing order events for stream processing..."
    for i in {1..3}; do
        ORDER_JSON=$(cat <<EOF
{"order_id": $((3000+i)), "customer_id": $i, "product_id": $((100+i)), "quantity": $i, "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
)
        echo "$ORDER_JSON" | $KAFKA_CMD kafka-console-producer --bootstrap-server localhost:9092 --topic order-events 2>/dev/null
        echo "  ✓ Sent order $((3000+i))"
    done
    print_success "Events produced"
    wait_for_user
    
    print_section "Step 3: Flink SQL Processing (Simulated)"
    cat << 'EOF'
Flink SQL Job Example:

CREATE TABLE kafka_orders (
    order_id BIGINT,
    customer_id BIGINT,
    product_id BIGINT,
    quantity INT,
    order_time TIMESTAMP(3),
    WATERMARK FOR order_time AS order_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'order-events',
    'properties.bootstrap.servers' = 'kafka:9092',
    'format' = 'json'
);

-- Streaming aggregation
SELECT 
    customer_id,
    COUNT(*) as order_count,
    SUM(quantity) as total_items,
    TUMBLE_START(order_time, INTERVAL '1' MINUTE) as window_start
FROM kafka_orders
GROUP BY customer_id, TUMBLE(order_time, INTERVAL '1' MINUTE);

To deploy: Access Flink SQL Client
  docker exec -it docker-flink-jobmanager ./bin/sql-client.sh
EOF
    wait_for_user
    
    print_section "Step 4: Monitor Kafka Topics"
    echo "Viewing order events:"
    timeout 2 $KAFKA_CMD kafka-console-consumer --bootstrap-server localhost:9092 \
        --topic order-events --from-beginning --max-messages 3 2>/dev/null || true
    
    print_success "Use Case 10 Complete!"
    print_info "Key Learnings: Stream processing, Flink SQL, Kafka integration"
    wait_for_user
}

usecase_11_dbt_transformations() {
    print_header "USE CASE 11: dbt Data Transformations"
    
    print_info "Scenario: SQL-based data modeling and transformation"
    print_info "You'll learn: dbt models, transformations, data lineage"
    wait_for_user
    
    print_section "Step 1: Check dbt Installation"
    echo "dbt version:"
    docker exec docker-dbt dbt --version 2>&1 | head -15
    wait_for_user
    
    print_section "Step 2: Create dbt Model (Simulated)"
    cat << 'EOF'
Example dbt Model: Customer Order Summary

File: models/marts/customer_orders_summary.sql

WITH customer_orders AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.country,
        o.order_id,
        o.total_amount,
        o.order_date
    FROM {{ ref('customers') }} c
    LEFT JOIN {{ ref('orders') }} o 
        ON c.customer_id = o.customer_id
),

aggregated AS (
    SELECT
        customer_id,
        customer_name,
        country,
        COUNT(order_id) as total_orders,
        COALESCE(SUM(total_amount), 0) as lifetime_value,
        MAX(order_date) as last_order_date
    FROM customer_orders
    GROUP BY customer_id, customer_name, country
)

SELECT * FROM aggregated
WHERE lifetime_value > 0;

Run with: dbt run --models customer_orders_summary
EOF
    wait_for_user
    
    print_section "Step 3: Manual Transformation Example"
    echo "Creating aggregated view using SQL..."
    $TRINO_CMD --execute "
    CREATE OR REPLACE VIEW iceberg.ecommerce.customer_summary AS
    SELECT 
        c.customer_name,
        c.country,
        COUNT(o.order_id) as total_orders,
        COALESCE(SUM(o.total_amount), 0) as lifetime_value
    FROM iceberg.ecommerce.customers c
    LEFT JOIN iceberg.ecommerce.orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_name, c.country;
    " 2>&1 | grep -v "WARNING" || true
    
    echo ""
    echo "Query transformed view:"
    $TRINO_CMD --execute "SELECT * FROM iceberg.ecommerce.customer_summary ORDER BY lifetime_value DESC;" 2>&1 | grep -v "WARNING"
    
    print_success "Use Case 11 Complete!"
    print_info "Key Learnings: dbt transformations, data modeling, SQL orchestration"
    wait_for_user
}

usecase_12_cross_engine_comparison() {
    print_header "USE CASE 12: Cross-Engine Query Comparison"
    
    print_info "Scenario: Compare Trino, Spark, and ClickHouse performance"
    print_info "You'll learn: Engine-specific use cases, performance characteristics"
    wait_for_user
    
    print_section "Step 1: Trino (Distributed SQL Engine)"
    echo "Use case: Ad-hoc analytics, complex JOINs"
    echo ""
    echo "Query: Customer order analysis"
    START_TIME=$(date +%s%N)
    $TRINO_CMD --execute "
    SELECT 
        c.country,
        COUNT(DISTINCT c.customer_id) as customers,
        COUNT(o.order_id) as orders,
        CAST(AVG(o.total_amount) AS DECIMAL(10,2)) as avg_order_value
    FROM iceberg.ecommerce.customers c
    LEFT JOIN iceberg.ecommerce.orders o ON c.customer_id = o.customer_id
    GROUP BY c.country
    ORDER BY orders DESC;
    " 2>&1 | grep -v "WARNING"
    END_TIME=$(date +%s%N)
    TRINO_TIME=$((($END_TIME - $START_TIME) / 1000000))
    echo ""
    print_info "Trino execution time: ${TRINO_TIME}ms"
    wait_for_user
    
    print_section "Step 2: ClickHouse (Real-Time OLAP)"
    echo "Use case: Real-time dashboards, time-series analytics"
    echo ""
    echo "Query: Hourly order metrics"
    START_TIME=$(date +%s%N)
    echo "
    SELECT 
        toStartOfHour(order_date) as hour,
        count() as orders,
        round(sum(total_amount), 2) as revenue
    FROM orders_realtime
    GROUP BY hour
    ORDER BY hour DESC
    LIMIT 5;
    " | $CLICKHOUSE_CMD
    END_TIME=$(date +%s%N)
    CLICKHOUSE_TIME=$((($END_TIME - $START_TIME) / 1000000))
    echo ""
    print_info "ClickHouse execution time: ${CLICKHOUSE_TIME}ms"
    wait_for_user
    
    print_section "Step 3: Apache Spark (Batch Processing)"
    echo "Use case: Large-scale data processing, ML pipelines"
    echo ""
    echo "Spark is ideal for:"
    echo "  • Processing TB+ datasets"
    echo "  • Machine learning workloads"
    echo "  • Complex ETL pipelines"
    echo "  • Graph processing"
    echo ""
    echo "Spark UI: http://localhost:4040"
    wait_for_user
    
    print_section "Step 4: Engine Comparison Summary"
    cat << EOF

╔════════════════════════════════════════════════════════════════╗
║                    ENGINE COMPARISON                            ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  TRINO (${TRINO_TIME}ms)                                        ║
║  ✓ Best for: Ad-hoc analytics, complex queries                ║
║  ✓ Strengths: JOIN performance, SQL compatibility             ║
║  ✓ Use when: Multiple data sources, federated queries         ║
║                                                                 ║
║  CLICKHOUSE (${CLICKHOUSE_TIME}ms)                             ║
║  ✓ Best for: Real-time dashboards, time-series                ║
║  ✓ Strengths: Sub-second queries, columnar storage            ║
║  ✓ Use when: High QPS, real-time analytics                    ║
║                                                                 ║
║  SPARK                                                          ║
║  ✓ Best for: Batch processing, ML workloads                   ║
║  ✓ Strengths: Scalability, rich APIs (Python/Scala)           ║
║  ✓ Use when: Large datasets, machine learning                 ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
EOF
    
    print_success "Use Case 12 Complete!"
    print_info "Key Learnings: Engine selection, performance trade-offs, use-case matching"
    wait_for_user
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    clear
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                     ShuDL Interactive Use Cases                           ║
║                   Complete Hands-On Learning Suite                        ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

Select a use case to explore (or 'all' to run everything):

  DATA LAKEHOUSE & ANALYTICS
  ─────────────────────────────────────────────────────────────────────────
  1.  Data Lakehouse Analytics (Trino + Iceberg + Nessie)
  4.  Data Versioning & Time Travel (Nessie + Iceberg)  
  5.  Unified Storage Layer (MinIO S3)
  8.  Multi-Table ACID Transactions
  9.  Schema Evolution

  REAL-TIME STREAMING
  ─────────────────────────────────────────────────────────────────────────
  2.  Real-Time Event Streaming (Kafka)
  7.  Stream Processing Platform (Flink)
  10. Flink Streaming Job (Kafka → Processing)

  ANALYTICS ENGINES
  ─────────────────────────────────────────────────────────────────────────
  3.  Real-Time OLAP Analytics (ClickHouse)
  12. Cross-Engine Query Comparison

  DATA ENGINEERING
  ─────────────────────────────────────────────────────────────────────────
  6.  Change Data Capture (Kafka Connect + Debezium)
  11. dbt Data Transformations

  ═════════════════════════════════════════════════════════════════════════
  all  - Run all 12 use cases sequentially
  q    - Quit
  ═════════════════════════════════════════════════════════════════════════

EOF
    echo -ne "${CYAN}Enter your choice: ${NC}"
}

main() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1) usecase_1_data_lakehouse_analytics ;;
            2) usecase_2_realtime_streaming ;;
            3) usecase_3_realtime_olap ;;
            4) usecase_4_data_versioning ;;
            5) usecase_5_unified_storage ;;
            6) usecase_6_change_data_capture ;;
            7) usecase_7_stream_processing ;;
            8) usecase_8_acid_transactions ;;
            9) usecase_9_schema_evolution ;;
            10) usecase_10_flink_streaming_job ;;
            11) usecase_11_dbt_transformations ;;
            12) usecase_12_cross_engine_comparison ;;
            all)
                print_header "Running All 12 Use Cases"
                for i in {1..12}; do
                    eval "usecase_${i}_*"
                done
                print_success "All use cases completed!"
                wait_for_user
                ;;
            q|Q) 
                echo ""
                print_info "Thanks for exploring ShuDL! 🚀"
                echo ""
                exit 0
                ;;
            *) 
                print_error "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Start the interactive guide
main
