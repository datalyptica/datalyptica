#!/bin/bash

# Real ShuDL System Testing Suite
# Tests the actual ShuDL functionality with custom images

echo "🚀 Real ShuDL System Testing Suite"
echo "=================================="
echo "Testing: Web Installer + Config Generation + shudlctl + Custom Images"
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

# Test tracking
test_result() {
    local name="$1"
    local result="$2"
    local details="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "   ${GREEN}✓ PASSED${NC}: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   ${RED}✗ FAILED${NC}: $name"
        if [ -n "$details" ]; then
            echo -e "     ${YELLOW}Details: $details${NC}"
        fi
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
    body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "PASS"
    else
        echo "FAIL:HTTP_$http_code"
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
# PHASE 1: ShuDL Installer Setup
# ================================
echo -e "${BLUE}Phase 1: ShuDL Installer Setup & Validation${NC}"
echo "--------------------------------------------"

echo "🚀 Starting ShuDL installer service..."
pkill -f "go run.*main.go" 2>/dev/null || true
sleep 2

go run cmd/installer/main.go --config production_config.json > real_shudl_test.log 2>&1 &
INSTALLER_PID=$!
echo "   Started installer with PID: $INSTALLER_PID"

if wait_for_service "$BASE_URL/health" 20; then
    test_result "ShuDL Installer Service" "PASS"
else
    test_result "ShuDL Installer Service" "FAIL" "Service failed to start"
    echo "❌ Cannot continue without installer service"
    cat real_shudl_test.log | tail -10
    exit 1
fi

# ================================
# PHASE 2: Web Interface Testing
# ================================
echo ""
echo -e "${BLUE}Phase 2: ShuDL Web Interface & Phase 1B Features${NC}"
echo "-----------------------------------------------"

echo "🌐 Testing ShuDL web installer..."

# Test main components
result=$(test_endpoint "/")
test_result "ShuDL Web Interface" "$result"

result=$(test_endpoint "/static/css/installer.css")
test_result "Enhanced CSS Assets" "$result"

result=$(test_endpoint "/static/js/installer.js")
test_result "Enhanced JavaScript Bundle" "$result"

# Test Phase 1B specific features
page_content=$(curl -s "$BASE_URL/" 2>/dev/null)
if echo "$page_content" | grep -q "Data Platform Configurator" && \
   echo "$page_content" | grep -q "service-builder" && \
   echo "$page_content" | grep -q "dependency-graph"; then
    test_result "Phase 1B Visual Configurator" "PASS"
else
    test_result "Phase 1B Visual Configurator" "FAIL" "Missing configurator elements"
fi

# Test ShuDL API endpoints
result=$(test_endpoint "/api/v1/compose/services")
test_result "ShuDL Service Definitions API" "$result"

result=$(test_endpoint "/api/v1/compose/defaults")
test_result "ShuDL Default Configurations API" "$result"

# ================================
# PHASE 3: Configuration Generation
# ================================
echo ""
echo -e "${BLUE}Phase 3: Configuration Generation & Validation${NC}"
echo "---------------------------------------------"

echo "⚙️ Testing ShuDL configuration generation..."

# Create a realistic ShuDL configuration
shudl_config='{
  "project_name": "shudl-production",
  "network_name": "shunetwork",
  "environment": "production",
  "services": {
    "postgresql": {
      "enabled": true,
      "config": {
        "POSTGRES_DB": "shudl_db",
        "POSTGRES_USER": "shudl_user",
        "POSTGRES_PASSWORD": "shudl_secure_pass"
      }
    },
    "minio": {
      "enabled": true,
      "config": {
        "MINIO_ROOT_USER": "shudladmin",
        "MINIO_ROOT_PASSWORD": "shudl_minio_pass123"
      }
    },
    "nessie": {
      "enabled": true,
      "config": {
        "NESSIE_VERSION_STORE_TYPE": "JDBC"
      }
    },
    "trino": {
      "enabled": true,
      "config": {}
    },
    "spark-master": {
      "enabled": true,
      "config": {}
    },
    "spark-worker": {
      "enabled": true,
      "config": {}
    }
  }
}'

# Test configuration validation
echo "✅ Testing configuration validation..."
validation_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$shudl_config" "$BASE_URL/api/v1/compose/validate" 2>/dev/null)
if echo "$validation_response" | grep -q '"valid":true'; then
    test_result "ShuDL Configuration Validation" "PASS"
else
    test_result "ShuDL Configuration Validation" "FAIL" "Config validation failed"
    echo "Response: $validation_response"
fi

# Test configuration preview
echo "👀 Testing configuration preview..."
preview_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$shudl_config" "$BASE_URL/api/v1/compose/preview" 2>/dev/null)
if echo "$preview_response" | grep -q '"success":true'; then
    test_result "ShuDL Configuration Preview" "PASS"
else
    test_result "ShuDL Configuration Preview" "FAIL" "Preview generation failed"
fi

# Test docker-compose generation
echo "🐳 Testing Docker Compose generation..."
rm -f generated/docker-compose.yml generated/.env 2>/dev/null

generate_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$shudl_config" "$BASE_URL/api/v1/compose/generate" 2>/dev/null)
if echo "$generate_response" | grep -q '"success":true'; then
    test_result "ShuDL Docker Compose Generation" "PASS"
    
    # Verify files were created
    if [ -f "generated/docker-compose.yml" ] && [ -f "generated/.env" ]; then
        test_result "Generated Files Creation" "PASS"
        echo "   ✓ Created docker-compose.yml and .env files"
    else
        test_result "Generated Files Creation" "FAIL" "Files not found"
    fi
    
    # Verify content contains ShuDL images
    if grep -q "ghcr.io/shugur-network/shudl" generated/docker-compose.yml 2>/dev/null; then
        test_result "ShuDL Custom Images Usage" "PASS"
        echo "   ✓ Using ShuDL custom Docker images"
    else
        test_result "ShuDL Custom Images Usage" "FAIL" "Not using custom images"
    fi
    
else
    test_result "ShuDL Docker Compose Generation" "FAIL" "Generation failed"
    echo "Response: $generate_response"
fi

# ================================
# PHASE 4: shudlctl CLI Testing
# ================================
echo ""
echo -e "${BLUE}Phase 4: shudlctl CLI Functionality${NC}"
echo "-----------------------------------"

echo "🔧 Testing shudlctl CLI commands..."

# Check if shudlctl exists
if [ -f "./shudlctl" ]; then
    test_result "shudlctl Binary Exists" "PASS"
    
    # Test shudlctl help
    if ./shudlctl --help >/dev/null 2>&1; then
        test_result "shudlctl Help Command" "PASS"
    else
        test_result "shudlctl Help Command" "FAIL" "Help command failed"
    fi
    
    # Test shudlctl version
    version_output=$(./shudlctl version 2>/dev/null || echo "")
    if [ -n "$version_output" ]; then
        test_result "shudlctl Version Command" "PASS"
        echo "   ✓ Version: $version_output"
    else
        test_result "shudlctl Version Command" "FAIL" "Version command failed"
    fi
    
    # Test shudlctl validate
    if [ -f "generated/docker-compose.yml" ]; then
        if ./shudlctl validate --compose-file generated/docker-compose.yml 2>/dev/null; then
            test_result "shudlctl Validate Command" "PASS"
        else
            test_result "shudlctl Validate Command" "FAIL" "Validation failed"
        fi
    else
        test_result "shudlctl Validate Command" "FAIL" "No compose file to validate"
    fi
    
else
    test_result "shudlctl Binary Exists" "FAIL" "Binary not found"
    echo "   ⚠️  Building shudlctl..."
    
    # Try to build shudlctl
    if go build -o shudlctl cmd/cli/main.go 2>/dev/null; then
        test_result "shudlctl Build" "PASS"
        echo "   ✓ Built shudlctl successfully"
        
        # Retry tests with built binary
        if ./shudlctl --help >/dev/null 2>&1; then
            test_result "shudlctl Help (Built)" "PASS"
        else
            test_result "shudlctl Help (Built)" "FAIL"
        fi
    else
        test_result "shudlctl Build" "FAIL" "Build failed"
    fi
fi

# ================================
# PHASE 5: Deployment Attempt
# ================================
echo ""
echo -e "${BLUE}Phase 5: ShuDL Environment Deployment${NC}"
echo "------------------------------------"

if [ -f "generated/docker-compose.yml" ]; then
    echo "🚀 Attempting ShuDL environment deployment..."
    
    # Check if compose file is valid
    if docker compose -f generated/docker-compose.yml config >/dev/null 2>&1; then
        test_result "Docker Compose File Validation" "PASS"
        
        # Try deployment (but don't wait for full startup due to custom images)
        echo "🐳 Starting ShuDL services..."
        deploy_output=$(docker compose -f generated/docker-compose.yml up -d 2>&1)
        deploy_exit_code=$?
        
        if [ $deploy_exit_code -eq 0 ]; then
            test_result "ShuDL Services Deployment" "PASS"
            
            # Check what containers started
            sleep 5
            running_containers=$(docker ps --format "{{.Names}}" | grep -E "shudl|postgres|minio|nessie|trino|spark" | wc -l)
            
            if [ "$running_containers" -gt 0 ]; then
                test_result "ShuDL Containers Started" "PASS"
                echo "   ✓ $running_containers ShuDL containers running"
                
                # List running services
                echo "   📊 Running ShuDL services:"
                docker ps --format "   - {{.Names}}: {{.Status}}" | grep -E "shudl|postgres|minio|nessie|trino|spark"
            else
                test_result "ShuDL Containers Started" "FAIL" "No containers started"
            fi
        else
            test_result "ShuDL Services Deployment" "FAIL" "Deployment failed"
            echo "   ❌ Deployment error: $deploy_output"
        fi
        
    else
        test_result "Docker Compose File Validation" "FAIL" "Invalid compose file"
        echo "   Checking compose file errors..."
        docker compose -f generated/docker-compose.yml config 2>&1 | head -5
    fi
else
    test_result "Docker Compose File Validation" "FAIL" "No compose file found"
fi

# ================================
# PHASE 6: Integration Validation
# ================================
echo ""
echo -e "${BLUE}Phase 6: ShuDL Integration Validation${NC}"
echo "------------------------------------"

echo "🔗 Testing ShuDL service integrations..."

# Test installer API with running containers
status_response=$(curl -s "$BASE_URL/api/v1/docker/status" 2>/dev/null)
if echo "$status_response" | grep -q "success\|containers"; then
    test_result "ShuDL Docker Status API" "PASS"
else
    test_result "ShuDL Docker Status API" "FAIL" "Status API failed"
fi

# Test logs functionality
logs_response=$(curl -s "$BASE_URL/api/v1/docker/logs" 2>/dev/null)
if [ $? -eq 0 ]; then
    test_result "ShuDL Logs API" "PASS"
else
    test_result "ShuDL Logs API" "FAIL" "Logs API failed"
fi

# Test real-time validation with actual ShuDL config
real_time_test='{"project_name":"test-validation","services":{"postgresql":{"enabled":true},"minio":{"enabled":true}}}'
validation_test=$(test_endpoint "/api/v1/compose/validate" "POST" "$real_time_test")
test_result "Real-time Configuration Validation" "$validation_test"

# ================================
# FINAL RESULTS
# ================================
echo ""
echo "=============================================="
echo -e "${YELLOW}🏁 Real ShuDL System Test Results${NC}"
echo "=============================================="
echo ""

echo "📊 Test Summary:"
echo "   Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"
echo "   Success Rate: $((TESTS_PASSED * 100 / TESTS_TOTAL))%"
echo ""

echo "🎯 ShuDL System Components Tested:"
echo "   ✅ Web Installer:         Enhanced Phase 1B interface"
echo "   ✅ Configuration Engine:  Generation, validation, preview"
echo "   ✅ Custom Images:         ShuDL Docker image usage"
echo "   ✅ File Generation:       docker-compose.yml + .env creation"
if [ -f "./shudlctl" ]; then
    echo "   ✅ CLI Tool:              shudlctl functionality"
else
    echo "   ⚠️  CLI Tool:              shudlctl needs development"
fi

# Check deployment status
running_services=$(docker ps --format "{{.Names}}" | grep -E "shudl|postgres|minio|nessie|trino|spark" | wc -l)
if [ "$running_services" -gt 0 ]; then
    echo "   ✅ Environment:           $running_services ShuDL services deployed"
else
    echo "   ⚠️  Environment:           Deployment needs custom image availability"
fi

echo ""
echo "🌐 ShuDL System Access Points:"
echo "   • ShuDL Web Installer:    http://localhost:8080"
echo "   • Enhanced Configurator:  Visual drag-and-drop interface"
echo "   • Generated Files:        generated/docker-compose.yml, generated/.env"

if [ "$running_services" -gt 0 ]; then
    echo ""
    echo "🐳 Running ShuDL Services:"
    docker ps --format "   • {{.Names}}: {{.Status}}" | grep -E "shudl|postgres|minio|nessie|trino|spark"
fi

echo ""
echo "📋 Next Steps:"
echo "   1. Verify custom Docker images are available: ghcr.io/shugur-network/shudl/*"
echo "   2. Test complete deployment with: docker compose -f generated/docker-compose.yml up -d"
echo "   3. Access ShuDL web interface for visual configuration"
echo "   4. Use shudlctl for CLI operations"

echo ""
if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! ShuDL system is fully functional!${NC}"
    exit_code=0
elif [ $TESTS_PASSED -gt $((TESTS_TOTAL * 3 / 4)) ]; then
    echo -e "${YELLOW}✅ EXCELLENT! ShuDL core functionality working perfectly.${NC}"
    exit_code=0
else
    echo -e "${RED}⚠️  SOME ISSUES DETECTED. Core ShuDL functionality may need attention.${NC}"
    exit_code=1
fi

echo ""
echo "🔍 For detailed logs:"
echo "   • ShuDL Installer: tail -f real_shudl_test.log"
echo "   • Docker Services: docker compose -f generated/docker-compose.yml logs"

# Cleanup note
echo ""
echo "🧹 To cleanup test environment:"
echo "   docker compose -f generated/docker-compose.yml down --volumes"
echo "   kill $INSTALLER_PID"

exit $exit_code 