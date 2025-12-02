#!/bin/sh
set -e

# Trino Server Entrypoint Script
echo "=== Trino Server Startup ==="
echo "Version: Trino 476"
echo "Time: $(date)"

# Verify config files are mounted
echo "Verifying Trino configuration files..."
if [ ! -f "/usr/lib/trino/etc/config.properties" ]; then
    echo "ERROR: /usr/lib/trino/etc/config.properties not found!"
    echo "Make sure configs are mounted from host to /usr/lib/trino/etc/"
    exit 1
fi

echo "Configuration files OK"
echo "Starting Trino server..."

# Use the official Trino run script
exec /usr/lib/trino/bin/run-trino
