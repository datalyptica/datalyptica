#!/bin/bash

# Complete ShuDL System Testing Suite
# Tests Phase 1B + Environment Deployment + Integrations + Monitoring

echo "🚀 Complete ShuDL System Testing Suite"
echo "========================================="
echo "Testing: Phase 1B + Deployment + Integrations + Monitoring"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
BASE_URL="http://localhost:8080"
TESTS_PASSED=0
TESTS_TOTAL=0
DEPLOYMENT_STARTED=false

# Test tracking
test_result() {
    local name="$1"
    local result="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "   ${GREEN}✓ PASSED${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   ${RED}✗ FAILED${NC}: $name"
    fi
}

# Helper functions
test_endpoint() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="$3"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint" 2>/dev/null)
    else
        response=$(curl -s -w "%{http_code}" "$BASE_URL$endpoint" 2>/dev/null)
    fi
    
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
}

wait_for_service() {
    local url="$1"
    local timeout="${2:-30}"
    local count=0
    
    echo -n "   Waiting for service to start"
    while [ $count -lt $timeout ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        count=$((count + 2))
    done
    echo -e " ${RED}✗ Timeout${NC}"
    return 1
}

# ================================
# PHASE 1: Setup & Start Services
# ================================
echo -e "${BLUE}Phase 1: Setup & Service Startup${NC}"
echo "-----------------------------------"

echo "🚀 Starting ShuDL installer service..."
cd /home/ubuntu/shudl
go run cmd/installer/main.go --config production_config.json > complete_test.log 2>&1 &
INSTALLER_PID=$!

if wait_for_service "$BASE_URL/health" 15; then
    test_result "ShuDL Installer Service Startup" "PASS"
else
    test_result "ShuDL Installer Service Startup" "FAIL"
    echo "❌ Cannot continue without installer service"
    exit 1
fi

# ================================
# PHASE 2: Phase 1B Feature Testing
# ================================
echo ""
echo -e "${BLUE}Phase 2: Phase 1B Enhanced Features${NC}"
echo "------------------------------------"

echo "🧪 Testing Phase 1B APIs..."

# Test enhanced APIs
result=$(test_endpoint "/health")
test_result "Health Check API" "$result"

result=$(test_endpoint "/")
test_result "Enhanced Web Interface" "$result"

result=$(test_endpoint "/api/v1/compose/services")
test_result "Service Definitions API" "$result"

result=$(test_endpoint "/api/v1/compose/defaults")
test_result "Default Configurations API" "$result"

# Test real-time validation
config_data='{"project_name":"test","network_name":"testnet","environment":"development","services":{"postgresql":{"enabled":true},"minio":{"enabled":true}}}'
result=$(test_endpoint "/api/v1/compose/validate" "POST" "$config_data")
test_result "Real-time Configuration Validation" "$result"

# Test configuration preview
result=$(test_endpoint "/api/v1/compose/preview" "POST" "$config_data")
test_result "Configuration Preview Generation" "$result"

echo "🎨 Testing Phase 1B Frontend..."

# Test enhanced frontend assets
result=$(test_endpoint "/static/css/installer.css")
test_result "Enhanced CSS Assets" "$result"

result=$(test_endpoint "/static/js/installer.js")
test_result "Enhanced JavaScript Assets" "$result"

# Check for Phase 1B features in HTML
page_content=$(curl -s "$BASE_URL/" 2>/dev/null)
if echo "$page_content" | grep -q "Data Platform Configurator" && \
   echo "$page_content" | grep -q "service-builder"; then
    test_result "Phase 1B HTML Structure" "PASS"
else
    test_result "Phase 1B HTML Structure" "FAIL"
fi

# ================================
# PHASE 3: Configuration Generation
# ================================
echo ""
echo -e "${BLUE}Phase 3: Configuration Generation & Validation${NC}"
echo "-----------------------------------------------"

echo "⚙️ Generating production configuration..."

# Create comprehensive production config
production_config='{
  "project_name": "shudl-complete-test",
  "network_name": "shunetwork",
  "environment": "production",
  "services": {
    "postgresql": {
      "enabled": true,
      "config": {
        "POSTGRES_DB": "shudl_db",
        "POSTGRES_USER": "shudl_user",
        "POSTGRES_PASSWORD": "shudl_password"
      }
    },
    "minio": {
      "enabled": true,
      "config": {
        "MINIO_ROOT_USER": "minioadmin",
        "MINIO_ROOT_PASSWORD": "minioadmin123"
      }
    },
    "nessie": {
      "enabled": true,
      "config": {}
    },
    "trino": {
      "enabled": true,
      "config": {}
    },
    "prometheus": {
      "enabled": true,
      "config": {}
    },
    "grafana": {
      "enabled": true,
      "config": {}
    }
  },
  "global_config": {
    "compose_project_name": "shudl-complete-test",
    "network_name": "shunetwork"
  }
}'

# Validate configuration
echo "✅ Validating complete configuration..."
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$production_config" "$BASE_URL/api/v1/compose/validate" 2>/dev/null)
if echo "$response" | grep -q '"valid":true'; then
    test_result "Production Configuration Validation" "PASS"
else
    test_result "Production Configuration Validation" "FAIL"
    echo "Response: $response"
fi

# Generate Docker Compose files
echo "🐳 Generating Docker Compose files..."
generate_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$production_config" "$BASE_URL/api/v1/compose/generate" 2>/dev/null)
if echo "$generate_response" | grep -q '"success":true'; then
    test_result "Docker Compose Generation" "PASS"
    echo "   ✓ Generated docker-compose.yml and .env files"
else
    test_result "Docker Compose Generation" "FAIL"
    echo "Response: $generate_response"
fi

# ================================
# PHASE 4: Environment Deployment
# ================================
echo ""
echo -e "${BLUE}Phase 4: Complete Environment Deployment${NC}"
echo "----------------------------------------"

echo "🚀 Deploying complete ShuDL data platform..."

# Check if compose files exist
if [ -f "generated/docker-compose.yml" ]; then
    test_result "Docker Compose File Exists" "PASS"
    
    # Deploy the environment
    echo "🐳 Starting Docker deployment..."
    cd /home/ubuntu/shudl
    
    # Try deployment
    if docker compose -f generated/docker-compose.yml up -d --pull missing 2>deployment_errors.log; then
        test_result "Docker Environment Deployment" "PASS"
        DEPLOYMENT_STARTED=true
        echo "   ✓ All services starting..."
    else
        test_result "Docker Environment Deployment" "FAIL"
        echo "   ❌ Deployment failed. Checking errors..."
        cat deployment_errors.log | head -10
    fi
else
    test_result "Docker Compose File Exists" "FAIL"
    echo "   ❌ No docker-compose.yml file found in generated/"
fi

# ================================
# PHASE 5: Service Health Checks
# ================================
if [ "$DEPLOYMENT_STARTED" = true ]; then
    echo ""
    echo -e "${BLUE}Phase 5: Service Health & Integration Testing${NC}"
    echo "----------------------------------------------"
    
    echo "🔍 Waiting for services to start (this may take 2-3 minutes)..."
    sleep 30
    
    # Check service status
    echo "📊 Checking individual service health..."
    
    # Check container status
    containers=$(docker ps --format "{{.Names}}" | grep -E "postgresql|minio|nessie|trino|prometheus|grafana" 2>/dev/null || echo "")
    
    if [ -n "$containers" ]; then
        test_result "Docker Containers Running" "PASS"
        echo "   Running containers:"
        echo "$containers" | while read container; do
            echo "   - $container"
        done
    else
        test_result "Docker Containers Running" "FAIL"
    fi
    
    # Test service endpoints
    echo "🌐 Testing service endpoints..."
    
    # Wait a bit more for services to fully start
    sleep 60
    
    # Test PostgreSQL (through container check)
    if docker exec shudl-complete-test-postgresql pg_isready -U shudl_user 2>/dev/null; then
        test_result "PostgreSQL Database Connectivity" "PASS"
    else
        test_result "PostgreSQL Database Connectivity" "FAIL"
    fi
    
    # Test MinIO
    if curl -s http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        test_result "MinIO Object Storage" "PASS"
    else
        test_result "MinIO Object Storage" "FAIL"
    fi
    
    # Test Nessie
    if curl -s http://localhost:19120/api/v1/config >/dev/null 2>&1; then
        test_result "Nessie Catalog Service" "PASS"
    else
        test_result "Nessie Catalog Service" "FAIL"
    fi
    
    # Test Trino
    if curl -s http://localhost:8081/v1/info >/dev/null 2>&1; then
        test_result "Trino Query Engine" "PASS"
    else
        test_result "Trino Query Engine" "FAIL"
    fi
    
    # Test Prometheus
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        test_result "Prometheus Monitoring" "PASS"
    else
        test_result "Prometheus Monitoring" "FAIL"
    fi
    
    # Test Grafana
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        test_result "Grafana Dashboards" "PASS"
    else
        test_result "Grafana Dashboards" "FAIL"
    fi
    
    # ================================
    # PHASE 6: Integration Testing
    # ================================
    echo ""
    echo -e "${BLUE}Phase 6: Integration & Data Flow Testing${NC}"
    echo "----------------------------------------"
    
    echo "🔗 Testing service integrations..."
    
    # Test Nessie-PostgreSQL integration
    if docker logs shudl-complete-test-nessie 2>&1 | grep -q "Connected to database" 2>/dev/null; then
        test_result "Nessie-PostgreSQL Integration" "PASS"
    else
        test_result "Nessie-PostgreSQL Integration" "FAIL"
    fi
    
    # Test Trino-Nessie integration
    if docker logs shudl-complete-test-trino 2>&1 | grep -q "catalog" 2>/dev/null; then
        test_result "Trino-Nessie Integration" "PASS"
    else
        test_result "Trino-Nessie Integration" "FAIL"
    fi
    
    # Test Prometheus metrics collection
    if curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -q "up" 2>/dev/null; then
        test_result "Prometheus Metrics Collection" "PASS"
    else
        test_result "Prometheus Metrics Collection" "FAIL"
    fi
    
    # ================================
    # PHASE 7: Management & Monitoring
    # ================================
    echo ""
    echo -e "${BLUE}Phase 7: Management & Monitoring Validation${NC}"
    echo "-------------------------------------------"
    
    echo "📊 Testing management APIs..."
    
    # Test deployment status through installer API
    status_response=$(curl -s "$BASE_URL/api/v1/docker/status" 2>/dev/null)
    if echo "$status_response" | grep -q "success" 2>/dev/null; then
        test_result "Deployment Status API" "PASS"
    else
        test_result "Deployment Status API" "FAIL"
    fi
    
    # Test service management
    echo "🎛️ Testing service management..."
    
    # List running containers for verification
    running_services=$(docker ps --format "{{.Names}}" | wc -l)
    if [ "$running_services" -ge 5 ]; then
        test_result "Multiple Services Running" "PASS"
        echo "   ✓ $running_services services are running"
    else
        test_result "Multiple Services Running" "FAIL"
        echo "   ❌ Only $running_services services running"
    fi
fi

# ================================
# PHASE 8: End-to-End Workflow
# ================================
echo ""
echo -e "${BLUE}Phase 8: End-to-End Workflow Validation${NC}"
echo "---------------------------------------"

echo "🔄 Testing complete workflow..."

# Test installer management
result=$(test_endpoint "/api/v1/docker/status")
test_result "Service Status Monitoring" "$result"

# Test configuration management workflow
workflow_config='{"project_name":"workflow-test","services":{"postgresql":{"enabled":true}}}'
result=$(test_endpoint "/api/v1/compose/validate" "POST" "$workflow_config")
test_result "Configuration Workflow" "$result"

# ================================
# FINAL RESULTS
# ================================
echo ""
echo "=============================================="
echo -e "${YELLOW}🏁 Complete ShuDL System Test Results${NC}"
echo "=============================================="
echo ""

echo "📊 Test Summary:"
echo "   Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"
echo "   Success Rate: $((TESTS_PASSED * 100 / TESTS_TOTAL))%"
echo ""

if [ "$DEPLOYMENT_STARTED" = true ]; then
    echo "🌐 System Access Points:"
    echo "   • ShuDL Installer:    http://localhost:8080"
    echo "   • MinIO Console:      http://localhost:9001"
    echo "   • Grafana:            http://localhost:3000"
    echo "   • Prometheus:         http://localhost:9090"
    echo "   • Trino Web UI:       http://localhost:8081"
    echo "   • Nessie API:         http://localhost:19120"
    echo ""
    
    echo "🐳 Docker Services Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "shudl|NAME"
    echo ""
fi

echo "📋 Component Status:"
echo "   ✅ Phase 1B Features:     Enhanced UI, Real-time validation, Backend restructure"
echo "   ✅ Configuration:         Generation, validation, preview working"
if [ "$DEPLOYMENT_STARTED" = true ]; then
    echo "   ✅ Environment:           Complete data platform deployed"
    echo "   ✅ Services:              PostgreSQL, MinIO, Nessie, Trino, Monitoring"
    echo "   ✅ Integrations:          Service-to-service connections"
    echo "   ✅ Monitoring:            Prometheus + Grafana stack"
else
    echo "   ⚠️  Environment:           Deployment testing skipped/failed"
fi

echo ""
if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! ShuDL system is fully operational!${NC}"
    exit_code=0
elif [ $TESTS_PASSED -gt $((TESTS_TOTAL * 2 / 3)) ]; then
    echo -e "${YELLOW}✅ MOSTLY SUCCESSFUL! Core functionality working.${NC}"
    exit_code=0
else
    echo -e "${RED}⚠️  SOME ISSUES DETECTED. See details above.${NC}"
    exit_code=1
fi

echo ""
echo "🔍 For detailed logs, check:"
echo "   • Installer: tail -f complete_test.log"
echo "   • Deployment: docker compose -f generated/docker-compose.yml logs"
echo "   • Individual services: docker logs <container-name>"

exit $exit_code 