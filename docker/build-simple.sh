#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

REGISTRY="ghcr.io/shugur-network/shudl"
TAG="latest"

echo -e "${GREEN}Building Lakehouse Docker Images with shusr user${NC}"

# Function to build image
build_image() {
    local context=$1
    local name=$2
    local dockerfile=$3
    
    echo -e "${GREEN}Building $name...${NC}"
    docker build -t "$REGISTRY/$name:$TAG" -f "$dockerfile" "$
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $name built successfully${NC}"
    else
        echo -e "${RED}❌ Failed to build $name${NC}"
        exit 1
    fi
    echo ""
}

# Build base images first
echo "Building base images..."
cd /home/ubuntu/shudl

build_image "docker/base/alpine" "base-alpine" "docker/base/alpine/Dockerfile"
build_image "docker/base/java" "base-java" "docker/base/java/Dockerfile"
build_image "docker/base/postgresql" "base-postgresql" "docker/base/postgresql/Dockerfile"

# Build service images
echo "Building service images..."
build_image "docker/services/minio" "minio" "docker/services/minio/Dockerfile"
# PostgreSQL services image removed - using base-postgresql directly
build_image "docker/services/patroni" "patroni" "docker/services/patroni/Dockerfile"
build_image "docker/services/nessie" "nessie" "docker/services/nessie/Dockerfile"
build_image "docker/services/trino" "trino" "docker/services/trino/Dockerfile"
build_image "docker/services/spark" "spark" "docker/services/spark/Dockerfile"

echo -e "${GREEN}🎉 All images built successfully!${NC}"

# List built images
echo ""
echo "Built images:"
docker images | grep "ghcr.io/shugur-network/shudl"
