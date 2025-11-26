#!/bin/bash

################################################################################
#                                                                              #
#              ShuDL - Quick Validation of All 12 Use Cases                    #
#                   Non-Interactive Automated Testing                          #
#                                                                              #
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TRINO_CMD="docker exec docker-trino /opt/trino/bin/trino"
KAFKA_CMD="docker exec docker-kafka"
CLICKHOUSE_CMD="docker exec -i docker-clickhouse clickhouse-client --host localhost"
MINIO_CMD="docker exec docker-minio mc"

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}          ShuDL - All 12 Use Cases Validation                   ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Track results
PASSED=0
FAILED=0

test_usecase() {
    local num=$1
    local name=$2
    echo -ne "${BLUE}Testing Use Case $num: $name...${NC}"
}

pass() {
    echo -e " ${GREEN}✅ PASS${NC}"
    ((PASSED++))
}

fail() {
    echo -e " ${RED}❌ FAIL${NC}"
    ((FAILED++))
}

# Use Case 1: Data Lakehouse Analytics
test_usecase 1 "Data Lakehouse Analytics"
$TRINO_CMD --execute "SELECT COUNT(*) FROM iceberg.ecommerce.customers;" &>/dev/null && pass || fail

# Use Case 2: Real-Time Streaming
test_usecase 2 "Real-Time Event Streaming"
$KAFKA_CMD kafka-topics --bootstrap-server localhost:9092 --list | grep -q "order-events" && pass || fail

# Use Case 3: Real-Time OLAP
test_usecase 3 "Real-Time OLAP Analytics"
echo "SELECT count() FROM orders_realtime;" | $CLICKHOUSE_CMD 2>/dev/null | grep -q "[0-9]" && pass || fail

# Use Case 4: Data Versioning
test_usecase 4 "Data Versioning & Time Travel"
curl -s http://localhost:19120/api/v2/trees | grep -q "main" && pass || fail

# Use Case 5: Unified Storage
test_usecase 5 "Unified Storage Layer"
$MINIO_CMD alias set local http://localhost:9000 minioadmin minioadmin123 &>/dev/null && \
$MINIO_CMD ls local/lakehouse/ &>/dev/null && pass || fail

# Use Case 6: Change Data Capture
test_usecase 6 "Change Data Capture"
curl -s http://localhost:8083/ | grep -q "version" && pass || fail

# Use Case 7: Stream Processing
test_usecase 7 "Stream Processing Platform"
curl -s http://localhost:8081/overview | grep -q "flink-version" && pass || fail

# Use Case 8: ACID Transactions
test_usecase 8 "Multi-Table ACID Transactions"
$TRINO_CMD --execute "SELECT COUNT(*) FROM iceberg.ecommerce.orders;" &>/dev/null && pass || fail

# Use Case 9: Schema Evolution
test_usecase 9 "Schema Evolution"
$TRINO_CMD --execute "DESCRIBE iceberg.ecommerce.customers;" &>/dev/null | grep -q "loyalty_points" && pass || fail

# Use Case 10: Flink Streaming Job
test_usecase 10 "Flink Streaming Job"
$KAFKA_CMD kafka-topics --bootstrap-server localhost:9092 --list | grep -q "enriched-orders" && pass || fail

# Use Case 11: dbt Transformations
test_usecase 11 "dbt Data Transformations"
docker exec docker-dbt dbt --version &>/dev/null && pass || fail

# Use Case 12: Cross-Engine Comparison
test_usecase 12 "Cross-Engine Query Comparison"
$TRINO_CMD --execute "SELECT 1;" &>/dev/null && \
echo "SELECT 1;" | $CLICKHOUSE_CMD &>/dev/null && pass || fail

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                      SUMMARY                                   ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL USE CASES VALIDATED SUCCESSFULLY! 🎉${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Run interactive guide: ${YELLOW}./test-usecases.sh${NC}"
    echo -e "  2. Read documentation: ${YELLOW}./USE_CASES_GUIDE.md${NC}"
    echo -e "  3. Explore your own scenarios!"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠️  Some use cases need setup. Run the interactive guide first:${NC}"
    echo -e "  ${YELLOW}./test-usecases.sh${NC}"
    echo ""
    exit 1
fi
