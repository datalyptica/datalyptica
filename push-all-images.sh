#!/bin/bash

# Push All ShuDL Images Script
# This script pushes all Docker images to the registry

set -e

REGISTRY="ghcr.io/shugur-network"
REPO_NAME="shudl"

echo "🚀 Pushing all ShuDL Docker images to $REGISTRY/$REPO_NAME..."
echo ""

# Check if user is logged in to registry
echo "🔐 Checking registry authentication..."
if ! docker pull $REGISTRY/hello-world:latest &>/dev/null; then
    echo "❌ Not authenticated to $REGISTRY"
    echo "Please login first:"
    echo "   docker login $REGISTRY"
    echo "   # Use your GitHub token as password"
    exit 1
fi

echo "✅ Registry authentication confirmed"
echo ""

# Push in dependency order
echo "📦 Pushing base images..."
docker push $REGISTRY/$REPO_NAME/base-alpine:latest
docker push $REGISTRY/$REPO_NAME/base-java:latest
docker push $REGISTRY/$REPO_NAME/base-postgresql:latest

echo ""
echo "🚀 Pushing service images..."
docker push $REGISTRY/$REPO_NAME/minio:latest
docker push $REGISTRY/$REPO_NAME/postgresql:latest
docker push $REGISTRY/$REPO_NAME/patroni:latest
docker push $REGISTRY/$REPO_NAME/nessie:latest
docker push $REGISTRY/$REPO_NAME/trino:latest
docker push $REGISTRY/$REPO_NAME/spark:latest

echo ""
echo "✅ All images pushed successfully!"
echo ""
echo "🌐 Images are now available at:"
echo "   https://github.com/orgs/Shugur-Network/packages?repo_name=shudl"
