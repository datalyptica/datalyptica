#!/bin/bash
# Complete deployment script for Datalyptica platform
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  Datalyptica Complete Deployment Script"
echo "=========================================="
echo ""
echo "This script will deploy the entire Datalyptica platform"
echo "Estimated time: 30-60 minutes"
echo ""

# Verify prerequisites
echo "Checking prerequisites..."
if ! command -v oc &> /dev/null; then
    echo "❌ Error: oc command not found"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into OpenShift cluster"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Confirmation
read -p "Deploy Datalyptica platform now? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "=========================================="
echo "  Phase 1: Foundation"
echo "=========================================="
echo ""

# Create namespaces
echo "Creating namespaces..."
cd "$ROOT_DIR"
oc apply -k namespaces/
echo "✅ Namespaces created"
echo ""

# Generate secrets if they don't exist
if [ ! -d "./openshift-secrets" ]; then
    echo "Generating secrets..."
    ./scripts/01-generate-secrets.sh
fi

# Create secrets
echo "Creating secrets in OpenShift..."
./scripts/02-create-secrets.sh
echo "✅ Secrets created"
echo ""

# Install operators
echo "Installing operators..."
./scripts/03-install-operators.sh
echo "✅ Operators installed"
echo ""

echo "Waiting 30 seconds for operators to stabilize..."
sleep 30

echo ""
echo "=========================================="
echo "  Phase 2: Storage Layer"
echo "=========================================="
echo ""

if [ -d "$ROOT_DIR/storage" ]; then
    echo "Deploying PostgreSQL cluster..."
    oc apply -k storage/postgresql/ || echo "⚠️  PostgreSQL deployment pending (check manually)"
    
    echo "Deploying MinIO tenant..."
    oc apply -k storage/minio/ || echo "⚠️  MinIO deployment pending (check manually)"
    
    echo "Waiting for storage layer (this may take 5-10 minutes)..."
    echo "  - Waiting for PostgreSQL..."
    oc wait --for=condition=Ready cluster/postgresql-ha -n datalyptica-storage --timeout=600s || \
        echo "⚠️  PostgreSQL not ready yet (check: oc get cluster -n datalyptica-storage)"
    
    echo "  - Waiting for MinIO..."
    oc wait --for=condition=Ready tenant/datalyptica-minio -n datalyptica-storage --timeout=600s || \
        echo "⚠️  MinIO not ready yet (check: oc get tenant -n datalyptica-storage)"
    
    echo "✅ Storage layer deployed"
else
    echo "⚠️  Storage manifests not found, skipping"
fi

echo ""
echo "=========================================="
echo "  Phase 3: Control Layer"
echo "=========================================="
echo ""

if [ -d "$ROOT_DIR/control" ]; then
    echo "Deploying Kafka cluster..."
    oc apply -k control/kafka/ || echo "⚠️  Kafka deployment pending"
    
    echo "Waiting for Kafka (this may take 5-10 minutes)..."
    oc wait --for=condition=Ready kafka/datalyptica-kafka -n datalyptica-control --timeout=900s || \
        echo "⚠️  Kafka not ready yet (check: oc get kafka -n datalyptica-control)"
    
    echo "Deploying Schema Registry..."
    oc apply -k control/schema-registry/ || echo "⚠️  Schema Registry deployment pending"
    
    echo "Deploying Kafka Connect..."
    oc apply -k control/kafka-connect/ || echo "⚠️  Kafka Connect deployment pending"
    
    echo "✅ Control layer deployed"
else
    echo "⚠️  Control manifests not found, skipping"
fi

echo ""
echo "=========================================="
echo "  Phase 4: Data Layer"
echo "=========================================="
echo ""

if [ -d "$ROOT_DIR/data" ]; then
    echo "Deploying Nessie catalog..."
    oc apply -k data/nessie/ || echo "⚠️  Nessie deployment pending"
    
    echo "Deploying Trino..."
    oc apply -k data/trino/ || echo "⚠️  Trino deployment pending"
    
    echo "Deploying Spark..."
    oc apply -k data/spark/ || echo "⚠️  Spark deployment pending"
    
    echo "Deploying Flink..."
    oc apply -k data/flink/ || echo "⚠️  Flink deployment pending"
    
    echo "Deploying ClickHouse..."
    oc apply -k data/clickhouse/ || echo "⚠️  ClickHouse deployment pending"
    
    echo "Deploying dbt..."
    oc apply -k data/dbt/ || echo "⚠️  dbt deployment pending"
    
    echo "Waiting for data layer components..."
    sleep 30
    
    echo "✅ Data layer deployed"
else
    echo "⚠️  Data manifests not found, skipping"
fi

echo ""
echo "=========================================="
echo "  Phase 5: Management Layer"
echo "=========================================="
echo ""

if [ -d "$ROOT_DIR/management" ]; then
    echo "Deploying Prometheus..."
    oc apply -k management/prometheus/ || echo "⚠️  Prometheus deployment pending"
    
    echo "Deploying Loki..."
    oc apply -k management/loki/ || echo "⚠️  Loki deployment pending"
    
    echo "Deploying Grafana..."
    oc apply -k management/grafana/ || echo "⚠️  Grafana deployment pending"
    
    echo "Deploying Alertmanager..."
    oc apply -k management/alertmanager/ || echo "⚠️  Alertmanager deployment pending"
    
    echo "Deploying Keycloak..."
    oc apply -k management/keycloak/ || echo "⚠️  Keycloak deployment pending"
    
    echo "✅ Management layer deployed"
else
    echo "⚠️  Management manifests not found, skipping"
fi

echo ""
echo "=========================================="
echo "  Phase 6: Security & Networking"
echo "=========================================="
echo ""

if [ -d "$ROOT_DIR/security" ]; then
    echo "Applying NetworkPolicies..."
    oc apply -k security/network-policies/ || echo "⚠️  NetworkPolicies pending"
    
    echo "Configuring RBAC..."
    oc apply -k security/rbac/ || echo "⚠️  RBAC pending"
    
    echo "✅ Security configured"
else
    echo "⚠️  Security manifests not found, skipping"
fi

if [ -d "$ROOT_DIR/networking" ]; then
    echo "Creating Routes..."
    oc apply -k networking/routes/ || echo "⚠️  Routes pending"
    
    echo "✅ Networking configured"
else
    echo "⚠️  Networking manifests not found, skipping"
fi

echo ""
echo "=========================================="
echo "  Deployment Summary"
echo "=========================================="
echo ""

echo "Checking deployment status..."
echo ""

echo "Namespaces:"
oc get namespaces -l platform=datalyptica
echo ""

echo "Pods by namespace:"
for ns in datalyptica-storage datalyptica-control datalyptica-data datalyptica-management; do
    echo ""
    echo "=== $ns ==="
    oc get pods -n $ns 2>/dev/null || echo "No pods yet"
done
echo ""

echo "Services:"
for ns in datalyptica-storage datalyptica-control datalyptica-data datalyptica-management; do
    echo ""
    echo "=== $ns ==="
    oc get svc -n $ns 2>/dev/null || echo "No services yet"
done
echo ""

echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""
echo "⏱️  Deployment started: $(date)"
echo ""
echo "📋 Next steps:"
echo "  1. Wait for all pods to be Running (may take 10-20 minutes)"
echo "     Watch: oc get pods -n datalyptica-data -w"
echo ""
echo "  2. Run validation: ./scripts/validate-deployment.sh"
echo ""
echo "  3. Access services via Routes:"
echo "     oc get routes -n datalyptica-management"
echo ""
echo "  4. Get credentials:"
echo "     cat ./openshift-secrets/grafana_admin_password"
echo ""
echo "🔗 Useful commands:"
echo "   # Check all pods"
echo "   oc get pods --all-namespaces -l platform=datalyptica"
echo ""
echo "   # Check operators"
echo "   oc get csv -n datalyptica-operators"
echo ""
echo "   # View logs"
echo "   oc logs -f deployment/nessie -n datalyptica-data"
echo ""
echo "📖 Documentation: ../docs/OPENSHIFT_DEPLOYMENT_GUIDE.md"
echo ""

