#!/usr/bin/env bash
set -euo pipefail

#######################################
# Helm Chart Validation Script
# Validates the Datalyptica Helm chart
#######################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHART_PATH="./deploy/helm/datalyptica"
ERRORS=0

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; ERRORS=$((ERRORS + 1)); }

echo "========================================"
echo "  Helm Chart Validation"
echo "========================================"
echo ""

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Install from: https://helm.sh/docs/intro/install/"
    exit 1
fi

print_info "Helm version:"
helm version --short
echo ""

# Lint the chart
print_info "Running helm lint..."
if helm lint "$CHART_PATH"; then
    print_success "Helm lint passed"
else
    print_error "Helm lint failed"
fi
echo ""

# Template the chart
print_info "Rendering templates (dry-run)..."
if helm template datalyptica "$CHART_PATH" > /dev/null; then
    print_success "Template rendering passed"
else
    print_error "Template rendering failed"
fi
echo ""

# Check chart structure
print_info "Checking chart structure..."

required_files=(
    "Chart.yaml"
    "values.yaml"
    "templates/_helpers.tpl"
    "templates/NOTES.txt"
)

for file in "${required_files[@]}"; do
    if [[ -f "$CHART_PATH/$file" ]]; then
        print_success "Found $file"
    else
        print_error "Missing $file"
    fi
done
echo ""

# Check required templates
print_info "Checking service templates..."

required_templates=(
    "templates/namespaces.yaml"
    "templates/serviceaccount.yaml"
    "templates/secrets.yaml"
    "templates/core/postgresql.yaml"
    "templates/core/redis.yaml"
    "templates/core/minio.yaml"
    "templates/core/nessie.yaml"
    "templates/apps/trino.yaml"
    "templates/apps/flink.yaml"
    "templates/apps/kafka.yaml"
    "templates/apps/spark.yaml"
    "templates/apps/clickhouse.yaml"
    "templates/apps/airflow.yaml"
    "templates/apps/superset.yaml"
)

for template in "${required_templates[@]}"; do
    if [[ -f "$CHART_PATH/$template" ]]; then
        print_success "Found $template"
    else
        print_error "Missing $template"
    fi
done
echo ""

# Validate values.yaml
print_info "Validating values.yaml..."
if yq eval '.' "$CHART_PATH/values.yaml" > /dev/null 2>&1; then
    print_success "values.yaml is valid YAML"
else
    print_error "values.yaml has syntax errors"
fi
echo ""

# Check for required values
print_info "Checking required values..."

required_values=(
    "global.imageRegistry"
    "global.imagePullPolicy"
    "global.storageClass"
    "namespaces.core"
    "namespaces.apps"
    "postgresql.enabled"
    "redis.enabled"
    "minio.enabled"
    "nessie.enabled"
)

for value in "${required_values[@]}"; do
    if yq eval ".$value" "$CHART_PATH/values.yaml" > /dev/null 2>&1; then
        print_success "Found value: $value"
    else
        print_error "Missing value: $value"
    fi
done
echo ""

# Test with different configurations
print_info "Testing minimal configuration..."
cat > /tmp/minimal-values.yaml <<EOF
trino:
  enabled: false
flink:
  enabled: false
kafka:
  enabled: false
spark:
  enabled: false
clickhouse:
  enabled: false
airflow:
  enabled: false
superset:
  enabled: false
prometheus:
  enabled: false
grafana:
  enabled: false
EOF

if helm template datalyptica "$CHART_PATH" -f /tmp/minimal-values.yaml > /dev/null; then
    print_success "Minimal configuration passed"
else
    print_error "Minimal configuration failed"
fi
rm /tmp/minimal-values.yaml
echo ""

# Summary
echo "========================================"
if [[ $ERRORS -eq 0 ]]; then
    print_success "All validations passed! ✨"
    echo ""
    echo "Next steps:"
    echo "  1. Package the chart: helm package $CHART_PATH"
    echo "  2. Install locally: helm install datalyptica $CHART_PATH"
    echo "  3. Or use deployment script: ./scripts/deploy_local_k8s.sh"
else
    print_error "Validation failed with $ERRORS error(s)"
    exit 1
fi
echo "========================================"
