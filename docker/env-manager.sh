#!/bin/bash
# ShuDL Environment Manager
# Manages environment configuration for different deployment scenarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    local level=$1
    local message=$2
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
}

# Function to show usage
show_usage() {
    cat << EOF
ShuDL Environment Manager

Usage: $0 <command> [options]

Commands:
    setup <env>     Setup environment configuration (dev|prod|custom)
    validate        Validate current .env configuration
    show            Show current environment settings
    backup          Backup current .env to .env.backup
    restore         Restore .env from .env.backup

Examples:
    $0 setup dev           # Setup development environment
    $0 setup prod          # Setup production environment  
    $0 setup custom        # Setup custom environment (interactive)
    $0 validate            # Validate current configuration
    $0 show                # Show current settings
    
Environment Files:
    .env                   # Active configuration
    .env.dev              # Development template
    .env.prod             # Production template
    .env.backup           # Backup of previous configuration

EOF
}

# Function to setup environment
setup_env() {
    local env_type=$1
    
    case $env_type in
        "dev")
            if [[ -f "${ENV_DIR}/.env.dev" ]]; then
                log "INFO" "Setting up development environment..."
                cp "${ENV_DIR}/.env.dev" "${ENV_DIR}/.env"
                log "INFO" "Development environment configured. Review .env file before starting services."
            else
                log "ERROR" "Development template (.env.dev) not found!"
                exit 1
            fi
            ;;
        "prod")
            if [[ -f "${ENV_DIR}/.env.prod" ]]; then
                log "INFO" "Setting up production environment..."
                cp "${ENV_DIR}/.env.prod" "${ENV_DIR}/.env"
                log "WARN" "IMPORTANT: Update credentials in .env before starting services!"
                log "WARN" "Change all CHANGE_ME_* values to secure passwords!"
            else
                log "ERROR" "Production template (.env.prod) not found!"
                exit 1
            fi
            ;;
        "custom")
            log "INFO" "Setting up custom environment..."
            if [[ -f "${ENV_DIR}/.env" ]]; then
                log "WARN" "Existing .env file found. Creating backup..."
                cp "${ENV_DIR}/.env" "${ENV_DIR}/.env.backup"
            fi
            
            # Interactive setup
            setup_custom_env
            ;;
        *)
            log "ERROR" "Invalid environment type: $env_type"
            log "INFO" "Valid options: dev, prod, custom"
            exit 1
            ;;
    esac
}

# Function to setup custom environment interactively
setup_custom_env() {
    log "INFO" "Interactive environment setup..."
    
    # Start with base template
    cp "${ENV_DIR}/.env" "${ENV_DIR}/.env.new" 2>/dev/null || {
        log "ERROR" "Base .env template not found!"
        exit 1
    }
    
    # Prompt for basic settings
    read -p "Project name [shudl]: " project_name
    project_name=${project_name:-shudl}
    
    read -p "PostgreSQL password [nessie123]: " postgres_password  
    postgres_password=${postgres_password:-nessie123}
    
    read -p "MinIO password [password123]: " minio_password
    minio_password=${minio_password:-password123}
    
    # Update the new env file
    sed -i "s/COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=${project_name}/" "${ENV_DIR}/.env.new"
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${postgres_password}/" "${ENV_DIR}/.env.new"
    sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=${minio_password}/" "${ENV_DIR}/.env.new"
    sed -i "s/S3_SECRET_KEY=.*/S3_SECRET_KEY=${minio_password}/" "${ENV_DIR}/.env.new"
    
    mv "${ENV_DIR}/.env.new" "${ENV_DIR}/.env"
    log "INFO" "Custom environment configured successfully!"
}

# Function to validate environment
validate_env() {
    if [[ ! -f "${ENV_DIR}/.env" ]]; then
        log "ERROR" ".env file not found! Run setup first."
        exit 1
    fi
    
    log "INFO" "Validating environment configuration..."
    
    # Check for required variables
    local required_vars=(
        "COMPOSE_PROJECT_NAME"
        "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD"
        "MINIO_ROOT_USER" "MINIO_ROOT_PASSWORD"
        "S3_ACCESS_KEY" "S3_SECRET_KEY"
        "NESSIE_PORT" "TRINO_PORT" "SPARK_MASTER_PORT"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "${ENV_DIR}/.env"; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "ERROR" "Missing required variables:"
        for var in "${missing_vars[@]}"; do
            log "ERROR" "  - $var"
        done
        exit 1
    fi
    
    # Check for insecure defaults in what appears to be production
    if grep -q "COMPOSE_PROJECT_NAME=.*prod" "${ENV_DIR}/.env"; then
        local insecure_patterns=(
            "CHANGE_ME"
            "password123"
            "admin"
        )
        
        for pattern in "${insecure_patterns[@]}"; do
            if grep -q "$pattern" "${ENV_DIR}/.env"; then
                log "WARN" "Potentially insecure value found: $pattern"
            fi
        done
    fi
    
    log "INFO" "Environment validation completed!"
}

# Function to show current environment
show_env() {
    if [[ ! -f "${ENV_DIR}/.env" ]]; then
        log "ERROR" ".env file not found!"
        exit 1
    fi
    
    log "INFO" "Current environment configuration:"
    echo
    
    # Show key configuration values (hide sensitive ones)
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*# ]] || [[ -z $line ]]; then
            continue
        fi
        
        if [[ $line =~ PASSWORD|SECRET|KEY ]]; then
            # Hide sensitive values
            echo "$line" | sed 's/=.*/=***HIDDEN***/'
        else
            echo "$line"
        fi
    done < "${ENV_DIR}/.env"
}

# Function to backup environment
backup_env() {
    if [[ ! -f "${ENV_DIR}/.env" ]]; then
        log "ERROR" ".env file not found!"
        exit 1
    fi
    
    cp "${ENV_DIR}/.env" "${ENV_DIR}/.env.backup"
    log "INFO" "Environment backed up to .env.backup"
}

# Function to restore environment
restore_env() {
    if [[ ! -f "${ENV_DIR}/.env.backup" ]]; then
        log "ERROR" ".env.backup file not found!"
        exit 1
    fi
    
    cp "${ENV_DIR}/.env.backup" "${ENV_DIR}/.env"
    log "INFO" "Environment restored from .env.backup"
}

# Main execution
case ${1:-""} in
    "setup")
        if [[ -z ${2:-""} ]]; then
            log "ERROR" "Environment type required for setup command"
            show_usage
            exit 1
        fi
        setup_env "$2"
        ;;
    "validate")
        validate_env
        ;;
    "show")
        show_env
        ;;
    "backup")
        backup_env
        ;;
    "restore")
        restore_env
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        log "ERROR" "Invalid command: ${1:-""}"
        show_usage
        exit 1
        ;;
esac
