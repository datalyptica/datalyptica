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

# Create data directory
mkdir -p /srv/jupyterhub/data

# If config template exists, create config in data directory (not in mounted config)
if [ -f "/srv/jupyterhub/config/jupyterhub_config.py.template" ]; then
    echo "Creating JupyterHub configuration from template..."
    envsubst < /srv/jupyterhub/config/jupyterhub_config.py.template > /srv/jupyterhub/data/jupyterhub_config.py
else
    echo "No config template found, using default configuration"
fi

echo "========================================"
echo "✅ JupyterHub Initialized Successfully"
echo "========================================"

# Execute the main command
exec "$@"
