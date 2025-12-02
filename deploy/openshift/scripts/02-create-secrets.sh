#!/bin/bash
# Create Kubernetes secrets from generated files
set -e

SECRETS_DIR="./openshift-secrets"

echo "=========================================="
echo "  Datalyptica Secrets Creation Script"
echo "=========================================="
echo ""

# Check if secrets directory exists
if [ ! -d "$SECRETS_DIR" ]; then
    echo "Error: Secrets directory not found: $SECRETS_DIR"
    echo "Please run ./scripts/01-generate-secrets.sh first"
    exit 1
fi

# Verify oc is available
if ! command -v oc &> /dev/null; then
    echo "Error: oc command not found. Please install OpenShift CLI."
    exit 1
fi

# Verify cluster connection
if ! oc whoami &> /dev/null; then
    echo "Error: Not logged into OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

echo "Creating secrets in OpenShift cluster..."
echo ""

# Function to create secret
create_secret() {
    local namespace=$1
    local secret_name=$2
    shift 2
    
    echo "  Creating $secret_name in $namespace..."
    
    # Delete if exists
    oc delete secret $secret_name -n $namespace 2>/dev/null || true
    
    # Create secret with all provided key=file pairs
    oc create secret generic $secret_name -n $namespace "$@"
    oc delete secret $secret_name -n $namespace 2>/dev/null || true
    
    # Create secret
    eval $cmd
}

# Storage namespace
echo "Storage namespace (datalyptica-storage):"
create_secret datalyptica-storage postgresql-credentials \
    postgres_password \
    postgres_replication_password \
    datalyptica_password

create_secret datalyptica-storage minio-credentials \
    minio_root_user \
    minio_root_password \
    minio_access_key \
    minio_secret_key

# Control namespace
echo ""
echo "Control namespace (datalyptica-control):"
create_secret datalyptica-control kafka-credentials \
    kafka_admin_password \
    schema_registry_password

# Data namespace
echo ""
echo "Data namespace (datalyptica-data):"
create_secret datalyptica-data nessie-credentials \
    nessie_password

create_secret datalyptica-data minio-credentials \
    minio_root_user \
    minio_root_password \
    minio_access_key \
    minio_secret_key

create_secret datalyptica-data postgresql-credentials \
    postgres_password \
    datalyptica_password

create_secret datalyptica-data clickhouse-credentials \
    clickhouse_user \
    clickhouse_password

# Management namespace
echo ""
echo "Management namespace (datalyptica-management):"
create_secret datalyptica-management keycloak-credentials \
    keycloak_admin_user \
    keycloak_admin_password \
    keycloak_db_password

create_secret datalyptica-management grafana-credentials \
    grafana_admin_user \
    grafana_admin_password

create_secret datalyptica-management postgresql-credentials \
    postgres_password \
    keycloak_db_password

# Optional: Analytics services (if deploying)
if [ -f "$SECRETS_DIR/jupyterhub_password" ]; then
    echo ""
    echo "Analytics services (datalyptica-management):"
    
    create_secret datalyptica-management jupyterhub-credentials \
        jupyterhub_password \
        jupyterhub_proxy_token
    
    create_secret datalyptica-management mlflow-credentials \
        mlflow_password
    
    create_secret datalyptica-management superset-credentials \
        superset_admin_user \
        superset_admin_password \
        superset_secret_key
    
    create_secret datalyptica-management airflow-credentials \
        airflow_admin_user \
        airflow_admin_password \
        airflow_fernet_key \
        airflow_secret_key
fi

echo ""
echo "=========================================="
echo "  All secrets created successfully!"
echo "=========================================="
echo ""

# Verify secrets
echo "Verifying secrets:"
echo ""
echo "Storage namespace:"
oc get secrets -n datalyptica-storage | grep -E "NAME|credentials"
echo ""
echo "Control namespace:"
oc get secrets -n datalyptica-control | grep -E "NAME|credentials"
echo ""
echo "Data namespace:"
oc get secrets -n datalyptica-data | grep -E "NAME|credentials"
echo ""
echo "Management namespace:"
oc get secrets -n datalyptica-management | grep -E "NAME|credentials"
echo ""

echo "✅ Secrets creation complete!"
echo ""
echo "Next step: Install operators with ./scripts/03-install-operators.sh"

