#!/bin/bash
# Validation script for Datalyptica deployment
set -e

echo "=========================================="
echo "  Datalyptica Deployment Validation"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Test function
test_check() {
    local test_name="$1"
    local test_command="$2"
    
    printf "Testing: %-50s " "$test_name"
    
    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

test_warning() {
    local test_name="$1"
    local test_command="$2"
    
    printf "Testing: %-50s " "$test_name"
    
    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠️  WARN${NC}"
        ((WARNINGS++))
        return 1
    fi
}

echo "1. Namespace Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_check "datalyptica-operators namespace exists" \
    "oc get namespace datalyptica-operators"
test_check "datalyptica-storage namespace exists" \
    "oc get namespace datalyptica-storage"
test_check "datalyptica-control namespace exists" \
    "oc get namespace datalyptica-control"
test_check "datalyptica-data namespace exists" \
    "oc get namespace datalyptica-data"
test_check "datalyptica-management namespace exists" \
    "oc get namespace datalyptica-management"
echo ""

echo "2. Operator Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_check "CloudNativePG operator running" \
    "oc get pod -n datalyptica-operators -l app.kubernetes.io/name=cloudnative-pg | grep Running"
test_check "Strimzi operator running" \
    "oc get pod -n datalyptica-operators -l name=strimzi-cluster-operator | grep Running"
test_warning "MinIO operator running" \
    "oc get pod -n minio-operator -l name=minio-operator | grep Running"
echo ""

echo "3. Storage Layer Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_check "PostgreSQL cluster exists" \
    "oc get cluster postgresql-ha -n datalyptica-storage"
test_check "PostgreSQL primary pod running" \
    "oc get pod -n datalyptica-storage -l cnpg.io/cluster=postgresql-ha,role=primary | grep Running"
test_check "PostgreSQL replica pod running" \
    "oc get pod -n datalyptica-storage -l cnpg.io/cluster=postgresql-ha,role=replica | grep Running"
test_warning "MinIO tenant exists" \
    "oc get tenant datalyptica-minio -n datalyptica-storage"
test_warning "MinIO pods running" \
    "oc get pod -n datalyptica-storage -l v1.min.io/tenant=datalyptica-minio | grep Running"
echo ""

echo "4. Control Layer Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_warning "Kafka cluster exists" \
    "oc get kafka datalyptica-kafka -n datalyptica-control"
test_warning "Kafka broker pods running" \
    "oc get pod -n datalyptica-control -l strimzi.io/cluster=datalyptica-kafka,strimzi.io/kind=Kafka | grep Running"
test_warning "Schema Registry running" \
    "oc get pod -n datalyptica-control -l app=schema-registry | grep Running"
test_warning "Kafka Connect running" \
    "oc get pod -n datalyptica-control -l strimzi.io/cluster=datalyptica-connect | grep Running"
echo ""

echo "5. Data Layer Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_warning "Nessie pods running" \
    "oc get pod -n datalyptica-data -l app=nessie | grep Running"
test_warning "Trino coordinator running" \
    "oc get pod -n datalyptica-data -l app=trino,component=coordinator | grep Running"
test_warning "Trino workers running" \
    "oc get pod -n datalyptica-data -l app=trino,component=worker | grep Running"
test_warning "Spark master running" \
    "oc get pod -n datalyptica-data -l app=spark,component=master | grep Running"
test_warning "Spark workers running" \
    "oc get pod -n datalyptica-data -l app=spark,component=worker | grep Running"
test_warning "Flink JobManager running" \
    "oc get pod -n datalyptica-data -l app=flink,component=jobmanager | grep Running"
test_warning "Flink TaskManager running" \
    "oc get pod -n datalyptica-data -l app=flink,component=taskmanager | grep Running"
test_warning "ClickHouse pods running" \
    "oc get pod -n datalyptica-data -l app=clickhouse | grep Running"
echo ""

echo "6. Management Layer Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_warning "Prometheus running" \
    "oc get pod -n datalyptica-management -l app=prometheus | grep Running"
test_warning "Grafana running" \
    "oc get pod -n datalyptica-management -l app=grafana | grep Running"
test_warning "Loki running" \
    "oc get pod -n datalyptica-management -l app=loki | grep Running"
test_warning "Alertmanager running" \
    "oc get pod -n datalyptica-management -l app=alertmanager | grep Running"
test_warning "Keycloak running" \
    "oc get pod -n datalyptica-management -l app=keycloak | grep Running"
echo ""

echo "7. Service Connectivity Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_warning "PostgreSQL service exists" \
    "oc get svc postgresql-rw -n datalyptica-storage"
test_warning "Nessie service exists" \
    "oc get svc nessie -n datalyptica-data"
test_warning "Trino service exists" \
    "oc get svc trino-coordinator -n datalyptica-data"
test_warning "Kafka service exists" \
    "oc get svc datalyptica-kafka-kafka-bootstrap -n datalyptica-control"
echo ""

echo "8. Route/Ingress Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_warning "Grafana route exists" \
    "oc get route grafana -n datalyptica-management"
test_warning "Keycloak route exists" \
    "oc get route keycloak -n datalyptica-management"
echo ""

echo "=========================================="
echo "  Validation Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}Passed:${NC}   $PASSED tests"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS tests (optional components)"
echo -e "${RED}Failed:${NC}   $FAILED tests"
echo ""

TOTAL=$((PASSED + WARNINGS + FAILED))
SUCCESS_RATE=$((PASSED * 100 / TOTAL))

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Validation PASSED!${NC}"
    echo ""
    echo "All critical components are running."
    if [ $WARNINGS -gt 0 ]; then
        echo "Some optional components have warnings (check above)."
    fi
    exit 0
else
    echo -e "${RED}❌ Validation FAILED!${NC}"
    echo ""
    echo "Some critical components are not running."
    echo "Please check the failed tests above."
    echo ""
    echo "Troubleshooting commands:"
    echo "  # View pod status"
    echo "  oc get pods --all-namespaces -l platform=datalyptica"
    echo ""
    echo "  # View pod logs"
    echo "  oc logs -f <pod-name> -n <namespace>"
    echo ""
    echo "  # Describe pod for events"
    echo "  oc describe pod <pod-name> -n <namespace>"
    echo ""
    exit 1
fi

