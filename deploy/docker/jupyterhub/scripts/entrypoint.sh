#!/bin/bash
set -e

echo "========================================"
echo "JupyterHub Initialization Starting..."
echo "========================================"

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until pg_isready -h ${POSTGRES_HOST:-postgresql} -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-postgres}; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "✅ PostgreSQL is ready"

# Create JupyterHub configuration
echo "Creating JupyterHub configuration..."
envsubst < /srv/jupyterhub/config/jupyterhub_config.py.template > /srv/jupyterhub/config/jupyterhub_config.py

# Create data directory
mkdir -p /srv/jupyterhub/data

echo "========================================"
echo "✅ JupyterHub Initialized Successfully"
echo "========================================"

# Execute the main command
exec "$@"
