#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io/shugur-network/shudl"
TAG="${1:-latest}"

echo -e "${GREEN}🚀 Pushing Lakehouse Docker Images to GitHub Container Registry${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo ""

# Function to push image
push_image() {
    local name=$1
    local image_name="$REGISTRY/$name:$TAG"
    
    echo -e "${YELLOW}📤 Pushing $name...${NC}"
    
    # Check if image exists locally
    if ! docker image inspect "$image_name" >/dev/null 2>&1; then
        echo -e "${RED}❌ Image $image_name not found locally. Please build it first.${NC}"
        return 1
    fi
    
    # Push the image
    if docker push "$image_name"; then
        echo -e "${GREEN}✅ $name pushed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to push $name${NC}"
        return 1
    fi
    echo ""
}

# Check if logged in to GitHub Container Registry
echo -e "${BLUE}🔐 Checking GitHub Container Registry authentication...${NC}"
if ! docker info | grep -q "ghcr.io"; then
    echo -e "${YELLOW}⚠️  You may need to log in to GitHub Container Registry first:${NC}"
    echo "   echo \$GITHUB_TOKEN | docker login ghcr.io -u <USERNAME> --password-stdin"
    echo ""
fi

# Push base images first
echo -e "${GREEN}📦 Pushing Base Images...${NC}"
push_image "base-alpine"
push_image "base-java"
push_image "base-postgresql"

# Push service images
echo -e "${GREEN}🚢 Pushing Service Images...${NC}"
push_image "minio"
push_image "postgresql"
push_image "patroni"
push_image "nessie"
push_image "trino"
push_image "spark"

echo -e "${GREEN}🎉 All images pushed successfully!${NC}"
echo ""
echo "Pushed images:"
echo "  - $REGISTRY/base-alpine:$TAG"
echo "  - $REGISTRY/base-java:$TAG"
echo "  - $REGISTRY/base-postgresql:$TAG"
echo "  - $REGISTRY/minio:$TAG"
echo "  - $REGISTRY/postgresql:$TAG"
echo "  - $REGISTRY/patroni:$TAG"
echo "  - $REGISTRY/nessie:$TAG"
echo "  - $REGISTRY/trino:$TAG"
echo "  - $REGISTRY/spark:$TAG"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Update docker-compose.yml or Helm charts to use the new images"
echo "2. Test the updated stack with: docker-compose up -d"
echo "3. Run integration tests: ./tmp/run_all_tests.sh"
