#!/bin/bash
# ShuDL Configuration Test Script
# Validates the environment-based configuration setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Test Docker Compose configuration
test_docker_compose_config() {
    log "INFO" "Testing Docker Compose configuration..."
    
    if ! command -v docker &> /dev/null; then
        log "ERROR" "docker not found!"
        return 1
    fi
    
    # Test configuration parsing
    if docker compose config > /dev/null 2>&1; then
        log "INFO" "✓ Docker Compose configuration is valid"
    else
        log "ERROR" "✗ Docker Compose configuration is invalid"
        docker compose config
        return 1
    fi
    
    # Check for environment variable substitution
    local missing_vars=()
    while IFS= read -r line; do
        if [[ $line =~ \$\{([^}]+)\} ]]; then
            local var_name="${BASH_REMATCH[1]}"
            if ! grep -q "^${var_name}=" "$ENV_FILE" 2>/dev/null; then
                missing_vars+=("$var_name")
            fi
        fi
    done < <(docker compose config 2>/dev/null || echo "")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "WARN" "Potentially missing environment variables:"
        for var in "${missing_vars[@]}"; do
            log "WARN" "  - $var"
        done
    fi
}

# Test environment file
test_env_file() {
    log "INFO" "Testing environment file..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log "ERROR" ".env file not found!"
        log "INFO" "Run: ./env-manager.sh setup dev"
        return 1
    fi
    
    # Check for required sections
    local required_sections=(
        "Global Configuration"
        "PostgreSQL Configuration"
        "MinIO Object Storage"
        "Nessie Catalog"
        "Trino Query Engine"
        "Spark Compute Engine"
    )
    
    for section in "${required_sections[@]}"; do
        if grep -q "$section" "$ENV_FILE"; then
            log "INFO" "✓ Found section: $section"
        else
            log "WARN" "✗ Missing section: $section"
        fi
    done
    
    # Check for critical variables
    local critical_vars=(
        "COMPOSE_PROJECT_NAME"
        "POSTGRES_PASSWORD"
        "MINIO_ROOT_PASSWORD"
        "S3_SECRET_KEY"
    )
    
    for var in "${critical_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE"; then
            log "INFO" "✓ Found critical variable: $var"
        else
            log "ERROR" "✗ Missing critical variable: $var"
        fi
    done
}

# Test service connectivity configuration
test_service_connectivity() {
    log "INFO" "Testing service connectivity configuration..."
    
    # Check if all service references are consistent
    local services=("postgresql" "minio" "nessie" "trino" "spark-master" "spark-worker")
    
    for service in "${services[@]}"; do
        log "DEBUG" "Checking $service configuration..."
        
        # This would be expanded to check specific connectivity patterns
        # For now, just verify the service is defined in docker-compose.yml
        if grep -q "^  $service:" "$COMPOSE_FILE"; then
            log "INFO" "✓ Service $service is defined"
        else
            log "ERROR" "✗ Service $service is not defined"
        fi
    done
}

# Test port configuration
test_port_configuration() {
    log "INFO" "Testing port configuration..."
    
    # Extract ports from docker-compose and check for conflicts
    local ports=($(docker compose config 2>/dev/null | grep -E '^\s+- "\d+:\d+"' | sed 's/.*"\([0-9]*\):.*/\1/' | sort -n))
    local unique_ports=($(echo "${ports[@]}" | tr ' ' '\n' | sort -nu))
    
    if [[ ${#ports[@]} -eq ${#unique_ports[@]} ]]; then
        log "INFO" "✓ No port conflicts detected"
    else
        log "ERROR" "✗ Port conflicts detected!"
        log "ERROR" "Ports: ${ports[*]}"
        log "ERROR" "Unique: ${unique_ports[*]}"
    fi
    
    # Check for common port conflicts
    local common_ports=(80 443 22 25 53 110 143 993 995)
    for port in "${ports[@]}"; do
        for common_port in "${common_ports[@]}"; do
            if [[ "$port" == "$common_port" ]]; then
                log "WARN" "Port $port might conflict with system services"
            fi
        done
    done
}

# Generate configuration summary
generate_summary() {
    log "INFO" "Configuration Summary:"
    echo
    
    if [[ -f "$ENV_FILE" ]]; then
        local project_name=$(grep "^COMPOSE_PROJECT_NAME=" "$ENV_FILE" | cut -d'=' -f2)
        local postgres_port=$(grep "^POSTGRES_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        local minio_api_port=$(grep "^MINIO_API_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        local nessie_port=$(grep "^NESSIE_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        local trino_port=$(grep "^TRINO_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        
        echo "Project Name: $project_name"
        echo "PostgreSQL: localhost:$postgres_port"
        echo "MinIO API: localhost:$minio_api_port"
        echo "MinIO Console: localhost:$(grep "^MINIO_CONSOLE_PORT=" "$ENV_FILE" | cut -d'=' -f2)"
        echo "Nessie: localhost:$nessie_port"
        echo "Trino: localhost:$trino_port"
        echo "Spark UI: localhost:$(grep "^SPARK_UI_PORT=" "$ENV_FILE" | cut -d'=' -f2)"
        echo
        
        echo "Service URLs:"
        echo "- MinIO Console: http://localhost:$(grep "^MINIO_CONSOLE_PORT=" "$ENV_FILE" | cut -d'=' -f2)"
        echo "- Nessie API: http://localhost:$nessie_port/api/v2"
        echo "- Trino UI: http://localhost:$trino_port"
        echo "- Spark UI: http://localhost:$(grep "^SPARK_UI_PORT=" "$ENV_FILE" | cut -d'=' -f2)"
    fi
}

# Main test execution
main() {
    log "INFO" "Starting ShuDL Configuration Tests..."
    echo
    
    local test_functions=(
        "test_env_file"
        "test_docker_compose_config"
        "test_service_connectivity"
        "test_port_configuration"
    )
    
    local failed_tests=0
    
    for test_func in "${test_functions[@]}"; do
        echo
        if $test_func; then
            log "INFO" "✓ $test_func passed"
        else
            log "ERROR" "✗ $test_func failed"
            ((failed_tests++))
        fi
    done
    
    echo
    if [[ $failed_tests -eq 0 ]]; then
        log "INFO" "All tests passed! Configuration looks good."
        echo
        generate_summary
    else
        log "ERROR" "$failed_tests test(s) failed. Please review the configuration."
        exit 1
    fi
}

# Check if running with specific test
if [[ $# -gt 0 ]]; then
    case $1 in
        "env") test_env_file ;;
        "compose") test_docker_compose_config ;;
        "connectivity") test_service_connectivity ;;
        "ports") test_port_configuration ;;
        "summary") generate_summary ;;
        *) 
            log "ERROR" "Unknown test: $1"
            log "INFO" "Available tests: env, compose, connectivity, ports, summary"
            exit 1
            ;;
    esac
else
    main
fi
