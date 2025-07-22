#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REGISTRY="ghcr.io/shugur-network/shudl"
TAG="latest"

echo -e "${BLUE}📊 ShuDL Docker Images Status Check${NC}"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo ""

# Array of all images that should be built
declare -a IMAGES=(
    "base-alpine"
    "base-java" 
    "base-postgresql"
    "minio"
    "postgresql"
    "patroni"
    "nessie"
    "trino"
    "spark"
)

echo -e "${YELLOW}🔍 Checking locally built images...${NC}"
echo ""

built_count=0
missing_images=()

for image in "${IMAGES[@]}"; do
    image_name="$REGISTRY/$image:$TAG"
    if docker image inspect "$image_name" >/dev/null 2>&1; then
        size=$(docker image inspect "$image_name" --format='{{.Size}}' | numfmt --to=iec)
        created=$(docker image inspect "$image_name" --format='{{.Created}}' | cut -d'T' -f1)
        echo -e "${GREEN}✅ $image${NC} (${size}, created: ${created})"
        ((built_count++))
    else
        echo -e "${RED}❌ $image${NC} (not found)"
        missing_images+=("$image")
    fi
done

echo ""
echo -e "${BLUE}📈 Summary:${NC}"
echo "  Built: $built_count/${#IMAGES[@]} images"

if [ $built_count -eq ${#IMAGES[@]} ]; then
    echo -e "${GREEN}🎉 All images are built and ready for pushing!${NC}"
    echo ""
    echo -e "${YELLOW}🚀 To push all images to GitHub Container Registry:${NC}"
    echo ""
    echo "1. First, log in to GitHub Container Registry:"
    echo "   ${BLUE}echo \$GITHUB_TOKEN | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin${NC}"
    echo ""
    echo "2. Then push all images:"
    echo "   ${BLUE}./docker/push.sh${NC}"
    echo ""
    echo "3. Or push individually:"
    for image in "${IMAGES[@]}"; do
        echo "   docker push $REGISTRY/$image:$TAG"
    done
else
    echo -e "${YELLOW}⚠️  Some images are missing. You may need to complete the build process.${NC}"
    echo ""
    if [ ${#missing_images[@]} -gt 0 ]; then
        echo "Missing images:"
        for image in "${missing_images[@]}"; do
            echo "  - $image"
        done
        echo ""
    fi
    echo "To build missing images:"
    echo "  ${BLUE}./docker/build-simple.sh${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Useful commands:${NC}"
echo "  Check build status:     ./docker/status.sh"
echo "  Build all images:       ./docker/build-simple.sh"
echo "  Push all images:        ./docker/push.sh"
echo "  List local images:      docker images | grep '$REGISTRY'"
echo "  Clean up images:        docker system prune -f"
