#!/bin/bash

# Test: MinIO Health Check
# Validates MinIO object storage service

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "MinIO Health Check"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Checking MinIO container status..."
if ! docker compose ps minio 2>/dev/null | grep -q "healthy"; then
    test_error "MinIO container is not healthy"
    docker compose ps minio
    exit 1
fi

test_step "Testing MinIO API port connectivity..."
if ! check_port "localhost" "$MINIO_API_PORT" 10; then
    test_error "Cannot connect to MinIO API port $MINIO_API_PORT"
    exit 1
fi

test_step "Testing MinIO Console port connectivity..."
if ! check_port "localhost" "$MINIO_CONSOLE_PORT" 10; then
    test_error "Cannot connect to MinIO Console port $MINIO_CONSOLE_PORT"
    exit 1
fi

test_step "Testing MinIO API health endpoint..."
if ! check_http_endpoint "http://localhost:$MINIO_API_PORT/minio/health/live" 200 30; then
    test_error "MinIO health endpoint is not responding"
    exit 1
fi

test_step "Testing bucket operations..."
# Test bucket creation and operations using mc client
if docker exec shudl-minio mc ls lakehouse/ &>/dev/null; then
    test_info "✓ Lakehouse bucket accessible"
else
    test_error "Cannot access lakehouse bucket"
    exit 1
fi

# Test file operations
test_file="/tmp/minio_test_$(date +%s).txt"
echo "MinIO health check test data" > "$test_file"

# Upload test file
if docker cp "$test_file" shudl-minio:/tmp/test_file.txt && \
   docker exec shudl-minio mc cp /tmp/test_file.txt lakehouse/test/health_check.txt &>/dev/null; then
    test_info "✓ File upload successful"
else
    test_error "Cannot upload test file"
    exit 1
fi

# Download test file
if docker exec shudl-minio mc cp lakehouse/test/health_check.txt /tmp/downloaded_file.txt &>/dev/null && \
   docker exec shudl-minio cat /tmp/downloaded_file.txt | grep -q "MinIO health check test data"; then
    test_info "✓ File download and content verification successful"
else
    test_error "Cannot download or verify test file"
    exit 1
fi

# Cleanup test files
docker exec shudl-minio rm -f /tmp/test_file.txt /tmp/downloaded_file.txt &>/dev/null || true
docker exec shudl-minio mc rm lakehouse/test/health_check.txt &>/dev/null || true
rm -f "$test_file"

test_step "Checking storage information..."
# Get storage info
storage_info=$(docker exec shudl-minio mc admin info minio 2>/dev/null || echo "")
if [[ -n "$storage_info" ]]; then
    test_info "✓ Storage information accessible"
else
    test_warning "Cannot retrieve storage information"
fi

test_step "Validating MinIO configuration..."
# Check if S3 API is working
if curl -s "http://localhost:$MINIO_API_PORT" | grep -q "Access.*Denied\|InvalidRequest" 2>/dev/null; then
    test_info "✓ S3 API is responding (access control working)"
else
    test_warning "S3 API response unexpected"
fi

test_success "MinIO is healthy and operational" 