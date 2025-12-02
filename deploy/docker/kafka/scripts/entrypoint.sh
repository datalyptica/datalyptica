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

# For KRaft mode, format storage if needed
if [[ "${KRAFT_MODE}" == "true" ]]; then
    echo "===> Running in KRaft mode, skipping Zookeeper health check..."
    
    # Check if CLUSTER_ID is provided
    if [[ -z "${CLUSTER_ID}" ]]; then
        echo "===> Generating new cluster id ..."
        CLUSTER_ID=$(kafka-storage random-uuid)
        echo "Generated cluster id: ${CLUSTER_ID}"
    else
        echo "===> Using provided cluster id ${CLUSTER_ID} ..."
    fi
    
    # Check if storage is already formatted
    if kafka-storage info -c /etc/kafka/kafka.properties 2>/dev/null | grep -q "Found log directory"; then
        echo "===> Storage already formatted, checking cluster ID..."
        
        # Get existing cluster ID
        EXISTING_CLUSTER_ID=$(kafka-storage info -c /etc/kafka/kafka.properties 2>/dev/null | grep "Cluster ID:" | awk '{print $3}' || echo "")
        
        if [[ -n "${EXISTING_CLUSTER_ID}" && "${EXISTING_CLUSTER_ID}" != "${CLUSTER_ID}" ]]; then
            echo "WARNING: Existing cluster ID (${EXISTING_CLUSTER_ID}) differs from provided (${CLUSTER_ID})"
            echo "===> Clearing old metadata and reformatting..."
            rm -rf ${KAFKA_LOG_DIRS:-/var/lib/kafka/data}/*
            kafka-storage format -t ${CLUSTER_ID} -c /etc/kafka/kafka.properties --ignore-formatted
        else
            echo "===> Storage already formatted with correct cluster ID, skipping format..."
        fi
    else
        echo "===> Formatting storage with cluster id ${CLUSTER_ID} ..."
        kafka-storage format -t ${CLUSTER_ID} -c /etc/kafka/kafka.properties
    fi
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
