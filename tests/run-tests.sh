#!/bin/bash

# ShuDL Test Runner
# Orchestrates all test suites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/test_helpers.sh"

# Test modes
MODE="${1:-full}"  # full, quick, health, integration, e2e

echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║                   ShuDL Test Runner                           ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Mode: $MODE"
echo ""

case "$MODE" in
    "full")
        echo "Running FULL test suite (all tests)..."
        echo ""
        
        # Run comprehensive test
        "${SCRIPT_DIR}/comprehensive-test-all-21-components.sh"
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
