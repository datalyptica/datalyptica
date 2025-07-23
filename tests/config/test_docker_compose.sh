#!/bin/bash

# Test: Docker Compose Validation
# Validates the docker-compose.yml configuration

set -euo pipefail

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_start "Docker Compose Validation"

cd "${SCRIPT_DIR}/../../"

test_step "Checking docker/docker-compose.yml exists..."
if [[ ! -f "docker/docker-compose.yml" ]]; then
    test_error "docker/docker-compose.yml file not found"
    exit 1
fi

test_step "Validating docker-compose.yml syntax..."
if ! docker compose -f docker/docker-compose.yml config > /dev/null 2>&1; then
    test_error "docker-compose.yml has syntax errors"
    docker compose -f docker/docker-compose.yml config
    exit 1
fi

test_step "Checking required services..."
required_services=("postgresql" "minio" "nessie" "trino" "spark-master" "spark-worker")
for service in "${required_services[@]}"; do
    if ! docker compose -f docker/docker-compose.yml config --services | grep -q "^${service}$"; then
        test_error "Required service '$service' not found in docker-compose.yml"
        exit 1
    else
        test_info "✓ Service '$service' found"
    fi
done

test_step "Validating service dependencies..."
# Check that services have proper dependencies
if ! docker compose -f docker/docker-compose.yml config | grep -A 20 "trino:" | grep -q "depends_on:"; then
    test_warning "Trino service should have dependencies defined"
fi

if ! docker compose -f docker/docker-compose.yml config | grep -A 20 "spark-master:" | grep -q "depends_on:"; then
    test_warning "Spark master service should have dependencies defined"
fi

test_step "Checking network configuration..."
if ! docker compose -f docker/docker-compose.yml config | grep -q "networks:"; then
    test_error "No networks defined in docker-compose.yml"
    exit 1
fi

test_step "Validating health checks..."
services_with_healthchecks=("postgresql" "minio" "nessie" "trino" "spark-master" "spark-worker")
for service in "${services_with_healthchecks[@]}"; do
    if docker compose -f docker/docker-compose.yml config | grep -A 50 "${service}:" | grep -q "healthcheck:"; then
        test_info "✓ Service '$service' has health check configured"
    else
        test_warning "Service '$service' missing health check configuration"
    fi
done

test_step "Checking volume mounts..."
# Ensure data persistence for stateful services
if ! docker compose -f docker/docker-compose.yml config | grep -A 20 "postgresql:" | grep -q "volumes:"; then
    test_warning "PostgreSQL should have volume mounts for data persistence"
fi

if ! docker compose -f docker/docker-compose.yml config | grep -A 20 "minio:" | grep -q "volumes:"; then
    test_warning "MinIO should have volume mounts for data persistence"
fi

test_step "Validating environment variables mapping..."
# Check that environment variables are properly mapped from .env
critical_env_mappings=(
    "POSTGRES_PASSWORD"
    "MINIO_ROOT_PASSWORD"
    "TRINO_PORT"
    "SPARK_MASTER_PORT"
)

for env_var in "${critical_env_mappings[@]}"; do
    if docker compose -f docker/docker-compose.yml config | grep -q "\${${env_var}}"; then
        test_info "✓ Environment variable '$env_var' is properly mapped"
    else
        test_warning "Environment variable '$env_var' may not be properly mapped"
    fi
done

test_success "Docker Compose configuration is valid" 

# Test completed 