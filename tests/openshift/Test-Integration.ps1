#
# Simplified Integration Test Runner (PowerShell)
# Executes: Spark → Trino workflow
#

$ErrorActionPreference = "Continue"
$NAMESPACE = "datalyptica"

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  Datalyptica OpenShift Integration Test Suite" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# Function to get first running pod
function Get-FirstPod {
    param([string]$Label)
    $pod = oc get pods -n $NAMESPACE -l $Label --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>$null
    return $pod
}

# Health check
Write-Host "1. Health Check" -ForegroundColor Yellow
Write-Host "----------------"
Write-Host "Checking all components..."

$MINIO_COUNT = (oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=minio' --field-selector=status.phase=Running --no-headers 2>$null | Measure-Object -Line).Lines
$NESSIE_COUNT = (oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=nessie' --field-selector=status.phase=Running --no-headers 2>$null | Measure-Object -Line).Lines
$SPARK_COUNT = (oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=spark' --field-selector=status.phase=Running --no-headers 2>$null | Measure-Object -Line).Lines
$TRINO_COUNT = (oc get pods -n $NAMESPACE -l 'app.kubernetes.io/name=trino' --field-selector=status.phase=Running --no-headers 2>$null | Measure-Object -Line).Lines

Write-Host "  MinIO: $MINIO_COUNT pods" -ForegroundColor Green
Write-Host "  Nessie: $NESSIE_COUNT pods" -ForegroundColor Green
Write-Host "  Spark: $SPARK_COUNT pods" -ForegroundColor Green
Write-Host "  Trino: $TRINO_COUNT pods" -ForegroundColor Green

if ($MINIO_COUNT -eq 0 -or $NESSIE_COUNT -eq 0 -or $SPARK_COUNT -eq 0 -or $TRINO_COUNT -eq 0) {
    Write-Host ""
    Write-Host "ERROR: Not all components are running!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "2. Spark Batch Processing Test" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "Writing sales data to Iceberg table via Nessie catalog..."
Write-Host ""

$SPARK_POD = Get-FirstPod "app.kubernetes.io/component=master"
if ([string]::IsNullOrEmpty($SPARK_POD)) {
    Write-Host "ERROR: Could not find Spark master pod" -ForegroundColor Red
    exit 1
}

Write-Host "Using Spark pod: $SPARK_POD" -ForegroundColor Cyan
Write-Host ""

# Copy test script to pod using stdin
Write-Host "Copying test script to Spark pod..."
Get-Content tests\openshift\spark\test_iceberg_write.py | oc exec -i -n $NAMESPACE $SPARK_POD -- sh -c 'cat > /tmp/test_iceberg_write.py'

# Execute Spark test
Write-Host "Executing Spark job - this may take a few minutes..."
Write-Host ""
oc exec -n $NAMESPACE $SPARK_POD -- sh -c '/opt/spark/bin/spark-submit --master spark://spark-svc.datalyptica.svc.cluster.local:7077 --deploy-mode client --jars /opt/spark/jars/iceberg/iceberg-spark-runtime-3.5_2.12-1.10.0.jar,/opt/spark/jars/iceberg/iceberg-nessie-1.10.0.jar,/opt/spark/jars/iceberg/aws-java-sdk-bundle-1.12.772.jar,/opt/spark/jars/iceberg/hadoop-aws-3.4.1.jar /tmp/test_iceberg_write.py'

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Spark test FAILED" -ForegroundColor Red
    Write-Host "Check Spark UI for details: https://spark-master-datalyptica.apps.virocp-poc.efinance.com.eg" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Spark test completed successfully!" -ForegroundColor Green
Write-Host ""

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "3. Trino Query Test" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "Querying Iceberg tables via Trino..."
Write-Host ""

$TRINO_POD = Get-FirstPod "app.kubernetes.io/component=coordinator"
if ([string]::IsNullOrEmpty($TRINO_POD)) {
    Write-Host "ERROR: Could not find Trino coordinator pod" -ForegroundColor Red
    exit 1
}

Write-Host "Using Trino pod: $TRINO_POD" -ForegroundColor Cyan
Write-Host ""

# Install trino-python-client in Trino pod if not present
Write-Host "Installing Python dependencies in Trino pod..."
oc exec -n $NAMESPACE $TRINO_POD -- sh -c 'pip3 install --quiet trino 2>/dev/null || pip install --quiet trino 2>/dev/null || true' 2>$null

# Copy test script to pod
Write-Host "Copying test script to Trino pod..."
Get-Content tests\openshift\trino\test_query_iceberg.py | oc exec -i -n $NAMESPACE $TRINO_POD -- sh -c 'cat > /tmp/test_query_iceberg.py'

# Execute Trino test
Write-Host "Executing Trino queries..."
Write-Host ""
oc exec -n $NAMESPACE $TRINO_POD -- python3 /tmp/test_query_iceberg.py

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Trino test FAILED" -ForegroundColor Red
    Write-Host "Check Trino UI for details: https://trino-datalyptica.apps.virocp-poc.efinance.com.eg" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Trino test completed successfully!" -ForegroundColor Green
Write-Host ""

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "INTEGRATION TEST SUITE COMPLETED" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:"
Write-Host "  [OK] Spark wrote 1000 transactions to Iceberg table" -ForegroundColor Green
Write-Host "  [OK] Trino queried Iceberg tables successfully" -ForegroundColor Green
Write-Host "  [SKIP] Flink test - requires Python in Flink image" -ForegroundColor Yellow
Write-Host ""
Write-Host "Data Pipeline Flow:"
Write-Host "  Spark -> Nessie Catalog -> Iceberg Format -> MinIO Storage -> Trino Query"
Write-Host ""
Write-Host "Access Points:"
Write-Host "  Spark UI: https://spark-master-datalyptica.apps.virocp-poc.efinance.com.eg"
Write-Host "  Trino UI: https://trino-datalyptica.apps.virocp-poc.efinance.com.eg"
Write-Host "  MinIO Console: https://minio-console-datalyptica.apps.virocp-poc.efinance.com.eg"
Write-Host "  Nessie API: https://nessie-datalyptica.apps.virocp-poc.efinance.com.eg"
Write-Host ""
