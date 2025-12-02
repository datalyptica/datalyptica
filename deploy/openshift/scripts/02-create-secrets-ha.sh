#!/bin/bash
# Create Kubernetes secrets from generated files for HA deployment
set -e

SECRETS_DIR="./openshift-secrets"

echo "=========================================="
echo "  Datalyptica HA Secrets Creation"
echo "=========================================="
echo ""

# Check if secrets directory exists
if [ ! -d "$SECRETS_DIR" ]; then
    echo "❌ Error: Secrets directory not found: $SECRETS_DIR"
    echo "   Please run ./scripts/01-generate-secrets.sh first"
    exit 1
fi

# Verify oc is available
if ! command -v oc &> /dev/null; then
    echo "❌ Error: oc command not found. Please install OpenShift CLI."
    exit 1
fi

# Verify cluster connection
if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into OpenShift cluster."
    echo "   Please run 'oc login' first."
    exit 1
fi

echo "Connected to cluster: $(oc whoami --show-server)"
echo "Current user: $(oc whoami)"
echo ""
echo "Creating secrets in OpenShift cluster..."
echo ""

# Function to create secret
create_secret() {
    local namespace=$1
    local secret_name=$2
    shift 2
    
    echo "  → Creating $secret_name in $namespace..."
    
    # Delete if exists
    oc delete secret $secret_name -n $namespace 2>/dev/null || true
    
    # Create secret with all provided key=file pairs
    oc create secret generic $secret_name -n $namespace "$@" \
        && echo "    ✓ Created" \
        || echo "    ✗ Failed"
}

# ==================================================
# Storage Layer Secrets
# ==================================================
echo "📦 Storage Layer (datalyptica-storage):"
echo ""

create_secret datalyptica-storage postgresql-credentials \
    --from-file=username=$SECRETS_DIR/postgres_user \
    --from-file=password=$SECRETS_DIR/datalyptica_password \
    --from-file=postgres_password=$SECRETS_DIR/postgres_password \
    --from-file=replication_password=$SECRETS_DIR/postgres_replication_password

create_secret datalyptica-storage minio-credentials \
    --from-file=root_user=$SECRETS_DIR/minio_root_user \
    --from-file=root_password=$SECRETS_DIR/minio_root_password \
    --from-file=access_key=$SECRETS_DIR/minio_access_key \
    --from-file=secret_key=$SECRETS_DIR/minio_secret_key \
    --from-file=datalyptica_password=$SECRETS_DIR/datalyptica_password

# ==================================================
# Control Layer Secrets
# ==================================================
echo ""
echo "🎛️  Control Layer (datalyptica-control):"
echo ""

create_secret datalyptica-control kafka-credentials \
    --from-file=admin_password=$SECRETS_DIR/kafka_admin_password

create_secret datalyptica-control schema-registry-credentials \
    --from-file=password=$SECRETS_DIR/schema_registry_password

# ==================================================
# Data Layer Secrets
# ==================================================
echo ""
echo "💾 Data Layer (datalyptica-data):"
echo ""

create_secret datalyptica-data postgresql-credentials \
    --from-file=username=$SECRETS_DIR/postgres_user \
    --from-file=password=$SECRETS_DIR/datalyptica_password \
    --from-file=postgres_password=$SECRETS_DIR/postgres_password

create_secret datalyptica-data nessie-credentials \
    --from-file=password=$SECRETS_DIR/nessie_password

create_secret datalyptica-data minio-credentials \
    --from-file=root_user=$SECRETS_DIR/minio_root_user \
    --from-file=root_password=$SECRETS_DIR/minio_root_password \
    --from-file=access_key=$SECRETS_DIR/minio_access_key \
    --from-file=secret_key=$SECRETS_DIR/minio_secret_key

create_secret datalyptica-data clickhouse-credentials \
    --from-file=user=$SECRETS_DIR/clickhouse_user \
    --from-file=password=$SECRETS_DIR/clickhouse_password

# ==================================================
# Management Layer Secrets
# ==================================================
echo ""
echo "📊 Management Layer (datalyptica-management):"
echo ""

create_secret datalyptica-management keycloak-credentials \
    --from-file=admin_user=$SECRETS_DIR/keycloak_admin_user \
    --from-file=admin_password=$SECRETS_DIR/keycloak_admin_password \
    --from-file=db_password=$SECRETS_DIR/keycloak_db_password

create_secret datalyptica-management grafana-credentials \
    --from-file=admin_user=$SECRETS_DIR/grafana_admin_user \
    --from-file=admin_password=$SECRETS_DIR/grafana_admin_password

create_secret datalyptica-management postgresql-credentials \
    --from-file=username=$SECRETS_DIR/postgres_user \
    --from-file=password=$SECRETS_DIR/postgres_password \
    --from-file=keycloak_password=$SECRETS_DIR/keycloak_db_password

# ==================================================
# Optional Analytics Services
# ==================================================
if [ -f "$SECRETS_DIR/jupyterhub_password" ]; then
    echo ""
    echo "🔬 Analytics Services (datalyptica-management):"
    echo ""
    
    create_secret datalyptica-management jupyterhub-credentials \
        --from-file=password=$SECRETS_DIR/jupyterhub_password \
        --from-file=proxy_token=$SECRETS_DIR/jupyterhub_proxy_token
    
    create_secret datalyptica-management mlflow-credentials \
        --from-file=password=$SECRETS_DIR/mlflow_password
    
    create_secret datalyptica-management superset-credentials \
        --from-file=admin_user=$SECRETS_DIR/superset_admin_user \
        --from-file=admin_password=$SECRETS_DIR/superset_admin_password \
        --from-file=secret_key=$SECRETS_DIR/superset_secret_key
    
    create_secret datalyptica-management airflow-credentials \
        --from-file=admin_user=$SECRETS_DIR/airflow_admin_user \
        --from-file=admin_password=$SECRETS_DIR/airflow_admin_password \
        --from-file=fernet_key=$SECRETS_DIR/airflow_fernet_key \
        --from-file=secret_key=$SECRETS_DIR/airflow_secret_key
fi

# ==================================================
# Verification
# ==================================================
echo ""
echo "=========================================="
echo "  Verifying Created Secrets"
echo "=========================================="
echo ""

echo "📦 Storage namespace:"
oc get secrets -n datalyptica-storage | grep -E "NAME|credentials" || echo "  No secrets found"
echo ""

echo "🎛️  Control namespace:"
oc get secrets -n datalyptica-control | grep -E "NAME|credentials" || echo "  No secrets found"
echo ""

echo "💾 Data namespace:"
oc get secrets -n datalyptica-data | grep -E "NAME|credentials" || echo "  No secrets found"
echo ""

echo "📊 Management namespace:"
oc get secrets -n datalyptica-management | grep -E "NAME|credentials" || echo "  No secrets found"
echo ""

echo "=========================================="
echo "  ✅ Secrets Creation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Deploy storage layer: oc apply -k storage/postgresql/"
echo "  2. Deploy storage layer: oc apply -k storage/minio/"
echo "  3. Deploy control layer: oc apply -k control/kafka/"
echo "  4. Or use: ./scripts/deploy-all.sh"
echo ""
