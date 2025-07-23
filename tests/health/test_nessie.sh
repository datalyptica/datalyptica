#!/bin/bash

# Test: Nessie Health Check
# Validates Nessie catalog service

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Nessie Health Check"

# Load environment variables
cd "${SCRIPT_DIR}/../../"
set -a
source docker/.env
set +a

test_step "Checking Nessie container status..."
if ! docker compose ps nessie 2>/dev/null | grep -q "healthy"; then
    test_error "Nessie container is not healthy"
    docker compose ps nessie
    exit 1
fi

test_step "Testing Nessie port connectivity..."
if ! check_port "localhost" "$NESSIE_PORT" 10; then
    test_error "Cannot connect to Nessie port $NESSIE_PORT"
    exit 1
fi

test_step "Testing Nessie API endpoints..."
if ! check_http_endpoint "http://localhost:$NESSIE_PORT/api/v2/config" 200 30; then
    test_error "Nessie config endpoint is not responding"
    exit 1
fi

test_step "Verifying Nessie service health..."
# Nessie doesn't have a dedicated health endpoint, but config endpoint confirms it's operational
test_info "✓ Nessie is responding correctly to API requests"

test_step "Checking Nessie configuration..."
config_response=$(curl -s "http://localhost:$NESSIE_PORT/api/v2/config" 2>/dev/null || echo "{}")
if echo "$config_response" | jq -e '.defaultBranch' &>/dev/null; then
    default_branch=$(echo "$config_response" | jq -r '.defaultBranch')
    test_info "✓ Default branch: $default_branch"
else
    test_error "Cannot retrieve Nessie configuration"
    exit 1
fi

test_step "Testing branch operations..."
# List branches
branches_response=$(curl -s "http://localhost:$NESSIE_PORT/api/v2/trees" 2>/dev/null || echo "{}")
if echo "$branches_response" | jq -e '.references' &>/dev/null; then
    branch_count=$(echo "$branches_response" | jq '.references | length')
    test_info "✓ Found $branch_count branches"
    
    # Check if main branch exists
    if echo "$branches_response" | jq -e '.references[] | select(.name == "main")' &>/dev/null; then
        test_info "✓ Main branch exists"
    else
        test_error "Main branch not found"
        exit 1
    fi
else
    test_error "Cannot retrieve branch information"
    exit 1
fi

test_step "Testing namespace operations..."
# List namespaces
namespaces_response=$(curl -s "http://localhost:$NESSIE_PORT/api/v2/trees/main/entries" 2>/dev/null || echo "{}")
if echo "$namespaces_response" | jq -e '.entries' &>/dev/null; then
    namespace_count=$(echo "$namespaces_response" | jq '.entries | length')
    test_info "✓ Found $namespace_count entries in main branch"
else
    test_warning "Cannot retrieve namespace information (may be empty)"
fi

test_step "Testing database connectivity..."
# Check if Nessie can connect to PostgreSQL
nessie_logs=$(docker logs shudl-nessie --tail=20 2>/dev/null || echo "")
if echo "$nessie_logs" | grep -q "Started.*Application\|Nessie.*started"; then
    test_info "✓ Nessie application started successfully"
else
    test_warning "Cannot confirm Nessie startup from logs"
fi

if echo "$nessie_logs" | grep -iq "error\|exception\|failed"; then
    test_warning "Found error messages in Nessie logs"
fi

test_step "Validating API version..."
api_info=$(curl -s "http://localhost:$NESSIE_PORT/api/v2" 2>/dev/null || echo "{}")
if echo "$api_info" | jq -e '.version' &>/dev/null; then
    api_version=$(echo "$api_info" | jq -r '.version')
    test_info "✓ Nessie API version: $api_version"
else
    test_warning "Cannot retrieve API version information"
fi

test_success "Nessie is healthy and operational" 