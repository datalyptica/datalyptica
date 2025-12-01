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

# Initialize Great Expectations project if not exists
if [ ! -f "${GE_HOME}/great_expectations.yml" ]; then
    echo "Initializing Great Expectations project..."
    cd ${GE_HOME}
    echo "Y" | great_expectations init --no-usage-stats || true
    
    echo "Great Expectations project initialized at ${GE_HOME}"
fi

# Configure AWS credentials for MinIO
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${S3_ACCESS_KEY}
aws_secret_access_key = ${S3_SECRET_KEY}
EOF

cat > ~/.aws/config << EOF
[default]
region = ${S3_REGION:-us-east-1}
s3 =
    endpoint_url = ${S3_ENDPOINT}
    signature_version = s3v4
EOF

# Configure database connections
cat > ${GE_HOME}/connections.yaml << EOF
# PostgreSQL Connection
postgres:
  host: ${POSTGRES_HOST}
  port: ${POSTGRES_PORT}
  database: ${POSTGRES_DB:-datalyptica}
  username: ${POSTGRES_USER:-datalyptica}
  password: ${POSTGRES_PASSWORD}

# Trino Connection
trino:
  host: ${TRINO_HOST:-trino}
  port: ${TRINO_PORT:-8080}
  catalog: ${TRINO_CATALOG:-iceberg}
  schema: ${TRINO_SCHEMA:-default}

# MinIO/S3 Connection
s3:
  endpoint_url: ${S3_ENDPOINT}
  access_key: ${S3_ACCESS_KEY}
  secret_key: ${S3_SECRET_KEY}
  region: ${S3_REGION:-us-east-1}
  bucket: ${S3_BUCKET:-lakehouse}

# Nessie Connection
nessie:
  uri: ${NESSIE_URI}
  ref: ${NESSIE_REF:-main}
  warehouse: ${NESSIE_WAREHOUSE:-s3://lakehouse/warehouse}
EOF

echo "Connections configured"

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
