#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to wait for etcd
wait_for_etcd() {
    log "Waiting for etcd to be available..."
    until etcdctl --endpoints=${ETCD_HOSTS} endpoint health; do
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
    
    # Create Patroni configuration with environment variable substitution
    envsubst < /etc/patroni/patroni.yml > /etc/patroni/patroni.yml.tmp
    mv /etc/patroni/patroni.yml.tmp /etc/patroni/patroni.yml
    
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