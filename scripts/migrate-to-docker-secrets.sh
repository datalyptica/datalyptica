#!/bin/bash
# migrate-to-docker-secrets.sh
# Migrate environment variables to Docker Swarm secrets

set -e

echo "🔐 Docker Secrets Migration Tool"
echo "================================"
echo ""
echo "This script helps migrate sensitive environment variables to Docker Secrets."
echo "Prerequisites:"
echo "  - Docker Swarm mode enabled (docker swarm init)"
echo "  - Existing .env file with credentials"
echo ""

# Check if Docker Swarm is initialized
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    echo "❌ Docker Swarm is not initialized"
    echo "Run: docker swarm init"
    exit 1
fi

echo "✅ Docker Swarm is active"
echo ""

# Load existing environment variables
if [ ! -f .env ]; then
    echo "❌ .env file not found"
    exit 1
fi

source .env

# Secret mapping: env_var -> secret_name
declare -A SECRETS=(
    ["POSTGRES_PASSWORD"]="postgres_password"
    ["POSTGRES_USER"]="postgres_user"
    ["MINIO_ROOT_USER"]="minio_root_user"
    ["MINIO_ROOT_PASSWORD"]="minio_root_password"
    ["S3_ACCESS_KEY"]="s3_access_key"
    ["S3_SECRET_KEY"]="s3_secret_key"
    ["PATRONI_API_USERNAME"]="patroni_api_username"
    ["PATRONI_API_PASSWORD"]="patroni_api_password"
    ["PATRONI_REPLICATION_PASSWORD"]="patroni_replication_password"
    ["GRAFANA_ADMIN_USER"]="grafana_admin_user"
    ["GRAFANA_ADMIN_PASSWORD"]="grafana_admin_password"
)

# Create secrets
echo "Creating Docker secrets..."
echo ""

for env_var in "${!SECRETS[@]}"; do
    secret_name="${SECRETS[$env_var]}"
    secret_value="${!env_var}"
    
    if [ -z "$secret_value" ]; then
        echo "⚠️  Skipping $env_var (not set)"
        continue
    fi
    
    # Check if secret already exists
    if docker secret inspect "$secret_name" &>/dev/null; then
        echo "⚠️  Secret '$secret_name' already exists, skipping"
    else
        echo "$secret_value" | docker secret create "$secret_name" -
        echo "✅ Created secret: $secret_name"
    fi
done

echo ""
echo "✅ Docker secrets created successfully!"
echo ""
echo "📝 Next steps:"
echo "  1. Update docker-compose.yml to use secrets instead of environment variables"
echo "  2. Services should read from /run/secrets/<secret_name>"
echo "  3. Test the deployment: docker stack deploy -c docker-compose.yml datalyptica"
echo "  4. Verify secrets are working before removing .env file"
echo ""
echo "🔍 List all secrets:"
echo "  docker secret ls"
echo ""
echo "🔍 Inspect a secret (metadata only, not content):"
echo "  docker secret inspect <secret_name>"
echo ""
echo "🗑️  Remove a secret:"
echo "  docker secret rm <secret_name>"
echo ""
echo "⚠️  IMPORTANT:"
echo "  - Backup your .env file before removing it"
echo "  - Secrets are only accessible to services that explicitly declare them"
echo "  - Secrets cannot be updated, only removed and recreated"
echo "  - For secret rotation, create new secret with different name"
