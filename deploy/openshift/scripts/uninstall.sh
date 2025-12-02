#!/bin/bash
# Uninstall Datalyptica platform
set -e

echo "=========================================="
echo "  Datalyptica Platform Uninstall Script"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will delete ALL Datalyptica resources!"
echo ""
echo "This includes:"
echo "  - All data in PostgreSQL"
echo "  - All data in MinIO"
echo "  - All Kafka topics and data"
echo "  - All configurations"
echo "  - All persistent volumes"
echo ""

read -p "Are you sure you want to uninstall? (type 'DELETE' to confirm): " confirm
if [ "$confirm" != "DELETE" ]; then
    echo "Uninstall cancelled"
    exit 0
fi

echo ""
echo "Starting uninstall..."
echo ""

# Delete in reverse order of deployment

echo "1. Deleting routes and networking..."
oc delete routes --all -n datalyptica-management 2>/dev/null || true
oc delete routes --all -n datalyptica-data 2>/dev/null || true
oc delete routes --all -n datalyptica-control 2>/dev/null || true
oc delete routes --all -n datalyptica-storage 2>/dev/null || true

echo "2. Deleting management layer..."
oc delete all --all -n datalyptica-management 2>/dev/null || true
oc delete pvc --all -n datalyptica-management 2>/dev/null || true
oc delete configmaps --all -n datalyptica-management 2>/dev/null || true

echo "3. Deleting data layer..."
oc delete all --all -n datalyptica-data 2>/dev/null || true
oc delete pvc --all -n datalyptica-data 2>/dev/null || true
oc delete configmaps --all -n datalyptica-data 2>/dev/null || true

echo "4. Deleting control layer..."
oc delete kafka --all -n datalyptica-control 2>/dev/null || true
oc delete kafkaconnect --all -n datalyptica-control 2>/dev/null || true
oc delete kafkatopic --all -n datalyptica-control 2>/dev/null || true
oc delete all --all -n datalyptica-control 2>/dev/null || true
oc delete pvc --all -n datalyptica-control 2>/dev/null || true
oc delete configmaps --all -n datalyptica-control 2>/dev/null || true

echo "5. Deleting storage layer..."
oc delete tenant --all -n datalyptica-storage 2>/dev/null || true
oc delete cluster --all -n datalyptica-storage 2>/dev/null || true
oc delete all --all -n datalyptica-storage 2>/dev/null || true
oc delete pvc --all -n datalyptica-storage 2>/dev/null || true
oc delete configmaps --all -n datalyptica-storage 2>/dev/null || true

echo "6. Deleting secrets..."
oc delete secrets --all -n datalyptica-management 2>/dev/null || true
oc delete secrets --all -n datalyptica-data 2>/dev/null || true
oc delete secrets --all -n datalyptica-control 2>/dev/null || true
oc delete secrets --all -n datalyptica-storage 2>/dev/null || true

echo "7. Deleting namespaces..."
oc delete namespace datalyptica-management 2>/dev/null || true
oc delete namespace datalyptica-data 2>/dev/null || true
oc delete namespace datalyptica-control 2>/dev/null || true
oc delete namespace datalyptica-storage 2>/dev/null || true

# Optionally delete operators
read -p "Delete operators too? (yes/no): " delete_operators
if [ "$delete_operators" == "yes" ]; then
    echo "8. Deleting operators..."
    oc delete subscription --all -n datalyptica-operators 2>/dev/null || true
    oc delete csv --all -n datalyptica-operators 2>/dev/null || true
    oc delete namespace datalyptica-operators 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  Uninstall Complete"
echo "=========================================="
echo ""
echo "✅ All Datalyptica resources have been deleted"
echo ""
echo "Note: Some resources may take a few minutes to fully terminate"
echo ""
echo "To verify deletion:"
echo "  oc get namespaces -l platform=datalyptica"
echo ""

