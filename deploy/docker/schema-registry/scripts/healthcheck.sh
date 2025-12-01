#!/bin/bash

# Health check for Schema Registry
# Check if the Schema Registry API is responding

SCHEMA_REGISTRY_HOST="${SCHEMA_REGISTRY_HOST:-localhost}"
SCHEMA_REGISTRY_PORT="${SCHEMA_REGISTRY_LISTENERS_PORT:-8081}"

# Check if Schema Registry is responding
if curl -sf "http://${SCHEMA_REGISTRY_HOST}:${SCHEMA_REGISTRY_PORT}/subjects" > /dev/null 2>&1; then
    exit 0
else
    exit 1
fi
