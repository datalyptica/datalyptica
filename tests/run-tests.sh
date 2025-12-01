#!/bin/bash

# Datalyptica Test Runner
# Orchestrates all test suites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/test_helpers.sh"

# Test modes
MODE="${1:-full}"  # full, quick, health, integration, e2e

echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║                   Datalyptica Test Runner                           ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Mode: $MODE"
echo ""

case "$MODE" in
    "full")
        echo "Running FULL test suite (all tests)..."
        echo ""
        
        # 1. Run health checks
        echo "Phase 1: Health Checks"
        if ! "${SCRIPT_DIR}/health/test-all-health.sh"; then
            echo -e "${RED}Health checks failed. Aborting full test suite.${NC}"
            exit 1
        fi
        echo ""

        # 2. Run integration tests
        echo "Phase 2: Integration Tests"
        if ! "${SCRIPT_DIR}/integration/test-data-flow.sh"; then
            echo -e "${RED}Integration tests failed. Aborting full test suite.${NC}"
            exit 1
        fi
        echo ""

        # 3. Run end-to-end tests
        echo "Phase 3: End-to-End Tests"
        if ! "${SCRIPT_DIR}/e2e/test-complete-pipeline.sh"; then
             echo -e "${RED}E2E tests failed.${NC}"
             exit 1
        fi
        
        echo -e "${GREEN}All tests passed!${NC}"
        ;;
        
    "quick")
        echo "Running QUICK test suite (health checks only)..."
        echo ""
        
        # Run health checks only
        "${SCRIPT_DIR}/health/test-all-health.sh"
        ;;
        
    "health")
        echo "Running HEALTH test suite..."
        echo ""
        
        "${SCRIPT_DIR}/health/test-all-health.sh"
        ;;
        
    "integration")
        echo "Running INTEGRATION test suite..."
        echo ""
        
        "${SCRIPT_DIR}/integration/test-data-flow.sh"
        ;;
        
    "e2e")
        echo "Running END-TO-END test suite..."
        echo ""
        
        "${SCRIPT_DIR}/e2e/test-complete-pipeline.sh"
        ;;
        
    *)
        echo -e "${RED}Unknown test mode: $MODE${NC}"
        echo ""
        echo "Usage: $0 [mode]"
        echo ""
        echo "Modes:"
        echo "  full         - Run all tests (default)"
        echo "  quick        - Run quick health checks only"
        echo "  health       - Run health check tests"
        echo "  integration  - Run integration tests"
        echo "  e2e          - Run end-to-end tests"
        exit 1
        ;;
esac
