#!/bin/bash
# Datalyptica Development Environment Initialization Script
# Orchestrates initialization of databases, buckets, topics, and service verification
# Following Single Responsibility Principle - delegates to atomic scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "======================================"
echo "Datalyptica Dev Environment Initialization"
echo "======================================"
echo ""

# Step 1: Initialize PostgreSQL databases
echo "Step 1: Initializing PostgreSQL databases..."
echo "--------------------------------------"
if "${SCRIPT_DIR}/init-databases.sh"; then
    echo -e "${GREEN}✓${NC} Database initialization complete"
else
    echo -e "${RED}✗${NC} Database initialization failed"
    exit 1
fi

echo ""

# Step 2: Initialize MinIO buckets
echo "Step 2: Initializing MinIO buckets..."
echo "--------------------------------------"
if "${SCRIPT_DIR}/init-minio-buckets.sh"; then
    echo -e "${GREEN}✓${NC} MinIO bucket initialization complete"
else
    echo -e "${RED}✗${NC} MinIO bucket initialization failed"
    exit 1
fi

echo ""

# Step 3: Initialize Kafka topics
echo "Step 3: Initializing Kafka topics..."
echo "--------------------------------------"
if "${SCRIPT_DIR}/init-kafka-topics.sh"; then
    echo -e "${GREEN}✓${NC} Kafka topics initialization complete"
else
    echo -e "${RED}✗${NC} Kafka topics initialization failed"
    exit 1
fi

echo ""

# Step 4: Verify all services
echo "Step 4: Verifying services..."
echo "--------------------------------------"
if "${SCRIPT_DIR}/verify-services.sh"; then
    echo -e "${GREEN}✓${NC} Service verification complete"
else
    echo -e "${RED}✗${NC} Service verification completed with warnings"
fi

echo ""
echo "======================================"
echo -e "${GREEN}Initialization Complete!${NC}"
echo "======================================"
echo ""
echo "Individual scripts can be run separately:"
echo "  - ${SCRIPT_DIR}/init-databases.sh"
echo "  - ${SCRIPT_DIR}/init-minio-buckets.sh"
echo "  - ${SCRIPT_DIR}/init-kafka-topics.sh"
echo "  - ${SCRIPT_DIR}/verify-services.sh"
echo ""
