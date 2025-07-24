#!/bin/bash
set -e

# Build All ShuDL Images Locally
# This script builds all Docker images locally with the correct tags for docker-compose.yml

REGISTRY="ghcr.io/shugur-network/shudl"

echo "🔨 Building all ShuDL Docker images locally..."
echo "Registry tags: $REGISTRY"
echo ""

# Build service images
echo "🚀 Building service images..."

echo "  📦 Building minio..."
docker build -t $REGISTRY/minio:latest -f services/minio/Dockerfile .

echo "  🐘 Building postgresql..."
docker build -t $REGISTRY/postgresql:latest -f services/postgresql/Dockerfile .

echo "  🔄 Building patroni..."
docker build -t $REGISTRY/patroni:latest -f services/patroni/Dockerfile .

echo "  📊 Building nessie..."
docker build -t $REGISTRY/nessie:latest -f services/nessie/Dockerfile .

echo "  🔍 Building trino..."
docker build -t $REGISTRY/trino:latest -f services/trino/Dockerfile .

echo "  ⚡ Building spark..."
docker build -t $REGISTRY/spark:latest -f services/spark/Dockerfile .

echo ""
echo "✅ All images built successfully!"
echo ""
echo "📋 Built images:"
docker images | grep "ghcr.io/shugur-network/shudl"
echo ""
echo "🚀 Ready to start with: docker compose up -d" 