#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io/shugur-network/shudl"
TAG="${1:-latest}"
PLATFORMS="${2:-linux/amd64,linux/arm64}"

echo -e "${GREEN}🏗️  Building Lakehouse Docker Images${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Platforms: $PLATFORMS"
echo ""

# Function to build image
build_image() {
    local context=$1
    local name=$2
    local dockerfile=$3
    
    echo -e "${YELLOW}📦 Building $name for $PLATFORMS...${NC}"
    docker buildx build \
        --platform "$PLATFORMS" \
        --push \
        -t "$REGISTRY/$name:$TAG" \
        -f "$dockerfile" \
        "$context"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $name built and pushed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to build $name${NC}"
        exit 1
    fi
    echo ""
}

# Build service images  
echo -e "${GREEN}🏗️  Building Service Images...${NC}"
build_image "." "postgresql" "services/postgresql/Dockerfile"
build_image "." "minio" "services/minio/Dockerfile"
build_image "." "patroni" "services/patroni/Dockerfile"
build_image "." "nessie" "services/nessie/Dockerfile"
build_image "." "trino" "services/trino/Dockerfile"
build_image "." "spark" "services/spark/Dockerfile"

echo -e "${GREEN}🎉 All images built and pushed successfully!${NC}"
echo ""
echo "Images built and pushed to registry:"
echo "  - $REGISTRY/postgresql:$TAG"
echo "  - $REGISTRY/minio:$TAG"
echo "  - $REGISTRY/patroni:$TAG"
echo "  - $REGISTRY/nessie:$TAG"
echo "  - $REGISTRY/trino:$TAG"
echo "  - $REGISTRY/spark:$TAG"
echo ""
echo "Platforms: $PLATFORMS" 