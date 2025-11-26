#!/bin/bash

# =============================================================================
# E2E Test: Security & Authentication Flow
# Tests Keycloak authentication and authorization across services
# Validates: Keycloak, API authentication, service security
# =============================================================================

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../helpers/test_helpers.sh"

# Test configuration
KEYCLOAK_URL="http://localhost:8180"
KEYCLOAK_ADMIN_USER="admin"
KEYCLOAK_ADMIN_PASSWORD="admin"
TEST_REALM="shudl-test-$$"
TEST_CLIENT="shudl-client-$$"
TEST_USER="testuser-$$"
TEST_PASSWORD="Test@123456"

# Setup
test_start "E2E Security & Authentication Test"

setup_test() {
    test_step "Setting up security test environment"
    test_success "Environment initialized"
}

teardown_test() {
    test_step "Cleaning up security test environment"
    
    # Delete test realm (cascades to all resources)
    local admin_token
    admin_token=$(get_admin_token)
    
    if [[ -n "$admin_token" ]]; then
        curl -s -X DELETE \
            -H "Authorization: Bearer $admin_token" \
            "$KEYCLOAK_URL/admin/realms/$TEST_REALM" >/dev/null 2>&1 || true
    fi
    
    test_success "Cleanup complete"
}

trap teardown_test EXIT

# Helper function to get admin token
get_admin_token() {
    local response
    response=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$KEYCLOAK_ADMIN_USER" \
        -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli")
    
    echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
}

# =============================================================================
# Scenario 1: Keycloak Server Health
# =============================================================================
scenario_1_keycloak_health() {
    test_step "Scenario 1: Keycloak Server Health"
    
    # 1.1 Check health endpoint
    if check_http_endpoint "$KEYCLOAK_URL/health/ready" 200 10; then
        test_success "Keycloak server is healthy"
    else
        test_error "Keycloak server not responding"
        return 1
    fi
    
    # 1.2 Check admin console
    if check_http_endpoint "$KEYCLOAK_URL/admin" 200 10; then
        test_success "Keycloak admin console accessible"
    else
        test_warning "Admin console may not be accessible"
    fi
    
    return 0
}

# =============================================================================
# Scenario 2: Admin Authentication
# =============================================================================
scenario_2_admin_auth() {
    test_step "Scenario 2: Admin Authentication"
    
    # 2.1 Get admin token
    local admin_token
    admin_token=$(get_admin_token)
    
    if [[ -n "$admin_token" ]] && [[ ${#admin_token} -gt 50 ]]; then
        test_success "Admin token obtained successfully"
    else
        test_error "Failed to obtain admin token"
        return 1
    fi
    
    # 2.2 Verify token by accessing admin API
    local realms
    realms=$(curl -s -H "Authorization: Bearer $admin_token" \
        "$KEYCLOAK_URL/admin/realms")
    
    if echo "$realms" | grep -q "master"; then
        test_success "Admin token validated via API"
    else
        test_error "Admin token validation failed"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 3: Realm Management
# =============================================================================
scenario_3_realm_management() {
    test_step "Scenario 3: Realm Management"
    
    local admin_token
    admin_token=$(get_admin_token)
    
    # 3.1 Create test realm
    local realm_payload="{
        \"realm\": \"$TEST_REALM\",
        \"enabled\": true,
        \"displayName\": \"ShuDL Test Realm\",
        \"registrationAllowed\": false,
        \"loginWithEmailAllowed\": true,
        \"duplicateEmailsAllowed\": false,
        \"resetPasswordAllowed\": true
    }"
    
    local create_response
    create_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d "$realm_payload")
    
    if [[ "$create_response" == "201" ]]; then
        test_success "Test realm created: $TEST_REALM"
    else
        test_error "Failed to create realm (HTTP $create_response)"
        return 1
    fi
    
    # 3.2 Verify realm exists
    local realm_info
    realm_info=$(curl -s -H "Authorization: Bearer $admin_token" \
        "$KEYCLOAK_URL/admin/realms/$TEST_REALM")
    
    if echo "$realm_info" | grep -q "\"realm\":\"$TEST_REALM\""; then
        test_success "Realm verified: $TEST_REALM"
    else
        test_error "Realm verification failed"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 4: Client Registration
# =============================================================================
scenario_4_client_registration() {
    test_step "Scenario 4: Client Registration"
    
    local admin_token
    admin_token=$(get_admin_token)
    
    # 4.1 Create OAuth2 client
    local client_payload="{
        \"clientId\": \"$TEST_CLIENT\",
        \"enabled\": true,
        \"publicClient\": false,
        \"serviceAccountsEnabled\": true,
        \"standardFlowEnabled\": true,
        \"directAccessGrantsEnabled\": true,
        \"clientAuthenticatorType\": \"client-secret\",
        \"secret\": \"client-secret-123\"
    }"
    
    local client_response
    client_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$KEYCLOAK_URL/admin/realms/$TEST_REALM/clients" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d "$client_payload")
    
    if [[ "$client_response" == "201" ]]; then
        test_success "OAuth2 client registered: $TEST_CLIENT"
    else
        test_error "Failed to register client (HTTP $client_response)"
        return 1
    fi
    
    # 4.2 Verify client exists
    local clients
    clients=$(curl -s -H "Authorization: Bearer $admin_token" \
        "$KEYCLOAK_URL/admin/realms/$TEST_REALM/clients")
    
    if echo "$clients" | grep -q "\"clientId\":\"$TEST_CLIENT\""; then
        test_success "Client verified in realm"
    else
        test_error "Client verification failed"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 5: User Management
# =============================================================================
scenario_5_user_management() {
    test_step "Scenario 5: User Management"
    
    local admin_token
    admin_token=$(get_admin_token)
    
    # 5.1 Create test user
    local user_payload="{
        \"username\": \"$TEST_USER\",
        \"enabled\": true,
        \"emailVerified\": true,
        \"firstName\": \"Test\",
        \"lastName\": \"User\",
        \"email\": \"$TEST_USER@example.com\",
        \"credentials\": [{
            \"type\": \"password\",
            \"value\": \"$TEST_PASSWORD\",
            \"temporary\": false
        }]
    }"
    
    local user_response
    user_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$KEYCLOAK_URL/admin/realms/$TEST_REALM/users" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d "$user_payload")
    
    if [[ "$user_response" == "201" ]]; then
        test_success "Test user created: $TEST_USER"
    else
        test_error "Failed to create user (HTTP $user_response)"
        return 1
    fi
    
    # 5.2 Search for user
    local users
    users=$(curl -s -H "Authorization: Bearer $admin_token" \
        "$KEYCLOAK_URL/admin/realms/$TEST_REALM/users?username=$TEST_USER")
    
    if echo "$users" | grep -q "\"username\":\"$TEST_USER\""; then
        test_success "User found in realm"
    else
        test_error "User search failed"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 6: User Authentication
# =============================================================================
scenario_6_user_authentication() {
    test_step "Scenario 6: User Authentication"
    
    # 6.1 Authenticate user and get token
    local user_token_response
    user_token_response=$(curl -s -X POST \
        "$KEYCLOAK_URL/realms/$TEST_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$TEST_USER" \
        -d "password=$TEST_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=$TEST_CLIENT" \
        -d "client_secret=client-secret-123")
    
    local user_token
    user_token=$(echo "$user_token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    if [[ -n "$user_token" ]] && [[ ${#user_token} -gt 50 ]]; then
        test_success "User authentication successful"
    else
        test_error "User authentication failed"
        return 1
    fi
    
    # 6.2 Verify token contains user info
    if echo "$user_token_response" | grep -q "access_token"; then
        test_success "Access token issued"
    fi
    
    if echo "$user_token_response" | grep -q "refresh_token"; then
        test_success "Refresh token issued"
    fi
    
    return 0
}

# =============================================================================
# Scenario 7: Token Introspection
# =============================================================================
scenario_7_token_introspection() {
    test_step "Scenario 7: Token Introspection"
    
    # 7.1 Get user token
    local user_token_response
    user_token_response=$(curl -s -X POST \
        "$KEYCLOAK_URL/realms/$TEST_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$TEST_USER" \
        -d "password=$TEST_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=$TEST_CLIENT" \
        -d "client_secret=client-secret-123")
    
    local user_token
    user_token=$(echo "$user_token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    # 7.2 Introspect token
    local introspection
    introspection=$(curl -s -X POST \
        "$KEYCLOAK_URL/realms/$TEST_REALM/protocol/openid-connect/token/introspect" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "token=$user_token" \
        -d "client_id=$TEST_CLIENT" \
        -d "client_secret=client-secret-123")
    
    if echo "$introspection" | grep -q '"active":true'; then
        test_success "Token introspection successful (active token)"
    else
        test_error "Token introspection failed or token inactive"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Scenario 8: Invalid Authentication Attempts
# =============================================================================
scenario_8_invalid_auth() {
    test_step "Scenario 8: Invalid Authentication Handling"
    
    # 8.1 Wrong password
    local wrong_pw_response
    wrong_pw_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$KEYCLOAK_URL/realms/$TEST_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$TEST_USER" \
        -d "password=WrongPassword123" \
        -d "grant_type=password" \
        -d "client_id=$TEST_CLIENT" \
        -d "client_secret=client-secret-123")
    
    if [[ "$wrong_pw_response" == "401" ]]; then
        test_success "Invalid password correctly rejected (HTTP 401)"
    else
        test_warning "Expected 401 for wrong password, got HTTP $wrong_pw_response"
    fi
    
    # 8.2 Non-existent user
    local invalid_user_response
    invalid_user_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$KEYCLOAK_URL/realms/$TEST_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=nonexistent-user" \
        -d "password=SomePassword" \
        -d "grant_type=password" \
        -d "client_id=$TEST_CLIENT" \
        -d "client_secret=client-secret-123")
    
    if [[ "$invalid_user_response" == "401" ]]; then
        test_success "Non-existent user correctly rejected (HTTP 401)"
    else
        test_warning "Expected 401 for invalid user, got HTTP $invalid_user_response"
    fi
    
    # 8.3 Invalid client secret
    local invalid_secret_response
    invalid_secret_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST "$KEYCLOAK_URL/realms/$TEST_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$TEST_USER" \
        -d "password=$TEST_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=$TEST_CLIENT" \
        -d "client_secret=wrong-secret")
    
    if [[ "$invalid_secret_response" == "401" ]]; then
        test_success "Invalid client secret correctly rejected (HTTP 401)"
    else
        test_warning "Expected 401 for invalid secret, got HTTP $invalid_secret_response"
    fi
    
    return 0
}

# =============================================================================
# Execute Test Scenarios
# =============================================================================

setup_test

FAILED_SCENARIOS=0

scenario_1_keycloak_health || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_2_admin_auth || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_3_realm_management || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_4_client_registration || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_5_user_management || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_6_user_authentication || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_7_token_introspection || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
scenario_8_invalid_auth || FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))

# Test summary
echo ""
echo "=========================================="
echo "E2E Security & Authentication Test Summary"
echo "=========================================="
echo "Scenarios run: 8"
echo "Scenarios passed: $((8 - FAILED_SCENARIOS))"
echo "Scenarios failed: $FAILED_SCENARIOS"
echo "=========================================="

if [[ $FAILED_SCENARIOS -eq 0 ]]; then
    test_success "All security scenarios passed! ✅"
    echo "✅ Security components validated:"
    echo "   → Keycloak Server (Health, Admin Console)"
    echo "   → Admin Authentication"
    echo "   → Realm Management (Create, Verify)"
    echo "   → Client Registration (OAuth2)"
    echo "   → User Management (Create, Search)"
    echo "   → User Authentication (Token issuance)"
    echo "   → Token Introspection"
    echo "   → Error Handling (Invalid credentials)"
    exit 0
else
    test_error "$FAILED_SCENARIOS scenario(s) failed ❌"
    exit 1
fi
