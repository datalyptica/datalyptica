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

# Initialize database - run upgrade/migrate each time for safety
echo "Upgrading Airflow database schema..."
airflow db migrate 2>&1 | grep -v "Could not import Security Manager" || true

# Create admin user if it doesn't exist (only for webserver)
if [ "$1" = "webserver" ]; then
    echo "Ensuring admin user exists..."
    python /usr/local/bin/create_user.py 2>&1 || echo "Admin user already exists or creation skipped"
fi

echo "========================================"
echo "✅ Airflow Initialized Successfully"
echo "========================================"

# Execute the main command based on the component
case "$1" in
    webserver)
        # Airflow 3.x uses 'api-server' instead of 'webserver'
        exec airflow api-server
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
