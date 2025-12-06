#!/bin/bash
# Datalyptica Platform Validation Script
# Run after completing all deployment phases

set -e

NAMESPACE="datalyptica"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "  Datalyptica Platform Validation"
echo "  Namespace: $NAMESPACE"
echo "========================================="
echo ""

# Function to check pods
check_pods() {
    echo "1. Checking Pod Status..."
    NOT_RUNNING=$(oc get pods -n $NAMESPACE --no-headers | grep -v -E "Running|Completed" | wc -l)
    TOTAL_PODS=$(oc get pods -n $NAMESPACE --no-headers | wc -l)
    RUNNING_PODS=$(oc get pods -n $NAMESPACE --no-headers | grep -E "Running|Completed" | wc -l)
    
    if [ $NOT_RUNNING -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} All pods are Running/Completed ($RUNNING_PODS/$TOTAL_PODS)"
    else
        echo -e "   ${RED}✗${NC} Some pods are not Running ($RUNNING_PODS/$TOTAL_PODS)"
        oc get pods -n $NAMESPACE | grep -v -E "Running|Completed|NAME"
        return 1
    fi
}

# Function to check PVCs
check_pvcs() {
    echo ""
    echo "2. Checking Persistent Volume Claims..."
    NOT_BOUND=$(oc get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep -v Bound | wc -l)
    TOTAL_PVC=$(oc get pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    
    if [ $TOTAL_PVC -eq 0 ]; then
        echo -e "   ${YELLOW}⚠${NC} No PVCs found (storage layer may not be deployed yet)"
        return 0
    fi
    
    if [ $NOT_BOUND -eq 0 ]; then
        echo -e "   ${GREEN}✓${NC} All PVCs are Bound ($TOTAL_PVC/$TOTAL_PVC)"
    else
        echo -e "   ${RED}✗${NC} Some PVCs are not Bound"
        oc get pvc -n $NAMESPACE | grep -v Bound
        return 1
    fi
}

# Function to check routes
check_routes() {
    echo ""
    echo "3. Checking Routes..."
    ROUTES=$(oc get routes -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    
    if [ $ROUTES -eq 0 ]; then
        echo -e "   ${YELLOW}⚠${NC} No routes found (services may not be exposed yet)"
        return 0
    fi
    
    echo -e "   ${GREEN}✓${NC} Found $ROUTES exposed routes:"
    oc get routes -n $NAMESPACE -o custom-columns=NAME:.metadata.name,HOST:.spec.host --no-headers | sed 's/^/     • /'
}

# Function to test MinIO
test_minio() {
    echo ""
    echo "4. Testing MinIO Object Storage..."
    MINIO_ROUTE=$(oc get route minio-console -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -z "$MINIO_ROUTE" ]; then
        echo -e "   ${YELLOW}⚠${NC} MinIO route not found (storage layer may not be deployed yet)"
        return 0
    fi
    
    if curl -sk --max-time 5 "https://$MINIO_ROUTE" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✓${NC} MinIO console is accessible at https://$MINIO_ROUTE"
    else
        echo -e "   ${RED}✗${NC} MinIO console is not accessible"
        return 1
    fi
}

# Function to test Nessie
test_nessie() {
    echo ""
    echo "5. Testing Nessie Catalog..."
    NESSIE_ROUTE=$(oc get route nessie -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -z "$NESSIE_ROUTE" ]; then
        echo -e "   ${YELLOW}⚠${NC} Nessie route not found (catalog layer may not be deployed yet)"
        return 0
    fi
    
    HEALTH=$(curl -sk --max-time 5 "https://$NESSIE_ROUTE/q/health" 2>/dev/null)
    if echo "$HEALTH" | grep -q '"status":"UP"'; then
        echo -e "   ${GREEN}✓${NC} Nessie catalog is healthy at https://$NESSIE_ROUTE"
    else
        echo -e "   ${RED}✗${NC} Nessie catalog is not healthy"
        return 1
    fi
}

# Function to test Spark
test_spark() {
    echo ""
    echo "6. Testing Apache Spark..."
    SPARK_MASTER=$(oc get pods -l datalyptica.io/component=master -n $NAMESPACE --no-headers 2>/dev/null | grep Running | wc -l)
    SPARK_WORKERS=$(oc get pods -l datalyptica.io/component=worker -n $NAMESPACE --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ $SPARK_MASTER -eq 0 ]; then
        echo -e "   ${YELLOW}⚠${NC} Spark not found (processing layer may not be deployed yet)"
        return 0
    fi
    
    if [ $SPARK_MASTER -ge 1 ] && [ $SPARK_WORKERS -ge 3 ]; then
        echo -e "   ${GREEN}✓${NC} Spark cluster is running ($SPARK_MASTER master, $SPARK_WORKERS workers)"
        SPARK_ROUTE=$(oc get route spark-master -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
        if [ -n "$SPARK_ROUTE" ]; then
            echo -e "     • Spark UI: https://$SPARK_ROUTE"
        fi
    else
        echo -e "   ${RED}✗${NC} Spark cluster is not fully running"
        return 1
    fi
}

# Function to test Flink
test_flink() {
    echo ""
    echo "7. Testing Apache Flink..."
    FLINK_ROUTE=$(oc get route flink-jobmanager -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -z "$FLINK_ROUTE" ]; then
        echo -e "   ${YELLOW}⚠${NC} Flink not found (processing layer may not be deployed yet)"
        return 0
    fi
    
    OVERVIEW=$(curl -sk --max-time 5 "https://$FLINK_ROUTE/overview" 2>/dev/null)
    TASKMANAGERS=$(echo "$OVERVIEW" | grep -o '"taskmanagers":[0-9]*' | cut -d: -f2)
    SLOTS=$(echo "$OVERVIEW" | grep -o '"slots-total":[0-9]*' | cut -d: -f2)
    
    if [ -n "$TASKMANAGERS" ] && [ $TASKMANAGERS -ge 3 ]; then
        echo -e "   ${GREEN}✓${NC} Flink cluster is running ($TASKMANAGERS TaskManagers, $SLOTS total slots)"
        echo -e "     • Flink Dashboard: https://$FLINK_ROUTE"
        
        # Check JobManager HA
        JOBMANAGERS=$(oc get pods -l datalyptica.io/component=flink-jobmanager -n $NAMESPACE --no-headers 2>/dev/null | grep Running | wc -l)
        if [ $JOBMANAGERS -eq 2 ]; then
            echo -e "     • High Availability: ${GREEN}✓${NC} (2 JobManagers for leader election)"
        fi
    else
        echo -e "   ${RED}✗${NC} Flink cluster is not fully running"
        return 1
    fi
}

# Function to check storage usage
check_storage() {
    echo ""
    echo "8. Checking Storage Usage..."
    
    PVC_INFO=$(oc get pvc -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $4}' | grep -E '[0-9]+Gi')
    
    if [ -z "$PVC_INFO" ]; then
        echo -e "   ${YELLOW}⚠${NC} No storage information available"
        return 0
    fi
    
    TOTAL_STORAGE=$(echo "$PVC_INFO" | sed 's/Gi//' | awk '{sum+=$1} END {print sum}')
    echo -e "   ${GREEN}✓${NC} Total allocated storage: ${TOTAL_STORAGE}Gi"
}

# Function to check ImageStreams
check_images() {
    echo ""
    echo "9. Checking Custom Images..."
    
    SPARK_IMAGE=$(oc get imagestream spark-iceberg -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    FLINK_IMAGE=$(oc get imagestream flink-connectors -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    
    if [ $SPARK_IMAGE -eq 0 ] && [ $FLINK_IMAGE -eq 0 ]; then
        echo -e "   ${YELLOW}⚠${NC} Custom images not found (may use external images)"
        return 0
    fi
    
    if [ $SPARK_IMAGE -eq 1 ]; then
        SPARK_TAG=$(oc get imagestream spark-iceberg -n $NAMESPACE -o jsonpath='{.status.tags[0].tag}' 2>/dev/null)
        echo -e "   ${GREEN}✓${NC} Spark custom image: spark-iceberg:$SPARK_TAG"
    fi
    
    if [ $FLINK_IMAGE -eq 1 ]; then
        FLINK_TAG=$(oc get imagestream flink-connectors -n $NAMESPACE -o jsonpath='{.status.tags[0].tag}' 2>/dev/null)
        echo -e "   ${GREEN}✓${NC} Flink custom image: flink-connectors:$FLINK_TAG"
    fi
}

# Function to check PodDisruptionBudgets
check_pdbs() {
    echo ""
    echo "10. Checking High Availability Configuration..."
    
    PDBS=$(oc get pdb -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    
    if [ $PDBS -eq 0 ]; then
        echo -e "   ${YELLOW}⚠${NC} No PodDisruptionBudgets found (HA may not be configured)"
        return 0
    fi
    
    echo -e "   ${GREEN}✓${NC} Found $PDBS PodDisruptionBudgets for high availability"
    oc get pdb -n $NAMESPACE --no-headers 2>/dev/null | awk '{print "     • " $1 ": minAvailable=" $2}'
}

# Main execution
FAILED=0

check_pods || FAILED=$((FAILED+1))
check_pvcs || FAILED=$((FAILED+1))
check_routes || FAILED=$((FAILED+1))
test_minio || FAILED=$((FAILED+1))
test_nessie || FAILED=$((FAILED+1))
test_spark || FAILED=$((FAILED+1))
test_flink || FAILED=$((FAILED+1))
check_storage || FAILED=$((FAILED+1))
check_images || FAILED=$((FAILED+1))
check_pdbs || FAILED=$((FAILED+1))

echo ""
echo "========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Validation Passed!${NC}"
    echo "All deployed components are healthy."
else
    echo -e "${RED}✗ Validation Failed!${NC}"
    echo "$FAILED check(s) failed."
    exit 1
fi
echo "========================================="
echo ""

# Show quick access URLs
echo "Quick Access URLs:"
echo "===================="
MINIO_ROUTE=$(oc get route minio-console -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
NESSIE_ROUTE=$(oc get route nessie -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
SPARK_ROUTE=$(oc get route spark-master -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
FLINK_ROUTE=$(oc get route flink-jobmanager -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)

[ -n "$MINIO_ROUTE" ] && echo "MinIO Console:    https://$MINIO_ROUTE"
[ -n "$NESSIE_ROUTE" ] && echo "Nessie Catalog:   https://$NESSIE_ROUTE"
[ -n "$SPARK_ROUTE" ] && echo "Spark Master UI:  https://$SPARK_ROUTE"
[ -n "$FLINK_ROUTE" ] && echo "Flink Dashboard:  https://$FLINK_ROUTE"
echo ""

exit 0
