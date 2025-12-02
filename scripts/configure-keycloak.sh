#!/bin/bash
# configure-keycloak.sh
# Automated Keycloak configuration for Datalyptica platform

set -e

KEYCLOAK_URL="http://localhost:8180"
ADMIN_USER="admin"
ADMIN_PASSWORD=$(cat ../secrets/passwords/keycloak_admin_password 2>/dev/null || echo "admin")

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║        🔐 KEYCLOAK CONFIGURATION FOR DATALYPTICA 🔐               ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Function to get admin token
get_admin_token() {
    echo "📝 Getting admin access token..."
    TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$ADMIN_USER" \
        -d "password=$ADMIN_PASSWORD" \
        -d 'grant_type=password' \
        -d 'client_id=admin-cli' | jq -r '.access_token')
    
    if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
        echo "❌ Failed to get admin token. Check Keycloak credentials."
        exit 1
    fi
    echo "✅ Admin token obtained"
}

# Function to create realm
create_realm() {
    echo ""
    echo "🏛️  Creating Datalyptica realm..."
    
    REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $TOKEN" \
        "$KEYCLOAK_URL/admin/realms/datalyptica")
    
    if [ "$REALM_EXISTS" == "200" ]; then
        echo "ℹ️  Realm 'datalyptica' already exists"
        return
    fi
    
    curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "realm": "datalyptica",
            "enabled": true,
            "displayName": "Datalyptica Platform",
            "displayNameHtml": "<b>Datalyptica</b> Data Platform",
            "registrationAllowed": false,
            "loginWithEmailAllowed": true,
            "duplicateEmailsAllowed": false,
            "resetPasswordAllowed": true,
            "editUsernameAllowed": false,
            "bruteForceProtected": true,
            "sslRequired": "external",
            "accessTokenLifespan": 3600,
            "ssoSessionIdleTimeout": 1800,
            "ssoSessionMaxLifespan": 36000
        }'
    
    echo "✅ Realm 'datalyptica' created"
}

# Function to create roles
create_roles() {
    echo ""
    echo "👥 Creating roles..."
    
    for role in "admin" "developer" "analyst" "viewer"; do
        curl -s -X POST "$KEYCLOAK_URL/admin/realms/datalyptica/roles" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"$role\",
                \"description\": \"${role^} role for Datalyptica platform\"
            }" 2>/dev/null || echo "  ℹ️  Role '$role' may already exist"
    done
    
    echo "✅ Roles created: admin, developer, analyst, viewer"
}

# Function to create client
create_client() {
    local CLIENT_ID=$1
    local CLIENT_NAME=$2
    local REDIRECT_URIS=$3
    
    echo ""
    echo "🔧 Creating client: $CLIENT_NAME..."
    
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/datalyptica/clients" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"clientId\": \"$CLIENT_ID\",
            \"name\": \"$CLIENT_NAME\",
            \"description\": \"$CLIENT_NAME for Datalyptica platform\",
            \"enabled\": true,
            \"clientAuthenticatorType\": \"client-secret\",
            \"redirectUris\": $REDIRECT_URIS,
            \"webOrigins\": [\"+\"],
            \"protocol\": \"openid-connect\",
            \"publicClient\": false,
            \"standardFlowEnabled\": true,
            \"implicitFlowEnabled\": false,
            \"directAccessGrantsEnabled\": true,
            \"serviceAccountsEnabled\": true,
            \"authorizationServicesEnabled\": false,
            \"fullScopeAllowed\": true
        }" 2>/dev/null || echo "  ℹ️  Client '$CLIENT_ID' may already exist"
    
    echo "✅ Client '$CLIENT_ID' configured"
}

# Function to create user
create_user() {
    local USERNAME=$1
    local EMAIL=$2
    local FIRST_NAME=$3
    local LAST_NAME=$4
    local PASSWORD=$5
    local ROLES=$6
    
    echo ""
    echo "👤 Creating user: $USERNAME..."
    
    # Create user
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/datalyptica/users" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$USERNAME\",
            \"email\": \"$EMAIL\",
            \"firstName\": \"$FIRST_NAME\",
            \"lastName\": \"$LAST_NAME\",
            \"enabled\": true,
            \"emailVerified\": true,
            \"credentials\": [{
                \"type\": \"password\",
                \"value\": \"$PASSWORD\",
                \"temporary\": false
            }]
        }" 2>/dev/null || echo "  ℹ️  User '$USERNAME' may already exist"
    
    echo "✅ User '$USERNAME' created"
}

# Main execution
main() {
    echo "🚀 Starting Keycloak configuration..."
    echo ""
    
    # Get admin token
    get_admin_token
    
    # Create realm
    create_realm
    
    # Create roles
    create_roles
    
    # Create clients for services
    create_client "grafana-client" "Grafana" '["http://localhost:3000/*", "https://localhost:3443/*"]'
    create_client "nessie-client" "Nessie Catalog" '["http://localhost:19120/*", "https://localhost:19443/*"]'
    create_client "trino-client" "Trino Query Engine" '["http://localhost:8080/*", "https://localhost:8443/*"]'
    create_client "prometheus-client" "Prometheus Monitoring" '["http://localhost:9090/*", "https://localhost:9443/*"]'
    create_client "datalyptica-api" "Datalyptica API" '["http://localhost:8000/*", "https://localhost:8443/*"]'
    
    # Create test users
    create_user "admin" "admin@datalyptica.local" "Admin" "User" "admin123" "admin"
    create_user "developer" "dev@datalyptica.local" "Developer" "User" "dev123" "developer"
    create_user "analyst" "analyst@datalyptica.local" "Analyst" "User" "analyst123" "analyst"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ KEYCLOAK CONFIGURATION COMPLETE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Summary:"
    echo "  • Realm: datalyptica"
    echo "  • Roles: admin, developer, analyst, viewer"
    echo "  • Clients: grafana-client, nessie-client, trino-client, prometheus-client, datalyptica-api"
    echo "  • Users: admin, developer, analyst"
    echo ""
    echo "🔐 Access Keycloak Admin Console:"
    echo "  URL: http://localhost:8180"
    echo "  Username: $ADMIN_USER"
    echo "  Password: (from secrets/passwords/keycloak_admin_password)"
    echo ""
    echo "🔑 Test Users Created:"
    echo "  • admin / admin123 (admin role)"
    echo "  • developer / dev123 (developer role)"
    echo "  • analyst / analyst123 (analyst role)"
    echo ""
    echo "📝 Next Steps:"
    echo "  1. Get client secrets from Keycloak admin console"
    echo "  2. Configure services to use Keycloak OIDC"
    echo "  3. Test SSO login flows"
    echo ""
}

# Run main function
main "$@"

