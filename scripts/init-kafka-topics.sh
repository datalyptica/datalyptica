#!/bin/bash
# Initialize Kafka topics for Datalyptica
# Single Responsibility: Kafka topic creation only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment variables
if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
    source "${PROJECT_ROOT}/docker/.env"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-datalyptica}
PREFIX=${COMPOSE_PROJECT_NAME}

echo "======================================"
echo "Kafka Topics Initialization"
echo "======================================"
echo ""

# Check if Kafka container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${PREFIX}-kafka$"; then
    echo -e "${RED}ERROR: ${PREFIX}-kafka container is not running${NC}"
    echo "Please start the stack first: cd docker && docker compose up -d"
    exit 1
fi

echo "Listing current Kafka topics..."

# List existing topics
if docker exec ${PREFIX}-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Kafka topics retrieved successfully"
else
    echo -e "${YELLOW}!${NC} Could not list Kafka topics (broker may still be initializing)"
fi

# Create example topics if needed
# Uncomment and customize as needed for your use case
# echo ""
# echo "Creating example topics..."
# docker exec ${PREFIX}-kafka kafka-topics --bootstrap-server localhost:9092 \
#     --create --topic test-topic --partitions 3 --replication-factor 1 \
#     --if-not-exists 2>/dev/null || echo "Topic already exists: test-topic"

echo ""
echo -e "${GREEN}Kafka topics initialization complete!${NC}"
echo ""
echo "To create a new topic, use:"
echo "  docker exec ${PREFIX}-kafka kafka-topics --bootstrap-server localhost:9092 \\"
echo "    --create --topic <topic-name> --partitions 3 --replication-factor 1"
echo ""
echo "Access Kafka UI: http://localhost:8090"
echo ""
