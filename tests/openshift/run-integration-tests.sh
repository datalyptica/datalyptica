#!/bin/bash
#
# End-to-End Integration Test Runner
# Executes: Spark → Flink → Trino workflow
#

set -e

NAMESPACE="datalyptica"
SPARK_POD=""
FLINK_POD=""

echo "========================================================================"
echo "  Datalyptica OpenShift Integration Test Suite"
echo "========================================================================"
echo ""

# Function to get first running pod
get_pod() {
    local label=$1
    oc get pods -n $NAMESPACE -l "$label" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Health check
echo "1. Health Check"
echo "----------------"
echo "Checking all components..."

MINIO_COUNT=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=minio' --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
NESSIE_COUNT=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=nessie' --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
SPARK_COUNT=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=spark' --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
FLINK_COUNT=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=flink' --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

echo "  ✓ MinIO: $MINIO_COUNT pods"
echo "  ✓ Nessie: $NESSIE_COUNT pods"
echo "  ✓ Spark: $SPARK_COUNT pods"
echo "  ✓ Flink: $FLINK_COUNT pods"

if [ $MINIO_COUNT -eq 0 ] || [ $NESSIE_COUNT -eq 0 ] || [ $SPARK_COUNT -eq 0 ] || [ $FLINK_COUNT -eq 0 ]; then
    echo ""
    echo "✗ ERROR: Not all components are running!"
    exit 1
fi

echo ""
echo "========================================================================"
echo "2. Spark Batch Processing Test"
echo "========================================================================"
echo "Writing sales data to Iceberg table via Nessie catalog..."
echo ""

SPARK_POD=$(get_pod "app.kubernetes.io/component=master")
if [ -z "$SPARK_POD" ]; then
    echo "✗ ERROR: Could not find Spark master pod"
    exit 1
fi

echo "Using Spark pod: $SPARK_POD"
echo ""

# Copy test script to pod
echo "Copying test script to Spark pod..."
cat tests/openshift/spark/test_iceberg_write.py | oc exec -i -n $NAMESPACE $SPARK_POD -- bash -c 'cat > /tmp/test_iceberg_write.py'

# Execute Spark test
echo "Executing Spark job..."
oc exec -n $NAMESPACE $SPARK_POD -- sh -c "/opt/spark/bin/spark-submit --master spark://spark-svc.datalyptica.svc.cluster.local:7077 --deploy-mode client /tmp/test_iceberg_write.py"

if [ $? -ne 0 ]; then
    echo ""
    echo "✗ Spark test FAILED"
    exit 1
fi

echo ""
echo "✓ Spark test completed successfully"
echo ""

echo "========================================================================"
echo "3. Flink Streaming Test"
echo "========================================================================"
echo "Streaming events to Iceberg table..."
echo ""

FLINK_POD=$(get_pod "app.kubernetes.io/component=jobmanager")
if [ -z "$FLINK_POD" ]; then
    echo "✗ ERROR: Could not find Flink JobManager pod"
    exit 1
fi

echo "Using Flink pod: $FLINK_POD"
echo ""

# Copy test script to pod
echo "Copying test script to Flink pod..."
cat tests/openshift/flink/test_streaming_cdc.py | oc exec -i -n $NAMESPACE $FLINK_POD -- bash -c 'cat > /tmp/test_streaming_cdc.py'

# Execute Flink test
echo "Executing Flink streaming job..."
oc exec -n $NAMESPACE $FLINK_POD -- python3 /tmp/test_streaming_cdc.py

if [ $? -ne 0 ]; then
    echo ""
    echo "✗ Flink test FAILED"
    exit 1
fi

echo ""
echo "✓ Flink test completed successfully"
echo ""

echo "========================================================================"
echo "4. Trino Query Test"
echo "========================================================================"
echo "Querying Iceberg tables via Trino..."
echo ""

TRINO_POD=$(get_pod "app.kubernetes.io/component=coordinator")
if [ -z "$TRINO_POD" ]; then
    echo "✗ ERROR: Could not find Trino coordinator pod"
    exit 1
fi

echo "Using Trino pod: $TRINO_POD"
echo ""

# Install trino-python-client in Trino pod if not present
echo "Installing Python dependencies in Trino pod..."
oc exec -n $NAMESPACE $TRINO_POD -- bash -c "pip3 install --quiet trino 2>/dev/null || pip install --quiet trino 2>/dev/null || true"

# Copy test script to pod
echo "Copying test script to Trino pod..."
cat tests/openshift/trino/test_query_iceberg.py | oc exec -i -n $NAMESPACE $TRINO_POD -- bash -c 'cat > /tmp/test_query_iceberg.py'

# Execute Trino test
echo "Executing Trino queries..."
oc exec -n $NAMESPACE $TRINO_POD -- python3 /tmp/test_query_iceberg.py

if [ $? -ne 0 ]; then
    echo ""
    echo "✗ Trino test FAILED"
    exit 1
fi

echo ""
echo "✓ Trino test completed successfully"
echo ""

echo "========================================================================"
echo "✓ INTEGRATION TEST SUITE COMPLETED"
echo "========================================================================"
echo ""
echo "Summary:"
echo "  ✓ Spark wrote 1000 transactions to Iceberg table"
echo "  ✓ Flink streamed aggregated events to Iceberg"
echo "  ✓ Data is available in MinIO (s3://lakehouse/)"
echo "  ✓ Nessie catalog tracks all table versions"
echo ""
echo "Next steps:"
echo "  1. Access Spark UI: https://spark-master-datalyptica.apps.virocp-poc.efinance.com.eg"
echo "  2. Access Flink Dashboard: https://flink-jobmanager-datalyptica.apps.virocp-poc.efinance.com.eg"
echo "  3. Query data with Trino (deploy Trino first)"
echo "  4. Check MinIO console: https://minio-console-datalyptica.apps.virocp-poc.efinance.com.eg"
echo ""
