#!/bin/bash
# Convert multi-namespace deployment to single namespace
# This script helps migrate from multiple namespaces to a single namespace
set -e

echo "=========================================="
echo "  Convert to Single Namespace"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will modify your deployment manifests!"
echo ""
echo "This script will:"
echo "  1. Create single namespace configuration"
echo "  2. Update all manifests to use 'datalyptica' namespace"
echo "  3. Simplify service references (remove FQDN)"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "Step 1: Creating single namespace configuration..."
cp "$ROOT_DIR/namespaces/namespaces-single.yaml" "$ROOT_DIR/namespaces/namespaces.yaml.backup"
# The single namespace file is already created

echo "Step 2: Finding all YAML files to update..."
find "$ROOT_DIR" -name "*.yaml" -o -name "*.yml" | while read file; do
    if grep -q "namespace: datalyptica-" "$file" 2>/dev/null; then
        echo "  Updating: $file"
        # Replace all namespace references
        sed -i.bak \
            -e 's/namespace: datalyptica-storage/namespace: datalyptica/g' \
            -e 's/namespace: datalyptica-control/namespace: datalyptica/g' \
            -e 's/namespace: datalyptica-data/namespace: datalyptica/g' \
            -e 's/namespace: datalyptica-management/namespace: datalyptica/g' \
            -e 's/namespace: datalyptica-operators/namespace: datalyptica/g' \
            "$file"
        rm -f "$file.bak"
    fi
done

echo "Step 3: Simplifying service references..."
find "$ROOT_DIR" -name "*.yaml" -o -name "*.yml" | while read file; do
    if grep -q "\.datalyptica-.*\.svc\.cluster\.local" "$file" 2>/dev/null; then
        echo "  Simplifying services in: $file"
        # Remove namespace suffixes from service references
        sed -i.bak \
            -e 's/\.datalyptica-storage\.svc\.cluster\.local//g' \
            -e 's/\.datalyptica-control\.svc\.cluster\.local//g' \
            -e 's/\.datalyptica-data\.svc\.cluster\.local//g' \
            -e 's/\.datalyptica-management\.svc\.cluster\.local//g' \
            "$file"
        rm -f "$file.bak"
    fi
done

echo ""
echo "=========================================="
echo "  Conversion Complete!"
echo "=========================================="
echo ""
echo "✅ All manifests updated to use single namespace: datalyptica"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Apply single namespace: oc apply -f namespaces/namespaces-single.yaml"
echo "  3. Redeploy: ./scripts/deploy-all.sh"
echo ""
echo "Note: Backup of original namespaces.yaml saved as namespaces.yaml.backup"

