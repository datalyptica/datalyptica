#!/usr/bin/env bash

#
# ShuDL Secrets Generation Script
# Generates secure passwords and creates Docker secret files
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SECRETS_DIR="${SECRETS_DIR:-./secrets/passwords}"
PASSWORD_LENGTH=32
FORCE=${FORCE:-false}

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

generate_password() {
    # Generate a secure random password
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-${PASSWORD_LENGTH}
}

create_secret_file() {
    local secret_name=$1
    local secret_value=$2
    local secret_file="${SECRETS_DIR}/${secret_name}"
    
    # Check if secret already exists
    if [[ -f "$secret_file" ]] && [[ "$FORCE" != "true" ]]; then
        log_warning "Secret ${secret_name} already exists. Use FORCE=true to override."
        return 1
    fi
    
    # Create secret file
    echo -n "$secret_value" > "$secret_file"
    chmod 600 "$secret_file"
    log_success "Created secret: ${secret_name}"
}

# Main
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           🔐 ShuDL Secrets Generation 🔐                     ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Create secrets directory
    log_info "Creating secrets directory: ${SECRETS_DIR}"
    mkdir -p "${SECRETS_DIR}"
    chmod 700 "${SECRETS_DIR}"
    
    echo ""
    log_info "Generating secure passwords..."
    echo ""
    
    # Storage Layer Secrets
    log_info "=== Storage Layer ==="
    create_secret_file "postgres_password" "$(generate_password)"
    create_secret_file "shudl_password" "$(generate_password)"
    create_secret_file "minio_root_password" "$(generate_password)"
    create_secret_file "s3_access_key" "$(generate_password)"
    create_secret_file "s3_secret_key" "$(generate_password)"
    
    echo ""
    log_info "=== Observability Layer ==="
    create_secret_file "grafana_admin_password" "$(generate_password)"
    create_secret_file "keycloak_admin_password" "$(generate_password)"
    create_secret_file "keycloak_db_password" "$(generate_password)"
    
    echo ""
    log_info "=== Query Layer ==="
    create_secret_file "clickhouse_password" "$(generate_password)"
    
    echo ""
    log_success "All secrets generated successfully!"
    echo ""
    
    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 SECRETS SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Secrets Directory: ${SECRETS_DIR}"
    echo "Total Secrets: $(find "${SECRETS_DIR}" -type f | wc -l | tr -d ' ')"
    echo "Permissions: 600 (owner read/write only)"
    echo ""
    echo "Generated Secrets:"
    ls -1 "${SECRETS_DIR}" | sed 's/^/  • /'
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_warning "SECURITY NOTE:"
    echo "  • Secrets are stored in: ${SECRETS_DIR}"
    echo "  • This directory is in .gitignore"
    echo "  • Never commit secrets to version control"
    echo "  • Back up secrets securely"
    echo "  • Rotate secrets regularly"
    echo ""
    log_success "Secrets generation complete!"
    echo ""
}

# Execute
main "$@"

