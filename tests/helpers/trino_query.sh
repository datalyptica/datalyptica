#!/bin/bash
# Trino Query Helper - Execute SQL queries via REST API

TRINO_HOST="${TRINO_HOST:-localhost}"
TRINO_PORT="${TRINO_PORT:-8080}"
TRINO_USER="${TRINO_USER:-admin}"

execute_query() {
    local query="$1"
    local max_wait="${2:-30}"
    
    # Submit query
    local response=$(curl -s "http://${TRINO_HOST}:${TRINO_PORT}/v1/statement" \
        -X POST \
        -H "X-Trino-User: ${TRINO_USER}" \
        -d "$query")
    
    # Extract next URI
    local next_uri=$(echo "$response" | grep -o '"nextUri":"[^"]*"' | cut -d'"' -f4 | head -1)
    
    if [[ -z "$next_uri" ]]; then
        echo "Error: Failed to submit query" >&2
        return 1
    fi
    
    # Poll for results
    local elapsed=0
    while [[ $elapsed -lt $max_wait ]]; do
        response=$(curl -s "$next_uri" -H "X-Trino-User: ${TRINO_USER}")
        
        # Check if query is finished
        local state=$(echo "$response" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 | head -1)
        
        if [[ "$state" == "FINISHED" ]]; then
            # Extract and print data
            echo "$response" | grep -o '"data":\[\[.*\]\]' | sed 's/"data"://; s/\[\[/[/; s/\]\]/]/'
            return 0
        elif [[ "$state" == "FAILED" ]]; then
            echo "Error: Query failed" >&2
            echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 >&2
            return 1
        fi
        
        # Get next URI
        next_uri=$(echo "$response" | grep -o '"nextUri":"[^"]*"' | cut -d'"' -f4 | head -1)
        if [[ -z "$next_uri" ]]; then
            break
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    echo "Error: Query timeout" >&2
    return 1
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "$1" ]]; then
        echo "Usage: $0 'SQL QUERY'" >&2
        exit 1
    fi
    execute_query "$1"
fi

