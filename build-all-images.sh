#!/bin/bash

# Build All ShuDL Images Script
# This script builds all Docker images in the correct dependency order

set -e

REGISTRY="ghcr.io/shugur-network"
REPO_NAME="shudl"

echo "🔨 Building all ShuDL Docker images..."
echo "Registry: $REGISTRY/$REPO_NAME"
echo ""

# Base images first (no dependencies)
echo "📦 Building base images..."
echo "  🏔️  Building base-alpine..."
docker build -t $REGISTRY/$REPO_NAME/base-alpine:latest docker/base/alpine/

echo "  ☕ Building base-java..."
docker build -t $REGISTRY/$REPO_NAME/base-java:latest docker/base/java/

echo "  🐘 Building base-postgresql..."
docker build -t $REGISTRY/$REPO_NAME/base-postgresql:latest docker/base/postgresql/

echo ""

# Service images (depend on base images)
echo "🚀 Building service images..."
echo "  📦 Building minio..."
docker build -t $REGISTRY/$REPO_NAME/minio:latest docker/services/minio/

# PostgreSQL services image removed - using base-postgresql directly

echo "  🔄 Building patroni..."
docker build -t $REGISTRY/$REPO_NAME/patroni:latest docker/services/patroni/

echo "  📊 Building nessie..."
docker build -t $REGISTRY/$REPO_NAME/nessie:latest docker/services/nessie/

echo "  🔍 Building trino..."
docker build -t $REGISTRY/$REPO_NAME/trino:latest docker/services/trino/

echo "  ⚡ Building spark..."
docker build -t $REGISTRY/$REPO_NAME/spark:latest docker/services/spark/

echo ""
echo "✅ All images built successfully!"
echo ""
echo "🚀 To push all images to registry, run:"
echo "   docker push $REGISTRY/$REPO_NAME/base-alpine:latest"
echo "   docker push $REGISTRY/$REPO_NAME/base-java:latest"
echo "   docker push $REGISTRY/$REPO_NAME/base-postgresql:latest"
echo "   docker push $REGISTRY/$REPO_NAME/minio:latest"
echo "   docker push $REGISTRY/$REPO_NAME/postgresql:latest"
echo "   docker push $REGISTRY/$REPO_NAME/patroni:latest"
echo "   docker push $REGISTRY/$REPO_NAME/nessie:latest"
echo "   docker push $REGISTRY/$REPO_NAME/trino:latest"
echo "   docker push $REGISTRY/$REPO_NAME/spark:latest"
echo ""
echo "📋 To see all built images:"
echo "   docker images | grep $REGISTRY/$REPO_NAME"
