#!/bin/bash
set -e

echo "===> User"
id

echo "===> Configuring ..."

# Determine if running in KRaft or ZooKeeper mode
if [[ -n "${KAFKA_PROCESS_ROLES}" ]]; then
    echo "Running in KRaft mode..."
    KRAFT_MODE=true
else
    echo "Running in ZooKeeper mode..."
    KRAFT_MODE=false
fi

echo "===> Running preflight checks ... "

# Check if data directory is writable
echo "===> Check if ${KAFKA_LOG_DIRS:-/var/lib/kafka/data} is writable ..."
if [ ! -w "${KAFKA_LOG_DIRS:-/var/lib/kafka/data}" ]; then
    echo "ERROR: ${KAFKA_LOG_DIRS:-/var/lib/kafka/data} is not writable"
    exit 1
fi

# For KRaft mode, validate CLUSTER_ID is provided
if [[ "${KRAFT_MODE}" == "true" ]]; then
    echo "===> Running in KRaft mode, skipping Zookeeper health check..."
    
    # Validate CLUSTER_ID is provided (must be formatted externally)
    if [[ -z "${CLUSTER_ID}" ]]; then
        echo "ERROR: CLUSTER_ID environment variable is required for KRaft mode"
        echo "Please run 'make init-kafka' before starting Kafka"
        exit 1
    fi
    
    echo "===> Using cluster id ${CLUSTER_ID} ..."
else
    # ZooKeeper mode - check if ZooKeeper is accessible
    if [[ -n "${KAFKA_ZOOKEEPER_CONNECT}" ]]; then
        echo "===> Check if Zookeeper is healthy ..."
        cub zk-ready "${KAFKA_ZOOKEEPER_CONNECT}" 40 || exit 1
    fi
fi

echo "===> Launching ... "

# Export CLUSTER_ID for potential use by the run script
export CLUSTER_ID

echo "===> Launching kafka ... "
exec /etc/confluent/docker/run
