#!/bin/bash
# Setup databases for Analytics & ML services

set -e

echo "============================================"
echo "Setting up Analytics & ML Service Databases"
echo "============================================"

# PostgreSQL connection details
POSTGRES_HOST=${POSTGRES_HOST:-localhost}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-password}

echo ""
echo "[1/4] Creating JupyterHub database..."
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE DATABASE IF NOT EXISTS jupyterhub;"
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE USER IF NOT EXISTS jupyterhub WITH PASSWORD 'jupyterhub123';"
docker exec docker-haproxy psql -h postgresql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE jupyterhub TO jupyterhub;"

echo "[2/4] Creating MLflow database..."
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE DATABASE IF NOT EXISTS mlflow;"
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE USER IF NOT EXISTS mlflow WITH PASSWORD 'mlflow123';"
docker exec docker-haproxy psql -h postgresql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;"

echo "[3/4] Creating Superset database..."
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE DATABASE IF NOT EXISTS superset;"
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE USER IF NOT EXISTS superset WITH PASSWORD 'superset123';"
docker exec docker-haproxy psql -h postgresql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE superset TO superset;"

echo "[4/4] Creating Airflow database..."
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE DATABASE IF NOT EXISTS airflow;"
docker exec docker-haproxy psql -h postgresql -U postgres -c "CREATE USER IF NOT EXISTS airflow WITH PASSWORD 'airflow123';"
docker exec docker-haproxy psql -h postgresql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;"

echo ""
echo "============================================"
echo "All databases created successfully!"
echo "============================================"
