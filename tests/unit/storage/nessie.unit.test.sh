#!/bin/bash

# =============================================================================
# Nessie Unit Tests
# Tests Project Nessie catalog functionality
# =============================================================================

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Test configuration
NESSIE_URL="http://localhost:19120/api/v2"
TEST_BRANCH="test-branch-$$"
TEST_TAG="test-tag-$$"

# Setup
test_start "Nessie Unit Tests"

teardown_test() {
    test_step "Cleaning up test environment"
    
    # Delete test branch if exists
    curl -s -X DELETE "$NESSIE_URL/trees/$TEST_BRANCH" >/dev/null 2>&1 || true
}

# Trap to ensure cleanup
trap teardown_test EXIT

# Test Cases
test_nessie_health() {
    test_step "Test 1: Nessie health check"
    
    if check_http_endpoint "$NESSIE_URL/config" 200 10; then
        test_success "Nessie API responding"
        return 0
    else
        test_error "Nessie API not responding"
        return 1
    fi
}

test_nessie_get_config() {
    test_step "Test 2: Get Nessie configuration"
    
    local response
    response=$(curl -s "$NESSIE_URL/config")
    
    if echo "$response" | grep -q "defaultBranch"; then
        test_success "Configuration retrieved successfully"
        return 0
    else
        test_error "Failed to retrieve configuration"
        return 1
    fi
}

test_nessie_list_branches() {
    test_step "Test 3: List branches"
    
    local response
    response=$(curl -s "$NESSIE_URL/trees")
    
    if echo "$response" | grep -q "references"; then
        test_success "Branches listed successfully"
        return 0
    else
        test_error "Failed to list branches"
        return 1
    fi
}

test_nessie_get_default_branch() {
    test_step "Test 4: Get default branch (main)"
    
    local response
    response=$(curl -s "$NESSIE_URL/trees/main")
    
    if echo "$response" | grep -q "name"; then
        test_success "Default branch retrieved"
        return 0
    else
        test_error "Failed to retrieve default branch"
        return 1
    fi
}

test_nessie_create_branch() {
    test_step "Test 5: Create new branch"
    
    # Get main branch hash
    local main_hash
    main_hash=$(curl -s "$NESSIE_URL/trees/main" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4 | head -1)
    
    local payload="{\"name\":\"$TEST_BRANCH\",\"type\":\"BRANCH\",\"hash\":\"$main_hash\"}"
    
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$NESSIE_URL/trees")
    
    if echo "$response" | grep -q "$TEST_BRANCH" || curl -s "$NESSIE_URL/trees/$TEST_BRANCH" | grep -q "name"; then
        test_success "Branch created successfully"
        return 0
    else
        test_error "Failed to create branch"
        return 1
    fi
}

test_nessie_get_branch() {
    test_step "Test 6: Get created branch"
    
    local response
    response=$(curl -s "$NESSIE_URL/trees/$TEST_BRANCH")
    
    if echo "$response" | grep -q "$TEST_BRANCH"; then
        test_success "Branch retrieved successfully"
        return 0
    else
        test_error "Failed to retrieve branch"
        return 1
    fi
}

test_nessie_list_contents() {
    test_step "Test 7: List branch contents"
    
    local response
    response=$(curl -s "$NESSIE_URL/trees/$TEST_BRANCH/entries")
    
    if [[ -n "$response" ]]; then
        test_success "Branch contents listed"
        return 0
    else
        test_error "Failed to list branch contents"
        return 1
    fi
}

test_nessie_commit_log() {
    test_step "Test 8: Get commit log"
    
    local response
    response=$(curl -s "$NESSIE_URL/trees/$TEST_BRANCH/history")
    
    if echo "$response" | grep -q "logEntries"; then
        test_success "Commit log retrieved"
        return 0
    else
        test_error "Failed to retrieve commit log"
        return 1
    fi
}

test_nessie_delete_branch() {
    test_step "Test 9: Delete branch"
    
    # Get branch hash
    local branch_hash
    branch_hash=$(curl -s "$NESSIE_URL/trees/$TEST_BRANCH" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4 | head -1)
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$NESSIE_URL/trees/$TEST_BRANCH?hash=$branch_hash")
    
    if [[ "$response_code" == "200" ]] || [[ "$response_code" == "204" ]]; then
        test_success "Branch deleted successfully"
        return 0
    else
        test_error "Failed to delete branch (HTTP $response_code)"
        return 1
    fi
}

test_nessie_branch_not_exists() {
    test_step "Test 10: Verify branch deletion"
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$NESSIE_URL/trees/$TEST_BRANCH")
    
    if [[ "$response_code" == "404" ]]; then
        test_success "Branch confirmed deleted"
        return 0
    else
        test_error "Branch still exists after deletion"
        return 1
    fi
}

# Run all tests
FAILED_TESTS=0

test_nessie_health || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_get_config || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_list_branches || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_get_default_branch || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_create_branch || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_get_branch || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_list_contents || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_commit_log || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_delete_branch || FAILED_TESTS=$((FAILED_TESTS + 1))
test_nessie_branch_not_exists || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test summary
echo ""
if [[ $FAILED_TESTS -eq 0 ]]; then
    test_success "All Nessie unit tests passed! ✅"
    exit 0
else
    test_error "$FAILED_TESTS test(s) failed ❌"
    exit 1
fi
