#!/bin/bash
set -e

echo "========================================"
echo "MLflow Initialization Starting..."
echo "========================================"

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until pg_isready -h ${POSTGRES_HOST:-postgresql} -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-postgres}; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "✅ PostgreSQL is ready"

# Wait for MinIO
echo "Waiting for MinIO..."
until curl -sf ${MLFLOW_S3_ENDPOINT_URL}/minio/health/live > /dev/null 2>&1; do
  echo "MinIO is unavailable - sleeping"
  sleep 2
done
echo "✅ MinIO is ready"

# Configure AWS credentials for MinIO
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF

cat > ~/.aws/config << EOF
[default]
region = ${AWS_REGION:-us-east-1}
s3 =
    signature_version = s3v4
    addressing_style = path
EOF

echo "========================================"
echo "✅ MLflow Initialized Successfully"
echo "========================================"

# Execute MLflow server
exec mlflow server \
    --host 0.0.0.0 \
    --port 5000 \
    --backend-store-uri postgresql://${MLFLOW_DB_USER}:${MLFLOW_DB_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${MLFLOW_DB_NAME} \
    --default-artifact-root s3://${MLFLOW_BUCKET}/ \
    --serve-artifacts
