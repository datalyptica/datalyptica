#!/bin/bash

# =============================================================================
# ShuDL Data Lakehouse - Comprehensive Test Suite
# =============================================================================
# This script runs all tests for the ShuDL data lakehouse platform
# Usage: ./run-tests.sh [--verbose] [--quick] [--category CATEGORY]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$SCRIPT_DIR"
LOG_DIR="$TESTS_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERBOSE=false
QUICK_MODE=false
TEST_CATEGORY=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Helper functions
log() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/test_run_${TIMESTAMP}.log"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_DIR/test_run_${TIMESTAMP}.log"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_DIR/test_run_${TIMESTAMP}.log"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_DIR/test_run_${TIMESTAMP}.log"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_DIR/test_run_${TIMESTAMP}.log"
}

run_test() {
    local test_name="$1"
    local test_script="$2"
    local category="${3:-general}"
    
    # Skip if category filter is set and doesn't match
    if [[ -n "$TEST_CATEGORY" && "$TEST_CATEGORY" != "$category" ]]; then
        log_info "Skipping $test_name (category: $category)"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return 0
    fi
    
    log "Running test: $test_name"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local start_time=$(date +%s)
    
    if [[ "$VERBOSE" == "true" ]]; then
        if bash "$test_script"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "$test_name completed in ${duration}s"
            TEST_RESULTS["$test_name"]="PASS"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_error "$test_name failed after ${duration}s"
            TEST_RESULTS["$test_name"]="FAIL"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        if bash "$test_script" &> "$LOG_DIR/${test_name// /_}_${TIMESTAMP}.log"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "$test_name completed in ${duration}s"
            TEST_RESULTS["$test_name"]="PASS"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_error "$test_name failed after ${duration}s (check logs: ${test_name// /_}_${TIMESTAMP}.log)"
            TEST_RESULTS["$test_name"]="FAIL"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    fi
}

print_summary() {
    echo ""
    echo "==============================================================================="
    echo -e "${PURPLE}🧪 ShuDL Test Suite Summary${NC}"
    echo "==============================================================================="
    echo -e "📊 Total Tests: $TOTAL_TESTS"
    echo -e "${GREEN}✅ Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}❌ Failed: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}⏭️  Skipped: $SKIPPED_TESTS${NC}"
    echo ""
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Failed Tests:${NC}"
        for test_name in "${!TEST_RESULTS[@]}"; do
            if [[ "${TEST_RESULTS[$test_name]}" == "FAIL" ]]; then
                echo -e "  ${RED}❌ $test_name${NC}"
            fi
        done
        echo ""
    fi
    
    if [[ $PASSED_TESTS -gt 0 ]]; then
        echo -e "${GREEN}Passed Tests:${NC}"
        for test_name in "${!TEST_RESULTS[@]}"; do
            if [[ "${TEST_RESULTS[$test_name]}" == "PASS" ]]; then
                echo -e "  ${GREEN}✅ $test_name${NC}"
            fi
        done
        echo ""
    fi
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo -e "📈 Success Rate: ${success_rate}%"
    echo -e "📋 Logs Directory: $LOG_DIR"
    echo "==============================================================================="
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

show_help() {
    cat << EOF
ShuDL Data Lakehouse Test Suite

Usage: $0 [OPTIONS]

Options:
    --verbose, -v       Show detailed output during test execution
    --quick, -q         Run only essential tests (skip performance tests)
    --category, -c CAT  Run only tests in specified category
    --help, -h          Show this help message

Categories:
    health              Service health checks
    integration         Cross-service integration tests
    config              Configuration validation tests
    performance         Performance and load tests
    all                 All tests (default)

Examples:
    $0                          # Run all tests
    $0 --verbose                # Run all tests with verbose output
    $0 --quick                  # Run essential tests only
    $0 --category health        # Run only health checks
    $0 -v -c integration        # Run integration tests with verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --category|-c)
            TEST_CATEGORY="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Setup
mkdir -p "$LOG_DIR"
cd "$DOCKER_DIR"

# Print header
echo ""
echo "==============================================================================="
echo -e "${PURPLE}🏗️  ShuDL Data Lakehouse - Test Suite${NC}"
echo "==============================================================================="
echo -e "🕐 Started: $(date)"
echo -e "📂 Working Directory: $(pwd)"
echo -e "📋 Log Directory: $LOG_DIR"
echo -e "🎯 Category: ${TEST_CATEGORY:-all}"
echo -e "⚡ Quick Mode: $QUICK_MODE"
echo -e "📢 Verbose: $VERBOSE"
echo "==============================================================================="
echo ""

# Trap to ensure summary is always printed
trap print_summary EXIT

# =============================================================================
# Phase 1: Prerequisites and Environment
# =============================================================================
log "Phase 1: Prerequisites and Environment Validation"

run_test "Environment Variables" "$TESTS_DIR/config/test_env_vars.sh" "config"
run_test "Docker Compose Validation" "$TESTS_DIR/config/test_docker_compose.sh" "config"

# =============================================================================
# Phase 2: Service Health Checks
# =============================================================================
log "Phase 2: Service Health Checks"

run_test "PostgreSQL Health" "$TESTS_DIR/health/test_postgresql.sh" "health"
run_test "MinIO Health" "$TESTS_DIR/health/test_minio.sh" "health"
run_test "Nessie Health" "$TESTS_DIR/health/test_nessie.sh" "health"
run_test "Trino Health" "$TESTS_DIR/health/test_trino.sh" "health"
run_test "Spark Health" "$TESTS_DIR/health/test_spark.sh" "health"

# =============================================================================
# Phase 3: Unit Tests
# =============================================================================
log "Phase 3: Unit Tests"

# Storage unit tests
run_test "MinIO Unit Tests" "$TESTS_DIR/unit/storage/minio.unit.test.sh" "unit"
run_test "PostgreSQL Unit Tests" "$TESTS_DIR/unit/storage/postgresql.unit.test.sh" "unit"
run_test "Nessie Unit Tests" "$TESTS_DIR/unit/storage/nessie.unit.test.sh" "unit"

# Compute unit tests
run_test "Trino Unit Tests" "$TESTS_DIR/unit/compute/trino.unit.test.sh" "unit"

# =============================================================================
# Phase 4: Integration Tests
# =============================================================================
log "Phase 4: Integration Tests"

run_test "Spark-Iceberg Integration" "$TESTS_DIR/integration/test_spark_iceberg.sh" "integration"
run_test "Cross-Engine Data Access" "$TESTS_DIR/integration/test_cross_engine.sh" "integration"

# =============================================================================
# Phase 5: E2E Tests
# =============================================================================
log "Phase 5: End-to-End Tests"

run_test "Complete Pipeline E2E" "$TESTS_DIR/e2e/complete-pipeline.e2e.test.sh" "e2e"

# =============================================================================
# Phase 6: Data Pipeline Tests
# =============================================================================
log "Phase 6: Data Pipeline Tests"

# Additional integration tests can be added here as needed

# =============================================================================
# Phase 7: Performance Tests (unless quick mode)
# =============================================================================
if [[ "$QUICK_MODE" != "true" ]]; then
    log "Phase 7: Performance Tests"
    
    # Performance tests can be added here as needed
    log_info "No performance tests implemented yet"
else
    log_info "Skipping performance tests (quick mode enabled)"
fi

# Summary will be printed by the trap 