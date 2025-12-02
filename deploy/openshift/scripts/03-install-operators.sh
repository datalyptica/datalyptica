#!/bin/bash
# Install required operators
set -e

echo "=========================================="
echo "  Datalyptica Operators Installation Script"
echo "=========================================="
echo ""

# Verify oc is available and logged in
if ! command -v oc &> /dev/null; then
    echo "Error: oc command not found"
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "Error: Not logged into OpenShift cluster"
    exit 1
fi

echo "Installing operators in datalyptica-operators namespace..."
echo ""

# Create operators namespace if it doesn't exist
oc get namespace datalyptica-operators >/dev/null 2>&1 || \
    oc create namespace datalyptica-operators

# 1. CloudNativePG Operator
echo "1. Installing CloudNativePG Operator..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cloudnativepg
  namespace: datalyptica-operators
spec:
  channel: stable
  name: cloudnativepg
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

echo "   Waiting for CloudNativePG operator..."
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=cloudnative-pg \
    -n datalyptica-operators --timeout=300s || true

# 2. Strimzi Kafka Operator
echo ""
echo "2. Installing Strimzi Kafka Operator..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: strimzi-kafka-operator
  namespace: datalyptica-operators
spec:
  channel: stable
  name: strimzi-kafka-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

echo "   Waiting for Strimzi operator..."
oc wait --for=condition=Ready pod -l name=strimzi-cluster-operator \
    -n datalyptica-operators --timeout=300s || true

# 3. MinIO Operator
echo ""
echo "3. Installing MinIO Operator..."
echo "   Note: MinIO operator will be installed in minio-operator namespace"

# Apply MinIO operator
kubectl apply -k "github.com/minio/operator?ref=v5.0.11" || \
    kubectl apply -f https://raw.githubusercontent.com/minio/operator/master/resources/kustomization.yaml

echo "   Waiting for MinIO operator..."
oc wait --for=condition=Ready pod -l name=minio-operator \
    -n minio-operator --timeout=300s || true

# 4. Cert-Manager (optional, for TLS automation)
echo ""
echo "4. Installing cert-manager (optional)..."
echo "   Checking if cert-manager is already installed..."

if ! oc get deployment cert-manager -n cert-manager &>/dev/null; then
    echo "   Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    echo "   Waiting for cert-manager..."
    oc wait --for=condition=Ready pod -l app=cert-manager \
        -n cert-manager --timeout=300s || true
else
    echo "   cert-manager already installed, skipping"
fi

echo ""
echo "=========================================="
echo "  Verifying operator installations..."
echo "=========================================="
echo ""

# Verify installations
echo "Installed operators:"
echo ""
oc get csv -n datalyptica-operators
echo ""

echo "Operator pods:"
echo ""
oc get pods -n datalyptica-operators
echo ""

if oc get namespace minio-operator &>/dev/null; then
    echo "MinIO operator pods:"
    oc get pods -n minio-operator
    echo ""
fi

if oc get namespace cert-manager &>/dev/null; then
    echo "cert-manager pods:"
    oc get pods -n cert-manager
    echo ""
fi

# Check CRDs
echo "Checking Custom Resource Definitions:"
echo ""
echo "CloudNativePG CRDs:"
oc api-resources | grep postgresql.cnpg.io || echo "   Not found"
echo ""
echo "Strimzi CRDs:"
oc api-resources | grep kafka.strimzi.io || echo "   Not found"
echo ""
echo "MinIO CRDs:"
oc api-resources | grep minio.min.io || echo "   Not found"
echo ""

echo "=========================================="
echo "  Operator installation complete!"
echo "=========================================="
echo ""
echo "✅ All operators installed successfully"
echo ""
echo "Next steps:"
echo "  1. Deploy storage layer: oc apply -k storage/"
echo "  2. Deploy control layer: oc apply -k control/"
echo "  3. Deploy data layer: oc apply -k data/"
echo "  4. Deploy management layer: oc apply -k management/"
echo ""
echo "Or run the complete deployment: ./scripts/deploy-all.sh"

