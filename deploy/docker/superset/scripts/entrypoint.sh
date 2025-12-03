#!/bin/bash
set -e

echo "========================================"
echo "Apache Superset Initialization Starting..."
echo "========================================"

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until PGPASSWORD=${SUPERSET_DB_PASSWORD} psql -h ${POSTGRES_HOST} -U ${SUPERSET_DB_USER} -d ${SUPERSET_DB_NAME} -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "✅ PostgreSQL is ready"

# Wait for Redis
echo "Waiting for Redis..."
until redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} ping 2>/dev/null | grep -q PONG; do
  echo "Redis is unavailable - sleeping"
  sleep 2
done
echo "✅ Redis is ready"

# Generate Superset configuration
echo "Creating Superset configuration..."
if [ -f "/app/superset_home/config/superset_config.py.template" ]; then
    envsubst < /app/superset_home/config/superset_config.py.template > /app/superset_home/superset_config.py
else
    echo "Warning: No config template found!"
fi

echo "========================================"
echo "✅ Superset Ready - Starting Service"
echo "========================================"

# Execute the main command
exec "$@"
