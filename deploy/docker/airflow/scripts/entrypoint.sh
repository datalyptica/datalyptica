#!/bin/bash
set -e

echo "========================================"
echo "Apache Airflow Initialization Starting..."
echo "========================================"

# Ensure airflow is in PATH (should be available in apache/airflow base image)
export PATH="/home/airflow/.local/bin:$PATH"

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until pg_isready -h ${POSTGRES_HOST:-postgresql} -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-postgres}; do
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

# Initialize Airflow database on first run
if [ ! -f /opt/airflow/.initialized ]; then
    echo "First run detected, initializing Airflow database..."
    
    # Initialize database
    airflow db init
    
    # Create admin user
    airflow users create \
        --username ${AIRFLOW_ADMIN_USERNAME} \
        --firstname Admin \
        --lastname User \
        --role Admin \
        --email ${AIRFLOW_ADMIN_EMAIL} \
        --password ${AIRFLOW_ADMIN_PASSWORD}
    
    # Mark as initialized
    touch /opt/airflow/.initialized
    
    echo "✅ Airflow database initialized"
else
    echo "Airflow already initialized, upgrading database if needed..."
    airflow db upgrade
fi

echo "========================================"
echo "✅ Airflow Initialized Successfully"
echo "========================================"

# Execute the main command based on the component
case "$1" in
    webserver)
        exec airflow webserver
        ;;
    scheduler)
        exec airflow scheduler
        ;;
    worker)
        exec airflow celery worker
        ;;
    triggerer)
        exec airflow triggerer
        ;;
    *)
        exec "$@"
        ;;
esac
