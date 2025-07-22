#!/bin/bash
# Configuration Management Script for ShuDL
# This script helps manage environment variables and configuration templates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE_FILE="$SCRIPT_DIR/.env.example"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if .env file exists
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found"
        return 1
    fi
    return 0
}

# Function to validate environment variables
validate_env_vars() {
    print_header "Validating Environment Variables"
    
    if ! check_env_file; then
        print_error "Please create .env file first: cp .env.example .env"
        return 1
    fi
    
    # Source the .env file
    source "$ENV_FILE"
    
    local missing_vars=()
    local weak_passwords=()
    
    # Check required variables
    [ -z "$POSTGRES_PASSWORD" ] && missing_vars+=("POSTGRES_PASSWORD")
    [ -z "$MINIO_ROOT_PASSWORD" ] && missing_vars+=("MINIO_ROOT_PASSWORD")
    [ -z "$S3_SECRET_KEY" ] && missing_vars+=("S3_SECRET_KEY")
    [ -z "$QUARKUS_DATASOURCE_PASSWORD" ] && missing_vars+=("QUARKUS_DATASOURCE_PASSWORD")
    
    # Check for weak passwords
    [ "$POSTGRES_PASSWORD" = "CHANGE_ME_SECURE_PASSWORD" ] && weak_passwords+=("POSTGRES_PASSWORD")
    [ "$MINIO_ROOT_PASSWORD" = "CHANGE_ME_SECURE_PASSWORD" ] && weak_passwords+=("MINIO_ROOT_PASSWORD")
    [ "$S3_SECRET_KEY" = "CHANGE_ME_SECURE_PASSWORD" ] && weak_passwords+=("S3_SECRET_KEY")
    
    # Report missing variables
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        printf '  %s\n' "${missing_vars[@]}"
        return 1
    fi
    
    # Report weak passwords
    if [ ${#weak_passwords[@]} -gt 0 ]; then
        print_warning "Default passwords detected (should be changed for production):"
        printf '  %s\n' "${weak_passwords[@]}"
    fi
    
    print_status "Environment validation completed"
    return 0
}

# Function to generate secure passwords
generate_passwords() {
    print_header "Generating Secure Passwords"
    
    # Generate random passwords
    local postgres_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local minio_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    print_status "Generated secure passwords:"
    echo "POSTGRES_PASSWORD=$postgres_password"
    echo "MINIO_ROOT_PASSWORD=$minio_password"
    echo "S3_SECRET_KEY=$minio_password"
    echo "QUARKUS_DATASOURCE_PASSWORD=$postgres_password"
    echo ""
    print_warning "Please update your .env file with these passwords"
}

# Function to setup initial configuration
setup() {
    print_header "Setting up ShuDL Configuration"
    
    # Copy .env.example to .env if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_EXAMPLE_FILE" ]; then
            cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
            print_status "Created .env file from template"
        else
            print_error ".env.example file not found"
            return 1
        fi
    else
        print_status ".env file already exists"
    fi
    
    # Generate secure passwords
    generate_passwords
    
    print_status "Setup completed! Next steps:"
    echo "1. Edit .env file with secure passwords"
    echo "2. Run: ./configure.sh validate"
    echo "3. Run: docker compose up -d"
}

# Function to test configuration
test_config() {
    print_header "Testing Configuration"
    
    # Validate docker-compose.yml
    print_status "Validating docker-compose.yml..."
    if docker compose config --quiet; then
        print_status "docker-compose.yml is valid"
    else
        print_error "docker-compose.yml validation failed"
        return 1
    fi
    
    # Validate environment variables
    validate_env_vars
    
    print_status "Configuration test completed successfully"
}

# Function to show current configuration
show_config() {
    print_header "Current Configuration"
    
    if ! check_env_file; then
        print_error "No .env file found. Run: ./configure.sh setup"
        return 1
    fi
    
    source "$ENV_FILE"
    
    echo "Database Configuration:"
    echo "  POSTGRES_DB: $POSTGRES_DB"
    echo "  POSTGRES_USER: $POSTGRES_USER"
    echo "  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:0:4}****"
    echo ""
    echo "MinIO Configuration:"
    echo "  MINIO_ROOT_USER: $MINIO_ROOT_USER"
    echo "  MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:0:4}****"
    echo "  MINIO_REGION: $MINIO_REGION"
    echo ""
    echo "Service Endpoints:"
    echo "  S3_ENDPOINT: $S3_ENDPOINT"
    echo "  NESSIE_URI: $NESSIE_URI"
    echo "  WAREHOUSE_LOCATION: $WAREHOUSE_LOCATION"
    echo ""
    echo "Spark Configuration:"
    echo "  SPARK_MASTER_URL: $SPARK_MASTER_URL"
    echo "  SPARK_WORKER_MEMORY: $SPARK_WORKER_MEMORY"
    echo "  SPARK_WORKER_CORES: $SPARK_WORKER_CORES"
}

# Function to show help
show_help() {
    cat << EOF
ShuDL Configuration Management Script

Usage: $0 [COMMAND]

Commands:
  setup       Initialize configuration from template
  validate    Validate current environment variables
  test        Test complete configuration (docker-compose + env vars)
  show        Display current configuration (passwords masked)
  generate    Generate secure passwords
  help        Show this help message

Examples:
  $0 setup        # First time setup
  $0 validate     # Check if all required variables are set
  $0 test         # Full configuration test
  $0 show         # Show current config

EOF
}

# Main command handling
case "${1:-help}" in
    "setup")
        setup
        ;;
    "validate")
        validate_env_vars
        ;;
    "test")
        test_config
        ;;
    "show")
        show_config
        ;;
    "generate")
        generate_passwords
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
