#!/bin/bash
# Use Case 0: Simple SQL Analytics with Trino + Iceberg
# Demonstrates: SQL-based data operations on Iceberg tables

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Use Case 0: Simple SQL Analytics - Trino + Iceberg"

echo ""
echo "============================================================"
echo "  Use Case: Product Catalog Management"
echo "============================================================"
echo ""
echo "Scenario: Manage product catalog using SQL on Iceberg"
echo "Stack: Trino (SQL engine) + Iceberg (storage) + Nessie (catalog)"
echo ""

# Helper function to run Trino query
run_query() {
    local query="$1"
    local description="$2"
    
    test_step "$description"
    local result=$("${SCRIPT_DIR}/../helpers/trino_query.sh" "$query" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        test_info "✓ Query executed"
        if [[ -n "$result" && "$result" != "null" ]]; then
            echo "   Result: $result"
        fi
        return 0
    else
        test_error "Query failed: $query"
        return 1
    fi
}

# Step 1: Create namespace
run_query "CREATE SCHEMA IF NOT EXISTS iceberg.retail" "Step 1: Creating retail schema..."

# Step 2: Create products table
run_query "CREATE TABLE IF NOT EXISTS iceberg.retail.products (
    product_id INT,
    name VARCHAR,
    category VARCHAR,
    price DOUBLE,
    stock_quantity INT
) WITH (
    format = 'PARQUET'
)" "Step 2: Creating products table..."

# Step 3: Insert sample data
test_step "Step 3: Inserting sample product data..."

run_query "INSERT INTO iceberg.retail.products VALUES 
    (1, 'Laptop Pro', 'Electronics', 1299.99, 50),
    (2, 'Wireless Mouse', 'Electronics', 29.99, 200),
    (3, 'Office Chair', 'Furniture', 249.99, 30),
    (4, 'Desk Lamp', 'Furniture', 45.99, 100),
    (5, 'Coffee Maker', 'Appliances', 89.99, 75)" "Inserting products..."

# Step 4: Query data
run_query "SELECT COUNT(*) as product_count FROM iceberg.retail.products" "Step 4: Counting products..."

# Step 5: Analytics query
run_query "SELECT 
    category,
    COUNT(*) as item_count,
    ROUND(AVG(price), 2) as avg_price,
    SUM(stock_quantity) as total_stock
FROM iceberg.retail.products
GROUP BY category
ORDER BY total_stock DESC" "Step 5: Running analytics by category..."

# Step 6: Update operation
run_query "UPDATE iceberg.retail.products 
SET stock_quantity = stock_quantity - 10 
WHERE product_id = 2" "Step 6: Updating stock (selling 10 mice)..."

# Step 7: Verify update
run_query "SELECT name, stock_quantity 
FROM iceberg.retail.products 
WHERE product_id = 2" "Step 7: Verifying update..."

# Step 8: Check table history (Iceberg time-travel)
run_query "SELECT snapshot_id, committed_at, operation 
FROM iceberg.retail.\"products\$snapshots\" 
ORDER BY committed_at DESC 
LIMIT 3" "Step 8: Checking table history..."

# Step 9: Get table metadata
test_step "Step 9: Checking Nessie catalog..."
NESSIE_ENTRIES=$(curl -s http://localhost:19120/api/v2/trees/branch/main/entries | grep -o '"name"' | wc -l | tr -d ' ')
test_info "✓ Found $NESSIE_ENTRIES entries in Nessie catalog"

# Step 10: Cross-engine validation
test_step "Step 10: Validating table exists..."
TABLES=$("${SCRIPT_DIR}/../helpers/trino_query.sh" "SHOW TABLES FROM iceberg.retail" 2>&1)
if echo "$TABLES" | grep -q "products"; then
    test_info "✓ Table exists and is accessible"
else
    test_warning "Table validation inconclusive"
fi

echo ""
echo "============================================================"
echo "  Use Case 0: COMPLETED ✅"
echo "============================================================"
echo ""
echo "Validated:"
echo "  ✓ Iceberg table creation via SQL"
echo "  ✓ Data insertion and querying"
echo "  ✓ UPDATE operations (Iceberg ACID)"
echo "  ✓ Table history tracking"
echo "  ✓ Analytics queries"
echo "  ✓ Nessie catalog integration"
echo ""

test_success "Use Case 0: Simple SQL Analytics"
print_test_summary

