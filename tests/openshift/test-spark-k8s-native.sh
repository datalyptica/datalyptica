#!/bin/bash
# Test Spark Kubernetes Native Mode
# This test verifies that Spark can create executor pods dynamically in K8s

set -e

NAMESPACE=${NAMESPACE:-datalyptica}

echo "========================================================================"
echo "  Spark Kubernetes Native Mode Test"
echo "========================================================================"

# Get spark-submit pod
SUBMIT_POD=$(oc get pods -n $NAMESPACE -l 'app.kubernetes.io/component=submit' --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

if [ -z "$SUBMIT_POD" ]; then
    echo "❌ ERROR: No running spark-submit pod found"
    exit 1
fi

echo "✓ Spark submit pod: $SUBMIT_POD"
echo ""

# Create simple test Python script
cat > /tmp/test_k8s_native.py << 'EOF'
from pyspark.sql import SparkSession
import sys

print("=" * 80)
print("SPARK K8S NATIVE MODE TEST")
print("=" * 80)

try:
    # Create Spark session
    print("\n1. Creating Spark session in K8s native mode...")
    spark = SparkSession.builder \
        .appName("K8s-Native-Test") \
        .getOrCreate()
    
    print(f"   ✓ Spark version: {spark.version}")
    print(f"   ✓ Master: {spark.sparkContext.master}")
    
    # Check executor info
    print("\n2. Checking executors...")
    sc = spark.sparkContext
    print(f"   ✓ Application ID: {sc.applicationId}")
    
    # Create test data
    print("\n3. Creating test DataFrame...")
    data = [(i, f"name_{i}", i * 100) for i in range(1, 10001)]
    df = spark.createDataFrame(data, ["id", "name", "value"])
    
    print(f"   ✓ Created DataFrame with {df.count()} rows")
    
    # Perform aggregation
    print("\n4. Running aggregation...")
    result = df.groupBy().sum("value").collect()
    total = result[0][0]
    print(f"   ✓ Sum of values: {total:,}")
    
    # Verify result
    expected = sum(i * 100 for i in range(1, 10001))
    if total == expected:
        print(f"   ✓ Result verified: {total:,} == {expected:,}")
    else:
        print(f"   ❌ Result mismatch: {total:,} != {expected:,}")
        sys.exit(1)
    
    print("\n" + "=" * 80)
    print("✓ K8S NATIVE MODE TEST PASSED")
    print("=" * 80)
    
    spark.stop()
    
except Exception as e:
    print(f"\n❌ TEST FAILED: {str(e)}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

# Copy test script to pod
echo "2. Copying test script to pod..."
cat /tmp/test_k8s_native.py | oc exec -i -n $NAMESPACE $SUBMIT_POD -- sh -c 'cat > /tmp/test_k8s_native.py'

# Run test
echo ""
echo "3. Running Spark K8s Native Mode Test"
echo "------------------------------------------------------------------------"

oc exec -n $NAMESPACE $SUBMIT_POD -- bash -c '
POD_IP=$(hostname -i)
sed "s/_DRIVER_HOST_PLACEHOLDER_/$POD_IP/" /opt/spark/conf/spark-defaults.conf > /tmp/spark-k8s-runtime.conf

/opt/spark/bin/spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode client \
  --name "K8s-Native-Test" \
  --properties-file /tmp/spark-k8s-runtime.conf \
  /tmp/test_k8s_native.py
' 2>&1

EXIT_CODE=$?

echo ""
echo "========================================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ SPARK K8S NATIVE MODE TEST PASSED"
else
    echo "❌ TEST FAILED (exit code: $EXIT_CODE)"
fi
echo "========================================================================"

exit $EXIT_CODE
