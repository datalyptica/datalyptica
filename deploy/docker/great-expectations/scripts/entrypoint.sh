#!/bin/bash
set -e

echo "================================"
echo "Great Expectations - Starting"
echo "================================"

# Required environment variables validation
: ${S3_ENDPOINT:?'S3_ENDPOINT must be set'}
: ${S3_ACCESS_KEY:?'S3_ACCESS_KEY must be set'}
: ${S3_SECRET_KEY:?'S3_SECRET_KEY must be set'}
: ${POSTGRES_HOST:?'POSTGRES_HOST must be set'}
: ${POSTGRES_PORT:?'POSTGRES_PORT must be set'}
: ${NESSIE_URI:?'NESSIE_URI must be set'}

# Wait for dependencies
echo "Waiting for PostgreSQL..."
until pg_isready -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER:-postgres} > /dev/null 2>&1; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 2
done
echo "PostgreSQL is ready"

echo "Waiting for MinIO..."
until curl -sf ${S3_ENDPOINT}/minio/health/live > /dev/null 2>&1; do
    echo "MinIO is unavailable - sleeping"
    sleep 2
done
echo "MinIO is ready"

echo "Waiting for Nessie..."
until curl -sf ${NESSIE_URI}/config > /dev/null 2>&1; do
    echo "Nessie is unavailable - sleeping"
    sleep 2
done
echo "Nessie is ready"

echo "================================"
echo "Great Expectations - Ready"
echo "JupyterLab: http://localhost:${GE_JUPYTER_PORT:-8888}"
echo "Data Docs: ${GE_HOME}/uncommitted/data_docs/local_site/index.html"
echo "================================"

# Execute the main command
exec "$@"
