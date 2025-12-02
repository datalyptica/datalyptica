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

# Initialize database on first run
if [ ! -f /app/superset_home/.initialized ]; then
    echo "First run detected, initializing Superset database..."
    
    # Upgrade database
    superset db upgrade
    
    # Create admin user
    superset fab create-admin \
        --username ${SUPERSET_ADMIN_USERNAME} \
        --firstname Admin \
        --lastname User \
        --email ${SUPERSET_ADMIN_EMAIL} \
        --password ${SUPERSET_ADMIN_PASSWORD}
    
    # Initialize Superset
    superset init
    
    # Mark as initialized
    touch /app/superset_home/.initialized
    
    echo "✅ Superset database initialized"
else
    echo "Superset already initialized, skipping database setup"
    # Run upgrade in case of schema changes
    superset db upgrade
fi

echo "========================================"
echo "✅ Superset Initialized Successfully"
echo "========================================"

# Execute the main command
exec "$@"
