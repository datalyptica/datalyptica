#!/bin/bash
#
# Simple Integration Test Runner
# Works with Git Bash on Windows
#

set -e

NAMESPACE="datalyptica"

echo "========================================================================"
echo "  Datalyptica Integration Tests"
echo "========================================================================"
echo ""

# Health check
echo "1. Health Check"
echo "----------------"

SPARK_POD=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/component=master' --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
FLINK_POD=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/component=jobmanager' --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
TRINO_POD=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/component=coordinator' --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

echo "✓ Spark pod: $SPARK_POD"
echo "✓ Flink pod: $FLINK_POD"
echo "✓ Trino pod: $TRINO_POD"
echo ""

# Test 1: Spark Batch Write
echo "========================================================================"
echo "2. Spark Batch Test"
echo "========================================================================"
echo "Writing sales data to Iceberg..."
echo ""

cat tests/openshift/spark/test_iceberg_write.py | oc exec -i -n $NAMESPACE $SPARK_POD -- sh -c 'cat > /tmp/test_iceberg_write.py'

oc exec -n $NAMESPACE $SPARK_POD -- bash -c 'POD_IP=$(hostname -i); sed "s/_DRIVER_HOST_PLACEHOLDER_/$POD_IP/" /opt/spark/conf/spark-defaults.conf > /tmp/spark-defaults-runtime.conf && MSYS_NO_PATHCONV=1 /opt/spark/bin/spark-submit --master spark://spark-svc.datalyptica.svc.cluster.local:7077 --deploy-mode client --properties-file /tmp/spark-defaults-runtime.conf --jars /opt/spark/jars/iceberg/iceberg-spark-runtime-3.5_2.12-1.10.0.jar,/opt/spark/jars/iceberg/iceberg-nessie-1.10.0.jar,/opt/spark/jars/iceberg/bundle-2.28.11.jar,/opt/spark/jars/iceberg/url-connection-client-2.28.11.jar,/opt/spark/jars/iceberg/aws-java-sdk-bundle-1.12.772.jar,/opt/spark/jars/iceberg/hadoop-aws-3.4.1.jar /tmp/test_iceberg_write.py'

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Spark test PASSED"
else
    echo ""
    echo "✗ Spark test FAILED"
    exit 1
fi

echo ""

# Test 2: Flink Streaming
echo "========================================================================"
echo "3. Flink Streaming Test"
echo "========================================================================"
echo "Streaming events to Iceberg (runs for 2 minutes)..."
echo ""

cat tests/openshift/flink/test_streaming_cdc.py | oc exec -i -n $NAMESPACE $FLINK_POD -- sh -c 'cat > /tmp/test_streaming_cdc.py'

MSYS_NO_PATHCONV=1 oc exec -n $NAMESPACE $FLINK_POD -- /opt/flink/bin/flink run -py /tmp/test_streaming_cdc.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Flink test PASSED"
else
    echo ""
    echo "✗ Flink test FAILED"
    exit 1
fi

echo ""

# Test 3: Trino Queries
echo "========================================================================"
echo "4. Trino Query Test"
echo "========================================================================"
echo "Querying Iceberg tables via Trino..."
echo ""

oc exec -n $NAMESPACE $TRINO_POD -- sh -c 'pip3 install --quiet trino 2>/dev/null || true'
cat tests/openshift/trino/test_query_iceberg.py | oc exec -i -n $NAMESPACE $TRINO_POD -- sh -c 'cat > /tmp/test_query_iceberg.py'

oc exec -n $NAMESPACE $TRINO_POD -- python3 /tmp/test_query_iceberg.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Trino test PASSED"
else
    echo ""
    echo "✗ Trino test FAILED"
    exit 1
fi

echo ""
echo "========================================================================"
echo "✓ ALL TESTS PASSED"
echo "========================================================================"
echo ""
echo "Data Pipeline Validated:"
echo "  Spark → Nessie → Iceberg → MinIO → Trino"
echo ""
echo "Access Points:"
echo "  Spark:  https://spark-master-datalyptica.apps.virocp-poc.efinance.com.eg"
echo "  Flink:  https://flink-jobmanager-datalyptica.apps.virocp-poc.efinance.com.eg"
echo "  Trino:  https://trino-datalyptica.apps.virocp-poc.efinance.com.eg"
echo "  MinIO:  https://minio-console-datalyptica.apps.virocp-poc.efinance.com.eg"
echo "  Nessie: https://nessie-datalyptica.apps.virocp-poc.efinance.com.eg"
echo ""
