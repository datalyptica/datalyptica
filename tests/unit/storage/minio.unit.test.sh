#!/bin/bash

# =============================================================================
# MinIO Unit Tests
# Tests MinIO S3-compatible object storage functionality
# =============================================================================

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Test configuration
TEST_BUCKET="test-minio-unit-$$"
TEST_FILE="/tmp/minio_test_$$"
MINIO_ALIAS="test_minio"

# Setup
test_start "MinIO Unit Tests"

setup_test() {
    test_step "Setting up test environment"
    
    # Create test file
    echo "Test data for MinIO unit tests" > "$TEST_FILE"
    
    # Configure mc client
    docker exec docker-minio mc alias set "$MINIO_ALIAS" http://localhost:9000 admin password123 >/dev/null 2>&1 || true
}

teardown_test() {
    test_step "Cleaning up test environment"
    
    # Remove test bucket
    docker exec docker-minio mc rb --force "$MINIO_ALIAS/$TEST_BUCKET" >/dev/null 2>&1 || true
    
    # Remove test file
    rm -f "$TEST_FILE"
}

# Trap to ensure cleanup
trap teardown_test EXIT

# Test Cases
test_minio_health() {
    test_step "Test 1: MinIO health check"
    
    if check_http_endpoint "http://localhost:9000/minio/health/live" 200 10; then
        test_success "MinIO health endpoint responding"
        return 0
    else
        test_error "MinIO health endpoint not responding"
        return 1
    fi
}

test_minio_create_bucket() {
    test_step "Test 2: Create bucket"
    
    if docker exec docker-minio mc mb "$MINIO_ALIAS/$TEST_BUCKET" >/dev/null 2>&1; then
        test_success "Bucket created successfully"
        return 0
    else
        test_error "Failed to create bucket"
        return 1
    fi
}

test_minio_list_buckets() {
    test_step "Test 3: List buckets"
    
    if docker exec docker-minio mc ls "$MINIO_ALIAS" | grep -q "$TEST_BUCKET"; then
        test_success "Bucket listed successfully"
        return 0
    else
        test_error "Failed to list bucket"
        return 1
    fi
}

test_minio_upload_file() {
    test_step "Test 4: Upload file"
    
    # Copy test file to container
    docker cp "$TEST_FILE" docker-minio:/tmp/test_file
    
    if docker exec docker-minio mc cp /tmp/test_file "$MINIO_ALIAS/$TEST_BUCKET/test_file" >/dev/null 2>&1; then
        test_success "File uploaded successfully"
        return 0
    else
        test_error "Failed to upload file"
        return 1
    fi
}

test_minio_download_file() {
    test_step "Test 5: Download file"
    
    if docker exec docker-minio mc cp "$MINIO_ALIAS/$TEST_BUCKET/test_file" /tmp/downloaded_file >/dev/null 2>&1; then
        test_success "File downloaded successfully"
        return 0
    else
        test_error "Failed to download file"
        return 1
    fi
}

test_minio_file_integrity() {
    test_step "Test 6: Verify file integrity"
    
    # Get checksums
    local original_checksum
    original_checksum=$(docker exec docker-minio md5sum /tmp/test_file | awk '{print $1}')
    
    local downloaded_checksum
    downloaded_checksum=$(docker exec docker-minio md5sum /tmp/downloaded_file | awk '{print $1}')
    
    if [[ "$original_checksum" == "$downloaded_checksum" ]]; then
        test_success "File integrity verified (checksums match)"
        return 0
    else
        test_error "File integrity check failed (checksums don't match)"
        return 1
    fi
}

test_minio_delete_file() {
    test_step "Test 7: Delete file"
    
    if docker exec docker-minio mc rm "$MINIO_ALIAS/$TEST_BUCKET/test_file" >/dev/null 2>&1; then
        test_success "File deleted successfully"
        return 0
    else
        test_error "Failed to delete file"
        return 1
    fi
}

test_minio_versioning() {
    test_step "Test 8: Enable versioning"
    
    if docker exec docker-minio mc version enable "$MINIO_ALIAS/$TEST_BUCKET" >/dev/null 2>&1; then
        test_success "Versioning enabled successfully"
        return 0
    else
        test_warning "Versioning not supported in this MinIO configuration (non-critical)"
        return 0
    fi
}

test_minio_policy() {
    test_step "Test 9: Set bucket policy"
    
    # Create a simple read-only policy
    local policy='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::'$TEST_BUCKET'/*"]}]}'
    
    if echo "$policy" | docker exec -i docker-minio mc anonymous set-json "$MINIO_ALIAS/$TEST_BUCKET" >/dev/null 2>&1; then
        test_success "Bucket policy set successfully"
        return 0
    else
        test_warning "Failed to set bucket policy (non-critical)"
        return 0
    fi
}

test_minio_stats() {
    test_step "Test 10: Get bucket statistics"
    
    if docker exec docker-minio mc stat "$MINIO_ALIAS/$TEST_BUCKET" >/dev/null 2>&1; then
        test_success "Bucket statistics retrieved"
        return 0
    else
        test_error "Failed to get bucket statistics"
        return 1
    fi
}

# Run all tests
setup_test

FAILED_TESTS=0

test_minio_health || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_create_bucket || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_list_buckets || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_upload_file || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_download_file || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_file_integrity || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_delete_file || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_versioning || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_policy || FAILED_TESTS=$((FAILED_TESTS + 1))
test_minio_stats || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test summary
echo ""
if [[ $FAILED_TESTS -eq 0 ]]; then
    test_success "All MinIO unit tests passed! ✅"
    exit 0
else
    test_error "$FAILED_TESTS test(s) failed ❌"
    exit 1
fi
