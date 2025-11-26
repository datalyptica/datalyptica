#!/bin/bash

# E2E Test Suite Runner
# Runs all end-to-end tests for ShuDL Platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests"
LOG_DIR="$TEST_DIR/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "$LOG_DIR"

# Summary file
SUMMARY_FILE="$LOG_DIR/e2e-suite-summary-$TIMESTAMP.log"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          ShuDL E2E Test Suite Runner                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Metrics
total_tests=0
passed_tests=0
failed_tests=0
total_scenarios=0
passed_scenarios=0
failed_scenarios=0
start_time=$(date +%s)

# Function to run a test
run_test() {
    local test_file=$1
    local test_name=$2
    local test_num=$3
    local total_num=$4
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Test $test_num/$total_num: $test_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local log_file="$LOG_DIR/$(basename "$test_file" .sh)-$TIMESTAMP.log"
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}❌ Test file not found: $test_file${NC}"
        ((failed_tests++))
        return 1
    fi
    
    if [[ ! -x "$test_file" ]]; then
        echo -e "${YELLOW}⚠️  Making test executable...${NC}"
        chmod +x "$test_file"
    fi
    
    echo -e "${BLUE}🔄 Running test...${NC}"
    test_start=$(date +%s)
    
    if bash "$test_file" 2>&1 | tee "$log_file"; then
        test_end=$(date +%s)
        test_duration=$((test_end - test_start))
        
        # Extract scenario counts from log
        scenarios_run=$(grep -c "Scenario [0-9]*:" "$log_file" || echo 0)
        scenarios_passed=$(grep -c "✅" "$log_file" || echo 0)
        scenarios_failed=$(grep -c "❌" "$log_file" || echo 0)
        
        echo ""
        echo -e "${GREEN}✅ Test completed successfully${NC}"
        echo -e "   Duration: ${test_duration}s"
        echo -e "   Scenarios: $scenarios_passed passed, $scenarios_failed failed"
        echo -e "   Log: $log_file"
        
        ((passed_tests++))
        ((total_scenarios += scenarios_run))
        ((passed_scenarios += scenarios_passed))
        ((failed_scenarios += scenarios_failed))
        
        echo "$test_name: ✅ PASSED ($test_duration s, $scenarios_passed/$scenarios_run scenarios)" >> "$SUMMARY_FILE"
    else
        test_end=$(date +%s)
        test_duration=$((test_end - test_start))
        
        echo ""
        echo -e "${RED}❌ Test failed${NC}"
        echo -e "   Duration: ${test_duration}s"
        echo -e "   Log: $log_file"
        
        ((failed_tests++))
        
        echo "$test_name: ❌ FAILED ($test_duration s)" >> "$SUMMARY_FILE"
    fi
    
    echo ""
}

# Check if services are running
echo -e "${BLUE}🔍 Checking service health...${NC}"
echo ""

cd "$PROJECT_ROOT/docker"
services_up=$(docker compose ps --format json 2>/dev/null | jq -r '.Health' | grep -c "healthy" || echo 0)
services_total=$(docker compose ps --format json 2>/dev/null | wc -l || echo 0)

if [[ $services_up -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No services appear to be running.${NC}"
    echo ""
    read -p "Start services now? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🚀 Starting services...${NC}"
        docker compose up -d
        
        echo -e "${BLUE}⏳ Waiting for services to be healthy (max 5 minutes)...${NC}"
        timeout=300
        elapsed=0
        while [[ $elapsed -lt $timeout ]]; do
            healthy=$(docker compose ps --format json | jq -r '.Health' | grep -c "healthy" || echo 0)
            total=$(docker compose ps --format json | wc -l || echo 0)
            echo -ne "\r   Services healthy: $healthy/$total"
            
            if [[ $healthy -eq $total ]] && [[ $total -gt 0 ]]; then
                echo ""
                echo -e "${GREEN}✅ All services healthy!${NC}"
                break
            fi
            
            sleep 5
            ((elapsed += 5))
        done
        
        if [[ $elapsed -ge $timeout ]]; then
            echo ""
            echo -e "${RED}❌ Timeout waiting for services. Some may not be healthy.${NC}"
            echo ""
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Tests require running services. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Services running: $services_up/$services_total healthy${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Run tests
cd "$TEST_DIR"

# Test 1: CDC Pipeline (Real-world use case)
((total_tests++))
run_test "$TEST_DIR/e2e/cdc-pipeline.e2e.test.sh" "CDC Pipeline (Debezium → Kafka → Flink → Iceberg)" 1 5

# Test 2: Complete Pipeline
((total_tests++))
run_test "$TEST_DIR/e2e/complete-pipeline.e2e.test.sh" "Complete Data Pipeline" 2 5

# Test 3: Streaming Pipeline
((total_tests++))
run_test "$TEST_DIR/e2e/streaming-pipeline.e2e.test.sh" "Streaming Pipeline" 3 5

# Test 4: Security & Authentication
((total_tests++))
run_test "$TEST_DIR/e2e/security-auth.e2e.test.sh" "Security & Authentication" 4 5

# Test 5: Monitoring & Observability
((total_tests++))
run_test "$TEST_DIR/e2e/monitoring-observability.e2e.test.sh" "Monitoring & Observability" 5 5

# Calculate final metrics
end_time=$(date +%s)
total_duration=$((end_time - start_time))
minutes=$((total_duration / 60))
seconds=$((total_duration % 60))

# Print summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    E2E Test Suite Summary                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

{
    echo "E2E Test Suite Summary - $TIMESTAMP"
    echo "=================================="
    echo ""
    echo "Test Suites:"
    echo "  Total: $total_tests"
    echo "  Passed: $passed_tests"
    echo "  Failed: $failed_tests"
    echo ""
    echo "Scenarios:"
    echo "  Total: $total_scenarios"
    echo "  Passed: $passed_scenarios"
    echo "  Failed: $failed_scenarios"
    echo ""
    echo "Duration: ${minutes}m ${seconds}s"
    echo ""
    echo "Test Results:"
    echo "-------------"
} >> "$SUMMARY_FILE"

cat "$SUMMARY_FILE"
echo ""

if [[ $failed_tests -eq 0 ]]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 ✅  ALL TESTS PASSED! ✅                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🎉 Congratulations! All E2E tests passed successfully.${NC}"
    echo -e "${GREEN}   Platform is ready for production deployment.${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  ❌  TESTS FAILED  ❌                          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}$failed_tests/$total_tests test suites failed.${NC}"
    echo -e "${YELLOW}Check logs in: $LOG_DIR${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "  1. Services not fully initialized (wait 2-3 minutes after startup)"
    echo -e "  2. Port conflicts (check docker ps for actual ports)"
    echo -e "  3. Resource constraints (ensure sufficient CPU/memory)"
    echo ""
    echo -e "See ${CYAN}E2E_EXECUTION_GUIDE.md${NC} for troubleshooting."
    exit 1
fi
