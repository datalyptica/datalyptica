#!/bin/bash
# Generate secure secret keys for Analytics & ML services

set -e

echo "=========================================="
echo "Generating Secure Keys for Analytics & ML Services"
echo "=========================================="

# Generate Superset secret key
SUPERSET_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "SUPERSET_SECRET_KEY=${SUPERSET_SECRET}"

# Generate Airflow secret key  
AIRFLOW_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "AIRFLOW_SECRET_KEY=${AIRFLOW_SECRET}"

# Generate Airflow Fernet key
AIRFLOW_FERNET=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
echo "AIRFLOW_FERNET_KEY=${AIRFLOW_FERNET}"

# Generate JupyterHub proxy token
JUPYTERHUB_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
echo "JUPYTERHUB_PROXY_AUTH_TOKEN=${JUPYTERHUB_TOKEN}"

echo ""
echo "=========================================="
echo "✅ Keys Generated Successfully!"
echo "=========================================="
echo ""
echo "Add these to your docker/.env file:"
echo ""
echo "SUPERSET_SECRET_KEY=${SUPERSET_SECRET}"
echo "AIRFLOW_SECRET_KEY=${AIRFLOW_SECRET}"
echo "AIRFLOW_FERNET_KEY=${AIRFLOW_FERNET}"
echo "JUPYTERHUB_PROXY_AUTH_TOKEN=${JUPYTERHUB_TOKEN}"
echo ""
echo "=========================================="
