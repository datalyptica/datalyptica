#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to wait for etcd
wait_for_etcd() {
    log "Waiting for etcd to be available..."
    # Extract first etcd host for health check
    FIRST_ETCD=$(echo ${ETCD_HOSTS} | cut -d',' -f1)
    until wget -q -O- http://${FIRST_ETCD}/health > /dev/null 2>&1; do
        log "Waiting for etcd..."
        sleep 2
    done
    log "etcd is available"
}

# Function to initialize Patroni
init_patroni() {
    log "Initializing Patroni..."
    
    # Create necessary directories
    mkdir -p /var/lib/postgresql/archive
    mkdir -p /tmp
    
    # Set environment variables
    export PATRONI_NAME=${HOSTNAME:-$(hostname)}
    export PATRONI_SCOPE=${PATRONI_SCOPE:-lakehouse}
    
    # Create pgpass file for authentication
    echo "*:*:*:postgres:${POSTGRESQL_POSTGRES_PASSWORD}" > /tmp/pgpass
    echo "*:*:*:replicator:replicator123" >> /tmp/pgpass
    echo "*:*:*:rewind_user:rewind123" >> /tmp/pgpass
    chmod 600 /tmp/pgpass
    
    # Create Patroni configuration with environment variable substitution using Python
    python3 -c "
import os
import sys

# Read template
with open('/etc/patroni/patroni.yml', 'r') as f:
    content = f.read()

# Replace environment variables
for key, value in os.environ.items():
    content = content.replace(f'\${{{key}}}', value)
    content = content.replace(f'\${key}', value)

# Write result
with open('/etc/patroni/patroni.yml', 'w') as f:
    f.write(content)
"
    
    log "Patroni configuration created"
}

# Function to start Patroni
start_patroni() {
    log "Starting Patroni..."
    log "Patroni Name: ${PATRONI_NAME}"
    log "Patroni Scope: ${PATRONI_SCOPE}"
    log "etcd Hosts: ${ETCD_HOSTS}"
    
    # Start Patroni
    exec patroni /etc/patroni/patroni.yml
}

# Main execution
main() {
    log "Patroni entrypoint starting..."
    
    # Wait for etcd
    wait_for_etcd
    
    # Initialize Patroni
    init_patroni
    
    # Start Patroni
    start_patroni
}

# Run main function
main "$@" 