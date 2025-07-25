#!/bin/bash

# ShuDL Configuration Generation Script
# Generates .env and docker-compose.yml files with all required parameters

set -e

echo "🚀 Generating ShuDL Configuration Files..."

# Default configuration
CONFIG='{
  "project_name": "shudl",
  "network_name": "shunetwork", 
  "environment": "development",
  "services": {
    "postgresql": {},
    "minio": {},
    "nessie": {},
    "trino": {},
    "spark-master": {},
    "spark-worker": {}
  },
  "global_config": {
    "registry": "ghcr.io/shugur-network/shudl"
  }
}'

echo "📋 Using configuration:"
echo "$CONFIG" | jq '.'

# Generate files using the API
echo "🔧 Generating files via API..."
RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/compose/generate \
  -H "Content-Type: application/json" \
  -d "$CONFIG")

if [ $? -eq 0 ]; then
    echo "✅ Files generated successfully!"
    
    # Check if files were created
    if [ -f "generated/.env" ]; then
        echo "✅ .env file created"
        echo "📊 .env file size: $(wc -l < generated/.env) lines"
    else
        echo "❌ .env file not found"
    fi
    
    if [ -f "generated/docker-compose.yml" ]; then
        echo "✅ docker-compose.yml file created"
        echo "📊 docker-compose.yml file size: $(wc -l < generated/docker-compose.yml) lines"
    else
        echo "❌ docker-compose.yml file not found"
    fi
    
    # Show the response
    echo "📄 API Response:"
    echo "$RESPONSE" | jq '.'
    
else
    echo "❌ Failed to generate files"
    echo "Error: $RESPONSE"
    exit 1
fi

echo ""
echo "🎯 Next steps:"
echo "1. Review generated files:"
echo "   - cat generated/.env"
echo "   - cat generated/docker-compose.yml"
echo ""
echo "2. Deploy with CLI:"
echo "   - ./bin/shudl ctl deploy"
echo ""
echo "3. Or deploy manually:"
echo "   - cd generated && docker compose up -d" 