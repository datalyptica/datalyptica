#!/bin/bash

# Phase 1B Testing Suite
# Comprehensive testing of all enhanced features

echo "🚀 ShuDL Phase 1B Feature Testing Suite"
echo "========================================"
echo ""

BASE_URL="http://localhost:8080"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_TOTAL=0

# Helper function for testing
test_endpoint() {
    local name="$1"
    local endpoint="$2"
    local method="${3:-GET}"
    local data="$4"
    
    echo -n "Testing ${name}... "
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "%{http_code}" "$BASE_URL$endpoint")
    fi
    
    http_code="${response: -3}"
    body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED (HTTP $http_code)${NC}"
        return 1
    fi
}

echo -e "${BLUE}Phase 1B.1: Visual Component Selection & Drag-and-Drop${NC}"
echo "--------------------------------------------------------"

# Test 1: Health Check
test_endpoint "Health Check" "/health"

# Test 2: Main Page Load
test_endpoint "Main Page Load" "/"

# Test 3: Static Assets
test_endpoint "CSS Assets" "/static/css/installer.css"
test_endpoint "JS Assets" "/static/js/installer.js"

echo ""
echo -e "${BLUE}Phase 1B.2: Backend API & Service Management${NC}"
echo "------------------------------------------------"

# Test 4: Service Definitions API
test_endpoint "Services API" "/api/v1/compose/services"

# Test 5: Default Configurations
test_endpoint "Default Configurations" "/api/v1/compose/defaults"

# Test 6: Docker Status
test_endpoint "Docker Status" "/api/v1/docker/status"

echo ""
echo -e "${BLUE}Phase 1B.3: Real-time Validation${NC}"
echo "-----------------------------------"

# Test 7: Configuration Validation
config_data='{"project_name":"test","network_name":"testnet","environment":"development","services":{"postgresql":{"enabled":true},"minio":{"enabled":true}}}'
test_endpoint "Configuration Validation" "/api/v1/compose/validate" "POST" "$config_data"

echo ""
echo -e "${BLUE}Phase 1B.4: Configuration Export/Import${NC}"
echo "--------------------------------------------"

# Test 8: Configuration Preview
test_endpoint "Configuration Preview" "/api/v1/compose/preview" "POST" "$config_data"

# Test 9: Compose Generation
test_endpoint "Compose Generation" "/api/v1/compose/generate" "POST" "$config_data"

echo ""
echo -e "${BLUE}Phase 1B.5: Enhanced Web Interface${NC}"
echo "-----------------------------------"

# Test 10: Web Interface Assets
echo -n "Testing enhanced HTML structure... "
TESTS_TOTAL=$((TESTS_TOTAL + 1))
page_content=$(curl -s "$BASE_URL/")

# Check for Phase 1B features in HTML
if echo "$page_content" | grep -q "service-builder" && \
   echo "$page_content" | grep -q "drag-and-drop" && \
   echo "$page_content" | grep -q "dependency-graph"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
fi

# Test 11: CSS Features
echo -n "Testing Phase 1B CSS features... "
TESTS_TOTAL=$((TESTS_TOTAL + 1))
css_content=$(curl -s "$BASE_URL/static/css/installer.css")

if echo "$css_content" | grep -q "service-card" && \
   echo "$css_content" | grep -q "dependency-graph" && \
   echo "$css_content" | grep -q "validation-indicator"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
fi

# Test 12: JavaScript Modules
echo -n "Testing JavaScript modules... "
TESTS_TOTAL=$((TESTS_TOTAL + 1))
js_content=$(curl -s "$BASE_URL/static/js/installer.js")

if echo "$js_content" | grep -q "ServiceBuilder" && \
   echo "$js_content" | grep -q "drag" && \
   echo "$js_content" | grep -q "validation"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
fi

echo ""
echo -e "${BLUE}Phase 1B.6: Backend Architecture${NC}"
echo "------------------------------------"

# Test 13: API Structure
echo -n "Testing modular API endpoints... "
TESTS_TOTAL=$((TESTS_TOTAL + 1))

if curl -s "$BASE_URL/api/v1/compose/services" >/dev/null && \
   curl -s "$BASE_URL/api/v1/docker/status" >/dev/null && \
   curl -s "$BASE_URL/health" >/dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
fi

echo ""
echo "=========================================="
echo -e "${YELLOW}Phase 1B Testing Results${NC}"
echo "=========================================="
echo "Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! Phase 1B is working perfectly!${NC}"
    exit 0
else
    failed=$((TESTS_TOTAL - TESTS_PASSED))
    echo -e "${YELLOW}⚠️  $failed tests failed. See details above.${NC}"
    exit 1
fi 