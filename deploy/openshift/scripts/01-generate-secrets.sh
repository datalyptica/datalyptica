#!/bin/bash
# Generate secrets for Datalyptica platform
set -e

SECRETS_DIR="./openshift-secrets"
mkdir -p $SECRETS_DIR

echo "=========================================="
echo "  Datalyptica Secret Generation Script"
echo "=========================================="
echo ""

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate hex key
generate_hex() {
    openssl rand -hex ${1:-20}
}

echo "Generating secrets..."
echo ""

# PostgreSQL
echo "  - PostgreSQL credentials"
echo -n "$(generate_password)" > $SECRETS_DIR/postgres_password
echo -n "$(generate_password)" > $SECRETS_DIR/postgres_replication_password
echo -n "datalyptica" > $SECRETS_DIR/postgres_user
echo -n "$(generate_password)" > $SECRETS_DIR/datalyptica_password
echo -n "$(generate_password)" > $SECRETS_DIR/nessie_password

# MinIO
echo "  - MinIO credentials"
echo -n "minioadmin" > $SECRETS_DIR/minio_root_user
echo -n "$(generate_password)" > $SECRETS_DIR/minio_root_password
echo -n "$(generate_hex 20)" > $SECRETS_DIR/minio_access_key
echo -n "$(openssl rand -base64 40 | tr -d "=+/")" > $SECRETS_DIR/minio_secret_key

# Kafka
echo "  - Kafka credentials"
echo -n "$(generate_password)" > $SECRETS_DIR/kafka_admin_password
echo -n "$(generate_password)" > $SECRETS_DIR/schema_registry_password

# Keycloak
echo "  - Keycloak credentials"
echo -n "admin" > $SECRETS_DIR/keycloak_admin_user
echo -n "$(generate_password)" > $SECRETS_DIR/keycloak_admin_password
echo -n "$(generate_password)" > $SECRETS_DIR/keycloak_db_password

# Monitoring
echo "  - Monitoring credentials"
echo -n "admin" > $SECRETS_DIR/grafana_admin_user
echo -n "$(generate_password)" > $SECRETS_DIR/grafana_admin_password

# ClickHouse
echo "  - ClickHouse credentials"
echo -n "default" > $SECRETS_DIR/clickhouse_user
echo -n "$(generate_password)" > $SECRETS_DIR/clickhouse_password

# JupyterHub
echo "  - JupyterHub credentials"
echo -n "$(generate_password)" > $SECRETS_DIR/jupyterhub_password
echo -n "$(generate_hex 32)" > $SECRETS_DIR/jupyterhub_proxy_token

# MLflow
echo "  - MLflow credentials"
echo -n "$(generate_password)" > $SECRETS_DIR/mlflow_password

# Superset
echo "  - Superset credentials"
echo -n "admin" > $SECRETS_DIR/superset_admin_user
echo -n "$(generate_password)" > $SECRETS_DIR/superset_admin_password
echo -n "$(generate_hex 32)" > $SECRETS_DIR/superset_secret_key

# Airflow
echo "  - Airflow credentials"
echo -n "admin" > $SECRETS_DIR/airflow_admin_user
echo -n "$(generate_password)" > $SECRETS_DIR/airflow_admin_password
echo -n "$(openssl rand -base64 32)" > $SECRETS_DIR/airflow_fernet_key
echo -n "$(generate_hex 32)" > $SECRETS_DIR/airflow_secret_key

echo ""
echo "=========================================="
echo "  Secrets generated successfully!"
echo "=========================================="
echo ""
echo "Location: $SECRETS_DIR/"
echo ""
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "   1. Store these secrets in a secure vault (e.g., HashiCorp Vault)"
echo "   2. Add $SECRETS_DIR/ to .gitignore"
echo "   3. Backup secrets to a secure location"
echo "   4. Rotate secrets regularly"
echo ""
echo "Generated files:"
ls -1 $SECRETS_DIR/ | sed 's/^/   - /'
echo ""

# Create .gitignore
if [ ! -f "$SECRETS_DIR/.gitignore" ]; then
    echo "*" > $SECRETS_DIR/.gitignore
    echo "!.gitignore" >> $SECRETS_DIR/.gitignore
    echo ""
    echo "Created .gitignore in secrets directory"
fi

echo "Next step: Run ./scripts/02-create-secrets.sh to create Kubernetes secrets"

