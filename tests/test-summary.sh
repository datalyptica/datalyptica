#!/usr/bin/env bash

# Quick Test Summary Generator
# Generates a test report for all 21 components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/test_helpers.sh"

echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║          ShuDL Component Test Summary                         ║"
echo "║          Testing All 21 Platform Components                   ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Component categories
declare -a STORAGE=("minio" "postgresql" "nessie")
declare -a STREAMING=("zookeeper" "kafka" "schema-registry" "kafka-ui")
declare -a PROCESSING=("spark-master" "spark-worker" "flink-jobmanager" "flink-taskmanager")
declare -a ANALYTICS=("trino" "clickhouse" "dbt" "kafka-connect")
declare -a OBSERVABILITY=("prometheus" "grafana" "loki" "alloy" "alertmanager" "keycloak")

# Status tracking
TOTAL=0
HEALTHY=0
RUNNING=0
UNHEALTHY=0

# Check all components
check_component() {
    local component=$1
    local container="shudl-${component}"
    
    TOTAL=$((TOTAL + 1))
    
    if check_service_running "$container" 2>/dev/null; then
        if check_service_healthy "$container" 2>/dev/null; then
            HEALTHY=$((HEALTHY + 1))
            echo -e "${GREEN}✓${NC} $component"
        else
            RUNNING=$((RUNNING + 1))
            echo -e "${YELLOW}○${NC} $component (running, no health check)"
        fi
    else
        UNHEALTHY=$((UNHEALTHY + 1))
        echo -e "${RED}✗${NC} $component"
    fi
}

# Storage Layer
echo -e "${CYAN}═══ Storage Layer (3 components) ═══${NC}"
for comp in "${STORAGE[@]}"; do check_component "$comp"; done
echo ""

# Streaming Layer
echo -e "${CYAN}═══ Streaming Layer (4 components) ═══${NC}"
for comp in "${STREAMING[@]}"; do check_component "$comp"; done
echo ""

# Processing Layer
echo -e "${CYAN}═══ Processing Layer (4 components) ═══${NC}"
for comp in "${PROCESSING[@]}"; do check_component "$comp"; done
echo ""

# Analytics Layer
echo -e "${CYAN}═══ Query/Analytics Layer (4 components) ═══${NC}"
for comp in "${ANALYTICS[@]}"; do check_component "$comp"; done
echo ""

# Observability Layer
echo -e "${CYAN}═══ Observability Layer (6 components) ═══${NC}"
for comp in "${OBSERVABILITY[@]}"; do check_component "$comp"; done
echo ""

# Summary
echo -e "${PURPLE}════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}                  Summary                           ${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Healthy:   $HEALTHY / $TOTAL${NC}"
echo -e "${YELLOW}○ Running:   $RUNNING / $TOTAL${NC}"
echo -e "${RED}✗ Down:      $UNHEALTHY / $TOTAL${NC}"
echo -e "${PURPLE}════════════════════════════════════════════════════${NC}"
echo ""

# Health percentage
OPERATIONAL=$((HEALTHY + RUNNING))
HEALTH_PERCENT=$(( (OPERATIONAL * 100) / TOTAL ))

if [ $HEALTH_PERCENT -eq 100 ]; then
    echo -e "${GREEN}🎉 All systems operational! (100%)${NC}"
elif [ $HEALTH_PERCENT -ge 80 ]; then
    echo -e "${GREEN}✅ System mostly healthy ($HEALTH_PERCENT%)${NC}"
elif [ $HEALTH_PERCENT -ge 50 ]; then
    echo -e "${YELLOW}⚠️  System partially operational ($HEALTH_PERCENT%)${NC}"
else
    echo -e "${RED}❌ System requires attention ($HEALTH_PERCENT%)${NC}"
fi

echo ""
echo "Run './tests/run-tests.sh full' for comprehensive testing"
echo "Run './tests/run-tests.sh quick' for quick health checks"
echo ""
